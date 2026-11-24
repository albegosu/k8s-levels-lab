#!/usr/bin/env bash
# Sets up a local GitOps repo served with git daemon, plus an Argo CD ApplicationSet
# that creates one Application per apps/* directory.
# Usage: ./level-6/gitops.sh up | bump <tag> | down
set -euo pipefail
cd "$(dirname "$0")/.."
REPO_ROOT="$PWD/.gitops"
REPO="$REPO_ROOT/platform-gitops-lab"
PIDFILE="$REPO_ROOT/git-daemon.pid"
# Lab-only commits: never ask for a GPG passphrase.
GIT=(git -C "$REPO" -c commit.gpgsign=false)

serve() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then return; fi
  git daemon --reuseaddr --export-all --base-path="$REPO_ROOT" --port=9418 \
    --detach --pid-file="$PIDFILE" "$REPO_ROOT"
}

case "${1:-}" in
  up)
    if ! git -C "$REPO" rev-parse -q --verify HEAD >/dev/null 2>&1; then
      mkdir -p "$REPO/apps"
      cp -R level-6/shop "$REPO/apps/shop"
      git -C "$REPO" init -q -b main
      "${GIT[@]}" add -A
      "${GIT[@]}" -c user.name=lab -c user.email=lab@lab.local commit -qm "feat(shop): first version"
    fi
    serve
    kubectl --context kind-lab apply -f level-6/applicationset.yaml
    echo "GitOps repo: $REPO (served at git://host.docker.internal:9418/platform-gitops-lab)" ;;
  bump)
    TAG=${2:?image tag, e.g. 6.7.1}
    yq -i ".image.tag = \"$TAG\"" "$REPO/apps/shop/values.yaml"
    "${GIT[@]}" -c user.name="CI" -c user.email=ci@lab.local \
      commit -qam "chore(shop): bump dev image tag to $TAG"
    git -C "$REPO" log --oneline -3 ;;
  down)
    [[ -f "$PIDFILE" ]] && kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
    kubectl --context kind-lab delete -f level-6/applicationset.yaml --ignore-not-found ;;
  *) echo "Usage: ./level-6/gitops.sh up | bump <tag> | down"; exit 1 ;;
esac
