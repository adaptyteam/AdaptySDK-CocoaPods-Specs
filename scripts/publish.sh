#!/bin/bash
# Publishes the Adapty iOS SDK podspecs from an AdaptySDK-iOS ref to this spec repo, in dependency
# order. A tag keeps the podspec's tag source; any other ref pins the source to the commit.
# Pods already published from this ref are skipped (another ref is refused), so reruns are safe.
# Usage: scripts/publish.sh --ios-repo PATH --ref TAG_OR_COMMIT [--repo NAME] [--skip-import-validation]
set -euo pipefail
export LANG=en_US.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS=(AdaptyLogger AdaptyCSimdjson AdaptyCodable AdaptyUIBuilder Adapty AdaptyUI AdaptyPlugin)
TRUNK_CDN='https://cdn.cocoapods.org/'
REPO_NAME='adapty-specs'
IOS_REPO=''
REF=''
PUSH_ARGS=()

die() { echo "error: $*" >&2; exit 1; }
need() { [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || die "$1 needs a value"; }

while [[ $# -gt 0 ]]; do
  case $1 in
    --ios-repo) need "$@"; IOS_REPO=$2; shift 2 ;;
    --ref) need "$@"; REF=$2; shift 2 ;;
    --repo) need "$@"; REPO_NAME=$2; shift 2 ;;
    --skip-import-validation) PUSH_ARGS+=(--skip-import-validation); shift ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$IOS_REPO" && -n "$REF" ]] || die "--ios-repo and --ref are required (see --help)"
REPO_DIR="$HOME/.cocoapods/repos/$REPO_NAME"
[[ -d "$REPO_DIR/.git" ]] || die "spec repo '$REPO_NAME' is not registered; run: pod repo add $REPO_NAME <url>"
git -C "$IOS_REPO" rev-parse --git-dir > /dev/null 2>&1 || die "$IOS_REPO is not a git checkout"
SHA=$(git -C "$IOS_REPO" rev-parse --verify --quiet "$REF^{commit}") || die "unknown ref $REF in $IOS_REPO"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# Read the podspecs at the ref, not from the working tree, and require one shared version.
VERSION=''
for pod in "${PODS[@]}"; do
  git -C "$IOS_REPO" show "$SHA:$pod.podspec" > "$WORK_DIR/$pod.podspec" 2>/dev/null \
    || die "missing $pod.podspec at $REF"
  pod ipc spec "$WORK_DIR/$pod.podspec" > "$WORK_DIR/$pod.orig.json"
  version=$(ruby -rjson -e 'puts JSON.parse($stdin.read)["version"]' < "$WORK_DIR/$pod.orig.json")
  if [[ -z "$VERSION" ]]; then
    VERSION="$version"
  elif [[ "$version" != "$VERSION" ]]; then
    die "$pod is $version, expected $VERSION (podspec versions drifted at $REF)"
  fi
done

# Lint clones the source from GitHub, so it must be reachable there before minutes of linting.
if git -C "$IOS_REPO" show-ref --verify --quiet "refs/tags/$REF"; then
  MODE=tag
  [[ "$REF" == "$VERSION" ]] || die "tag $REF does not match podspec version $VERSION"
  git -C "$IOS_REPO" ls-remote --exit-code --tags origin "refs/tags/$REF" > /dev/null \
    || die "tag $REF is not on origin"
else
  MODE=commit
  # Uses the locally known remote branches; run `git fetch` in the iOS repo if this looks stale.
  [[ -n "$(git -C "$IOS_REPO" branch -r --contains "$SHA")" ]] \
    || die "commit $SHA is not on any remote branch; push it first"
fi

# `pod repo push` commits in the clone before pushing, so a failed push leaves specs only there.
sync_repo() {
  { git -C "$REPO_DIR" pull --quiet --rebase && git -C "$REPO_DIR" push --quiet origin HEAD; } \
    || die "cannot sync $REPO_NAME with its remote (is the spec repo working tree clean?)"
}
sync_repo

echo "Publishing $VERSION from $REF ($MODE source, $SHA) to $REPO_NAME"
for pod in "${PODS[@]}"; do
  published="$REPO_DIR/Specs/$pod/$VERSION/$pod.podspec.json"
  if [[ -f "$published" ]]; then
    # Skipping a spec from another ref would keep a stale source or mix sources within one version.
    if [[ "$MODE" == commit ]]; then key=commit want=$SHA; else key=tag want=$REF; fi
    have=$(ruby -rjson -e 's = JSON.parse($stdin.read)["source"]; puts s[ARGV[0]] || s["commit"] || s["tag"]' \
      "$key" < "$published")
    [[ "$have" == "$want" ]] || die "$pod $VERSION is already published from $have, not $want"
    echo "skip: $pod $VERSION is already published"
    continue
  fi
  spec="$WORK_DIR/$pod.podspec.json"
  if [[ "$MODE" == commit ]]; then
    ruby "$SCRIPT_DIR/rewrite_source.rb" --commit "$SHA" < "$WORK_DIR/$pod.orig.json" > "$spec"
  else
    cp "$WORK_DIR/$pod.orig.json" "$spec"
  fi
  echo "push: $pod $VERSION"
  pod repo push "$REPO_NAME" "$spec" \
    --sources="$REPO_NAME,$TRUNK_CDN" \
    --allow-warnings --skip-tests --no-overwrite \
    --commit-message="[Add] $pod ($VERSION)" \
    ${PUSH_ARGS[@]+"${PUSH_ARGS[@]}"}
done

sync_repo
local_head=$(git -C "$REPO_DIR" rev-parse HEAD)
remote_head=$(git -C "$REPO_DIR" ls-remote origin HEAD | cut -f1)
[[ "$local_head" == "$remote_head" ]] || die "$REPO_NAME remote is at $remote_head, the clone at $local_head"
echo "Done: $VERSION"
