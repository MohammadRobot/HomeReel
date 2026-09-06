#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
  echo "Commit project changes before packaging a release." >&2
  exit 1
fi
version=$(git show HEAD:VERSION)
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]]; then
  echo "Invalid VERSION value." >&2
  exit 1
fi
name="homereel-$version"
mkdir -p dist
for artifact in "dist/$name.tar.gz" "dist/$name.zip" "dist/$name.sha256"; do
  if [ -e "$artifact" ]; then
    echo "Release artifact already exists: $artifact; preserve or move it before rebuilding." >&2
    exit 1
  fi
done

# Explicit tracked-file allowlist: runtime state and local client builds never enter archives.
files=(
  .dockerignore .env.example .gitignore AGENTS.md README.md VERSION
  LICENSE THIRD_PARTY.md CHANGELOG.md docker-compose.yml docker-compose.gpu.yml
  docs/USER_MANUAL.md docs/RELEASING.md
  scripts/start-media-server.sh scripts/package-release.sh
  landing/index.html landing/nginx.conf updater/Dockerfile updater/update_server.py
  .github/workflows/validate.yml
)
git archive --format=tar.gz --prefix="$name/" -o "dist/$name.tar.gz" HEAD -- "${files[@]}"
git archive --format=zip --prefix="$name/" -o "dist/$name.zip" HEAD -- "${files[@]}"
(
  cd dist
  sha256sum "$name.tar.gz" "$name.zip" > "$name.sha256"
  sha256sum -c "$name.sha256"
)
printf 'Release %s packaged from commit %s in dist/\n' "$version" "$(git rev-parse --short HEAD)"
