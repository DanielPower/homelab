#!/usr/bin/env bash
# Fast-forward this checkout to GitHub master and redeploy the apps that changed.
# Runs from deploy/homelab-sync.timer. Last successful deploy is tracked in
# refs/deploy/last, so a failed deploy is retried on the next run.
set -euo pipefail

REMOTE_URL=https://github.com/danielpower/homelab.git
BRANCH=master
DEPLOY_REF=refs/deploy/last

main() {
  cd "$(dirname "$(readlink -f "$0")")/.."
  exec 9>.git/homelab-sync.lock
  flock -n 9 || { echo "another sync is running"; exit 0; }

  if ! git rev-parse -q --verify "$DEPLOY_REF" >/dev/null; then
    git update-ref "$DEPLOY_REF" HEAD
    echo "initialized $DEPLOY_REF at $(git rev-parse --short HEAD)"
  fi

  git fetch -q "$REMOTE_URL" "$BRANCH"
  local target deployed
  target=$(git rev-parse FETCH_HEAD)
  deployed=$(git rev-parse "$DEPLOY_REF")
  [ "$target" = "$deployed" ] && exit 0

  if [ "$(git rev-parse HEAD)" != "$target" ]; then
    git merge-base --is-ancestor HEAD "$target" \
      || { echo "refusing: $BRANCH is not a fast-forward of HEAD"; exit 1; }
    git merge -q --ff-only "$target"
  fi

  local app failed=0
  for app in $(git diff --name-only "$deployed" "$target" | cut -d/ -f1 | sort -u); do
    [ -f "$app/compose.yml" ] || continue
    # Only redeploy stacks that are already deployed; stopped ones stay stopped.
    if [ -z "$(cd "$app" && docker compose ps -a -q)" ]; then
      echo "$app: not deployed, skipping"
      continue
    fi
    echo "$app: deploying"
    if ! (cd "$app" && docker compose pull -q --ignore-buildable \
                    && docker compose up -d --build --remove-orphans); then
      echo "$app: deploy failed"
      failed=1
    fi
  done

  [ "$failed" = 0 ] || exit 1
  git update-ref "$DEPLOY_REF" "$target"
  echo "deployed $(git rev-parse --short "$target")"
}

main "$@"
