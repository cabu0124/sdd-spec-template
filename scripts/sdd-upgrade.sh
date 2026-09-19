#!/usr/bin/env bash
#
# Bring this repository's scaffolding up to a published version of the template
# it was built from.
#
#   scripts/sdd-upgrade.sh                    # what would change, and nothing else
#   scripts/sdd-upgrade.sh --diff             # read the changes first
#   scripts/sdd-upgrade.sh --apply            # write them into the working tree
#   scripts/sdd-upgrade.sh --to v1.4.0        # a version other than the pinned one
#   scripts/sdd-upgrade.sh --to latest --apply
#   scripts/sdd-upgrade.sh --list             # versions published by the template
#   scripts/sdd-upgrade.sh --adopt --source <url>   # a repository with no provenance yet
#
# It writes into the working tree and stops there: you read the diff and commit
# it, exactly as with scripts/spec-sync.sh. It never commits, never branches and
# never pushes.
#
# What it may touch is decided by the template's own .sdd/manifest.yml at the
# target version — managed, seeded or ignored. A managed file the repository has
# edited is reported and left alone: this tool does not merge, because a merge
# it got wrong would be a change nobody reviewed.
#
# .sdd/template.yml says where the scaffolding comes from and which version this
# repository is on. That version is a pin: nothing moves until someone asks.
# .sdd/template.lock records the blob the template delivered for each managed
# file, which is how a local edit is told apart from a file simply being old.

set -uo pipefail

here=$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

. "$here/sdd-lib.sh" || { echo "sdd-upgrade: scripts/sdd-lib.sh is missing" >&2; exit 1; }

CONFIG=.sdd/template.yml
LOCK=.sdd/template.lock
MANIFEST=.sdd/manifest.yml

die() { printf 'sdd-upgrade: %s\n' "$1" >&2; exit "${2:-1}"; }

mode=check
requested_version=""
adopt_source=""
adopt_from=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) mode=check ;;
    --diff) mode=diff ;;
    --apply) mode=apply ;;
    --list) mode=list ;;
    --adopt) mode=adopt ;;
    --to)
      shift
      [ "$#" -gt 0 ] || die "--to needs a version, or 'latest'" 2
      requested_version=$1
      ;;
    --source)
      shift
      [ "$#" -gt 0 ] || die "--source needs the template's git URL" 2
      adopt_source=$1
      ;;
    --from)
      shift
      [ "$#" -gt 0 ] || die "--from needs the version this repository started at" 2
      adopt_from=$1
      ;;
    --help | -h)
      awk 'NR > 1 && /^#/ { sub(/^#[[:space:]]?/, ""); print; next } NR > 1 { exit }' "$0"
      exit 0
      ;;
    *) die "unknown option: $1" 2 ;;
  esac
  shift
done

config_field() {
  [ -f "$CONFIG" ] || return 0
  sed -n "s/^$1:[[:space:]]*//p" "$CONFIG" \
    | head -n1 \
    | sed -e 's/[[:space:]]*#.*$//' -e 's/\r$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//" -e 's/[[:space:]]*$//'
}

source_url=$(config_field source)
pinned_version=$(config_field version)

if [ "$mode" = adopt ]; then
  [ -n "$adopt_source" ] || source_url=${source_url:-}
  [ -n "$adopt_source" ] && source_url=$adopt_source
  [ -n "$source_url" ] || die "--adopt needs --source <url>, the template this repository came from" 2
elif [ ! -f "$CONFIG" ]; then
  die "$CONFIG not found — this repository has no recorded provenance. Run --adopt --source <url> once to record it" 2
fi

[ -n "$source_url" ] || die "source is not set in $CONFIG" 2

# The template, fetched into a scratch repository. Nothing is ever cloned over
# this one, and no ref of this repository is touched.
tmp=$(mktemp -d)
cleanup() { [ -n "${tmp:-}" ] && rm -rf "$tmp"; return 0; }
trap cleanup EXIT

src="$tmp/template"
git -C "$tmp" init --quiet template
git -C "$src" remote add origin "$source_url"

# Tags only, and no depth limit: a shallow fetch is refused over a local path,
# and a template is small enough that the whole history costs nothing.
if ! git -C "$src" fetch --quiet origin 'refs/tags/*:refs/tags/*' 2>/dev/null; then
  die "could not reach $source_url"
fi

versions() { git -C "$src" tag --list 'v[0-9]*' --sort=-v:refname; }

latest_version() { versions | head -n1; }

if [ "$mode" = list ]; then
  printf 'Published by %s:\n' "$source_url"
  versions | sed 's/^/  /'
  [ -n "$pinned_version" ] && printf '\nThis repository is on %s.\n' "$pinned_version"
  exit 0
fi

target=${requested_version:-${pinned_version:-latest}}
[ "$target" = latest ] && target=$(latest_version)
[ -n "$target" ] || die "$source_url has published no versions"

git -C "$src" rev-parse --verify --quiet "refs/tags/$target^{commit}" > /dev/null \
  || die "$target is not a version published by $source_url — try --list"
commit=$(git -C "$src" rev-parse "refs/tags/$target^{commit}")

# The manifest that ships with the target version, not the one in this
# repository: which files the template owns is itself versioned.
manifest="$tmp/manifest.yml"
git -C "$src" show "$commit:$MANIFEST" > "$manifest" 2>/dev/null \
  || die "$target has no $MANIFEST, so it predates upgrading and cannot be a target"

manifest_list() {
  awk -v section="$1" '
    $0 ~ "^" section ":" { inside = 1; next }
    /^[^[:space:]#]/ { inside = 0 }
    inside && /^[[:space:]]*-[[:space:]]/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "")
      sub(/[[:space:]]*$/, "")
      if (length($0)) print
    }
  ' "$manifest"
}

sha_at() { git -C "$src" rev-parse --quiet --verify "$commit:$1" 2>/dev/null; }
sha_here() { [ -f "$1" ] && git hash-object "$1" 2>/dev/null; }
locked_sha() { [ -f "$LOCK" ] && awk -v p="$1" '$2 == p { print $1; exit }' "$LOCK"; }
mode_at() { git -C "$src" ls-tree "$commit" -- "$1" 2>/dev/null | awk '{ print $1; exit }'; }

# Files this repository has taken over. A deliberate divergence stops being news
# after the first time it is reported, and a check that cries wolf on every run
# is a check nobody reads the day it means something.
kept_list() {
  [ -f "$CONFIG" ] || return 0
  awk '
    /^keep:/ { inside = 1; next }
    /^[^[:space:]#]/ { inside = 0 }
    inside && /^[[:space:]]*-[[:space:]]/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "")
      sub(/[[:space:]]*#.*$/, "")
      sub(/[[:space:]]*$/, "")
      if (length($0)) print
    }
  ' "$CONFIG"
}

is_kept() { kept_list | grep -Fqx "$1"; }

block_body() {
  git -C "$src" show "$commit:$1" 2>/dev/null \
    | awk -v s="<!-- $2:start -->" -v e="<!-- $2:end -->" '$0 == s { f = 1; next } $0 == e { f = 0 } f'
}

block_body_here() {
  [ -f "$1" ] || return 0
  awk -v s="<!-- $2:start -->" -v e="<!-- $2:end -->" '$0 == s { f = 1; next } $0 == e { f = 0 } f' "$1"
}

# --- work out what would change ---------------------------------------------

actions="$tmp/actions"
: > "$actions"

record() { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >> "$actions"; }

while IFS= read -r path; do
  [ -n "$path" ] || continue
  remote=$(sha_at "$path")
  local_sha=$(sha_here "$path")
  locked=$(locked_sha "$path")

  if [ -z "$remote" ] && [ -n "$local_sha" ]; then
    record gone "$path"
  elif [ -z "$remote" ]; then
    :
  elif [ -z "$local_sha" ]; then
    record new "$path" "$remote"
  elif [ "$remote" = "$local_sha" ]; then
    record current "$path" "$remote"
  elif is_kept "$path"; then
    record kept "$path"
  elif [ -n "$locked" ] && [ "$locked" = "$local_sha" ]; then
    record update "$path" "$remote"
  else
    record conflict "$path" "$remote"
  fi
done < <(manifest_list managed)

while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  file=${entry%% *}
  marker=${entry##* }
  [ -f "$file" ] || continue
  if ! grep -Fq "<!-- $marker:start -->" "$file"; then
    record blockmissing "$file" "$marker"
    continue
  fi
  if [ "$(block_body "$file" "$marker")" = "$(block_body_here "$file" "$marker")" ]; then
    record current "$file ($marker)"
  else
    record block "$file" "$marker"
  fi
done < <(manifest_list blocks)

count() { awk -v k="$1" '$1 == k' "$actions" | wc -l | tr -d ' '; }

to_apply=$(( $(count new) + $(count update) + $(count block) ))
needs_review=$(( $(count conflict) + $(count gone) + $(count blockmissing) ))
kept=$(count kept)

# --- report ------------------------------------------------------------------

if [ "$mode" != adopt ]; then
  if [ -n "$pinned_version" ] && [ "$pinned_version" != "$target" ]; then
    printf '%s -> %s  (%s)\n' "$pinned_version" "$target" "$source_url"
  else
    printf '%s  (%s)\n' "$target" "$source_url"
  fi

  while IFS=$'\t' read -r kind path extra; do
    case $kind in
      current) ;;
      new)     printf '  new       %s\n' "$path" ;;
      update)  printf '  update    %s\n' "$path" ;;
      block)   printf '  block     %s (%s)\n' "$path" "$extra" ;;
      conflict) printf '  conflict  %s — edited here, left alone\n' "$path" ;;
      kept)    printf '  kept      %s — yours, by keep: in %s\n' "$path" "$CONFIG" ;;
      gone)    printf '  gone      %s — dropped by the template, delete it yourself\n' "$path" ;;
      blockmissing) printf '  no marker %s — lost its %s block\n' "$path" "$extra" ;;
    esac
  done < "$actions"
fi

# --- diff --------------------------------------------------------------------

if [ "$mode" = diff ]; then
  while IFS=$'\t' read -r kind path extra; do
    case $kind in
      new | update | conflict) ;;
      *) continue ;;
    esac
    printf '\n--- %s: %s ---\n' "$kind" "$path"
    git -C "$src" show "$commit:$path" > "$tmp/remote" 2>/dev/null || continue
    if [ -f "$path" ]; then
      diff -u --label "$path (here)" --label "$path ($target)" "$path" "$tmp/remote" \
        | sdd_truncate_lines 40 10
    else
      sdd_truncate_lines 20 5 < "$tmp/remote"
    fi
  done < "$actions"
fi

# --- apply -------------------------------------------------------------------

write_lock() {
  local tmp_lock="$tmp/lock"
  : > "$tmp_lock"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    local sha
    sha=$(awk -v p="$path" -F'\t' '$2 == p { print $3; exit }' "$actions")
    case $(awk -v p="$path" -F'\t' '$2 == p { print $1; exit }' "$actions") in
      new | update | current) ;;
      # Not applied, so it still answers to whatever the template last delivered.
      *) sha=$(locked_sha "$path") ;;
    esac
    [ -n "$sha" ] && printf '%s\t%s\n' "$sha" "$path" >> "$tmp_lock"
  done < <(manifest_list managed)
  sort -k2 "$tmp_lock" > "$LOCK"
}

write_config() {
  # keep: is the repository's, not ours — read it before the file is rewritten.
  local keeps
  keeps=$(kept_list)
  {
    printf '# Where this repository'"'"'s scaffolding comes from, and which version it is on.\n'
    printf '# Written by scripts/sdd-upgrade.sh — the version is a pin, so nothing moves\n'
    printf '# until someone asks for it. See docs/commands/upgrade.md.\n\n'
    printf 'source: %s\n' "$source_url"
    printf 'version: %s\n' "$target"
    printf 'resolved: %s\n' "$commit"
    if [ -n "$keeps" ]; then
      printf '\n# Managed files this repository has taken over. An upgrade reports them and\n'
      printf '# never writes them.\nkeep:\n'
      printf '%s\n' "$keeps" | sed 's/^/  - /'
    fi
  } > "$CONFIG"
}

if [ "$mode" = apply ]; then
  applied=0
  while IFS=$'\t' read -r kind path extra; do
    case $kind in
      new | update)
        mkdir -p "$(dirname "$path")"
        git -C "$src" show "$commit:$path" > "$path" || die "could not write $path"
        [ "$(mode_at "$path")" = 100755 ] && chmod +x "$path"
        applied=$((applied + 1))
        ;;
      block)
        block_body "$path" "$extra" > "$tmp/block"
        awk -v s="<!-- $extra:start -->" -v e="<!-- $extra:end -->" -v repl="$tmp/block" '
          $0 == s { print; while ((getline line < repl) > 0) print line; skip = 1; next }
          $0 == e { skip = 0; print; next }
          !skip { print }
        ' "$path" > "$tmp/patched"
        cat "$tmp/patched" > "$path"
        applied=$((applied + 1))
        ;;
    esac
  done < "$actions"

  mkdir -p .sdd
  write_lock
  write_config

  printf '\n%d file(s) written, %d left for you' "$applied" "$needs_review"
  [ "$kept" -gt 0 ] && printf ', %d kept as yours' "$kept"
  printf '. %s and %s updated.\n' "$CONFIG" "$LOCK"
  printf 'Nothing was committed. Read the diff, then commit it.\n'

  if git -C "$src" cat-file -e "$commit:docs/migrations/$target.md" 2>/dev/null; then
    printf '\n%s has migration notes. Read them:\n' "$target"
    git -C "$src" show "$commit:docs/migrations/$target.md" | sed 's/^/  /'
  fi
  exit 0
fi

if [ "$mode" = adopt ]; then
  # No provenance yet: work out which published version this repository is
  # closest to, so the lock records what the template delivered rather than what
  # the repository has now. Get that backwards and every local edit reads as
  # up to date, and the next upgrade overwrites it.
  if [ -z "$adopt_from" ]; then
    best=""
    best_hits=-1
    while IFS= read -r candidate; do
      [ -n "$candidate" ] || continue
      c=$(git -C "$src" rev-parse "refs/tags/$candidate^{commit}")
      hits=0
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        [ -f "$path" ] || continue
        [ "$(git -C "$src" rev-parse --quiet --verify "$c:$path" 2>/dev/null)" = "$(git hash-object "$path")" ] \
          && hits=$((hits + 1))
      done < <(manifest_list managed)
      if [ "$hits" -gt "$best_hits" ]; then
        best=$candidate
        best_hits=$hits
      fi
    done < <(versions)
    adopt_from=$best
    printf 'Closest published version: %s (%d managed file(s) match).\n' "$adopt_from" "$best_hits"
  fi

  [ -n "$adopt_from" ] || die "could not work out a base version; pass --from vX.Y.Z"
  base=$(git -C "$src" rev-parse --verify --quiet "refs/tags/$adopt_from^{commit}") \
    || die "$adopt_from is not a version published by $source_url"

  mkdir -p .sdd
  : > "$LOCK"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    sha=$(git -C "$src" rev-parse --quiet --verify "$base:$path" 2>/dev/null) || continue
    [ -n "$sha" ] && printf '%s\t%s\n' "$sha" "$path" >> "$LOCK"
  done < <(manifest_list managed)
  sort -k2 "$LOCK" -o "$LOCK"

  target=$adopt_from
  commit=$base
  write_config

  printf 'Recorded %s at %s. Run scripts/sdd-upgrade.sh to see what a newer version would change.\n' \
    "$CONFIG" "$adopt_from"
  exit 0
fi

if [ "$to_apply" -eq 0 ] && [ "$needs_review" -eq 0 ]; then
  printf '\nUp to date'
  [ "$kept" -gt 0 ] && printf ', with %d file(s) kept as yours' "$kept"
  printf '.\n'
  exit 0
fi

printf '\n%d to apply, %d for you to look at' "$to_apply" "$needs_review"
[ "$kept" -gt 0 ] && printf ', %d kept as yours' "$kept"
printf '.\n'
[ "$mode" = check ] && printf 'Run --diff to read them, --apply to write them.\n'
exit 1
