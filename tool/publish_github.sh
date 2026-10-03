#!/usr/bin/env bash
# Run explicitly on your own machine to create and push the public repository.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v gh >/dev/null || { echo 'Installeer GitHub CLI (gh) en voer gh auth login uit.' >&2; exit 1; }
gh auth status
github_owner="$(gh api user --jq .login)"
if [[ "$github_owner" != 'basd82' ]]; then
  echo 'Log in met GitHub-account basd82 voordat je dit project publiceert.' >&2
  exit 1
fi
if gh repo view basd82/de-schutter >/dev/null 2>&1; then
  echo 'basd82/de-schutter bestaat al. Controleer eerst de bestaande repository.' >&2
  exit 1
fi
if [[ ! -d .git ]]; then
  git init -b main
  git add .
  git commit -m 'Initialize De Schutter cross-platform offline scorecard app'
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo 'Commit eerst de lokale wijzigingen; er wordt nog niets gepubliceerd.' >&2
  exit 1
fi
if git remote get-url origin >/dev/null 2>&1; then
  echo 'Er bestaat al een origin-remote. Controleer die eerst; er wordt niets gewijzigd.' >&2
  exit 1
fi
gh repo create basd82/de-schutter --public --source=. --remote=origin \
  --description 'Offline archery scorecards for Android, iOS, macOS and Windows; mobile on-device photo recognition foundation' \
  --push
