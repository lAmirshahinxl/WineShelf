#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
website_dir="$repo_root/website"
local_config="$script_dir/deploy-site.local"

environment_target="${WINESHELF_DEPLOY_TARGET:-}"
environment_path="${WINESHELF_DEPLOY_PATH:-}"

if [[ -f "$local_config" ]]; then
  # This ignored file is intentionally sourced so each user can keep server settings locally.
  # shellcheck disable=SC1090
  source "$local_config"
fi

target="${environment_target:-${WINESHELF_DEPLOY_TARGET:-}}"
remote_path="${environment_path:-${WINESHELF_DEPLOY_PATH:-/var/www/wineshelf.site}}"

usage() {
  cat <<'EOF'
Usage: ./deploy/deploy-site.sh [--dry-run]

Set WINESHELF_DEPLOY_TARGET in deploy/deploy-site.local or in the environment
to an SSH config alias or user@host with write access to the website directory.
EOF
}

dry_run=0
if [[ "${1:-}" == "--dry-run" && $# -eq 1 ]]; then
  dry_run=1
elif [[ $# -ne 0 ]]; then
  usage >&2
  exit 2
fi

if [[ -z "$target" ]]; then
  echo "Missing WINESHELF_DEPLOY_TARGET. See deploy/deploy-site.local.example." >&2
  exit 2
fi

if [[ ! "$remote_path" =~ ^/[A-Za-z0-9._/-]+$ ]]; then
  echo "WINESHELF_DEPLOY_PATH must be an absolute path without spaces or shell characters." >&2
  exit 2
fi

if [[ ! -d "$website_dir" ]]; then
  echo "Website source directory not found: $website_dir" >&2
  exit 1
fi

for command_name in rsync ssh shasum cut sed cp mktemp grep gh npm; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

ssh_options=(-o BatchMode=yes -o ConnectTimeout=10)
if ! ssh "${ssh_options[@]}" "$target" "test -d '$remote_path' && test -w '$remote_path'"; then
  echo "Cannot write to $target:$remote_path. Check the SSH target and remote directory permissions." >&2
  exit 1
fi

npm ci --prefix "$website_dir/slider"
npm run build --prefix "$website_dir/slider"
bundle_dir="$repo_root/.build/game-carousel"
for bundle_file in game-carousel.js game-carousel.css; do
  if [[ ! -s "$bundle_dir/$bundle_file" ]]; then
    echo "Game slider build did not produce $bundle_file." >&2
    exit 1
  fi
done

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/wineshelf-site-deploy.XXXXXX")"
release_dir="$(mktemp -d "${TMPDIR:-/tmp}/wineshelf-release-download.XXXXXX")"
trap 'rm -rf "$staging_dir" "$release_dir"' EXIT
cp -pR "$website_dir/." "$staging_dir/"
rm -rf "$staging_dir/slider"
cp -p "$bundle_dir/game-carousel.js" "$staging_dir/game-carousel.js"
cp -p "$bundle_dir/game-carousel.css" "$staging_dir/game-carousel.css"

release_repo="lAmirshahinxl/WineShelf"
release_tag="$(gh release view --repo "$release_repo" --json tagName --jq '.tagName')"
release_asset="$(gh release view --repo "$release_repo" --json assets --jq '.assets[].name | select(test("^WineShelf-[0-9].*-universal[.]dmg$"))' | sed -n '1p')"
if [[ ! "$release_tag" =~ ^v?[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "Could not determine a valid latest WineShelf release tag." >&2
  exit 1
fi
if [[ ! "$release_asset" =~ ^WineShelf-[0-9][A-Za-z0-9._-]*-universal\.dmg$ ]]; then
  echo "Could not find the latest versioned universal DMG in release $release_tag." >&2
  exit 1
fi

gh release download "$release_tag" --repo "$release_repo" --pattern "$release_asset" --dir "$release_dir"
mkdir -p "$staging_dir/downloads"
cp -p "$release_dir/$release_asset" "$staging_dir/downloads/WineShelf-universal.dmg"

css_hash="$(shasum -a 256 "$staging_dir/styles.css" | cut -c1-12)"
carousel_hash="$(shasum -a 256 "$staging_dir/game-carousel.js" | cut -c1-12)"
carousel_css_hash="$(shasum -a 256 "$staging_dir/game-carousel.css" | cut -c1-12)"
stylesheet_placeholder='href="/styles.css?v=source"'
if ! grep -Fq "$stylesheet_placeholder" "$staging_dir/index.html"; then
  echo "Expected stylesheet placeholder was not found in website/index.html." >&2
  exit 1
fi
carousel_placeholder='src="/game-carousel.js?v=source"'
if ! grep -Fq "$carousel_placeholder" "$staging_dir/index.html"; then
  echo "Expected game carousel script placeholder was not found in website/index.html." >&2
  exit 1
fi
carousel_css_placeholder='href="/game-carousel.css?v=source"'
if ! grep -Fq "$carousel_css_placeholder" "$staging_dir/index.html"; then
  echo "Expected game carousel stylesheet placeholder was not found in website/index.html." >&2
  exit 1
fi
download_placeholder='href="/downloads/WineShelf-universal.dmg?v=source"'
if ! grep -Fq "$download_placeholder" "$staging_dir/index.html"; then
  echo "Expected download placeholder was not found in website/index.html." >&2
  exit 1
fi

sed \
  -e "s|href=\"/styles\\.css?v=source\"|href=\"/styles.css?v=${css_hash}\"|" \
  -e "s|src=\"/game-carousel\\.js?v=source\"|src=\"/game-carousel.js?v=${carousel_hash}\"|" \
  -e "s|href=\"/game-carousel\\.css?v=source\"|href=\"/game-carousel.css?v=${carousel_css_hash}\"|" \
  -e "s|href=\"/downloads/WineShelf-universal\\.dmg?v=source\"|href=\"/downloads/WineShelf-universal.dmg?v=${release_tag}\"|" \
  "$staging_dir/index.html" > "$staging_dir/index.html.tmp"
mv "$staging_dir/index.html.tmp" "$staging_dir/index.html"

rsync_options=(-rltz --checksum --human-readable)
if (( dry_run )); then
  rsync_options+=(--dry-run --itemize-changes)
  echo "Previewing website sync to $target:$remote_path (styles $css_hash/$carousel_css_hash, slider $carousel_hash, WineShelf $release_tag)"
else
  echo "Syncing website to $target:$remote_path (styles $css_hash/$carousel_css_hash, slider $carousel_hash, WineShelf $release_tag)"
fi

rsync "${rsync_options[@]}" -e 'ssh -o BatchMode=yes -o ConnectTimeout=10' -- \
  "$staging_dir/" "$target:$remote_path/"

if (( dry_run )); then
  echo "Dry run complete. No server files were changed."
else
  ssh "${ssh_options[@]}" "$target" "sudo -n bash -s" <<'REMOTE_SCRIPT'
set -Eeuo pipefail
config="$(readlink -f /etc/nginx/sites-enabled/wineshelf.site)"
if [[ ! -f "$config" ]]; then
  echo "Could not find the active WineShelf Nginx configuration." >&2
  exit 1
fi
if grep -Fq "style-src 'self';" "$config"; then
  backup="$(mktemp /tmp/wineshelf-nginx.XXXXXX)"
  cp -p "$config" "$backup"
  sed -i "s/style-src 'self';/style-src 'self' 'unsafe-inline';/" "$config"
  if ! nginx -t; then
    cp -p "$backup" "$config"
    rm -f "$backup"
    exit 1
  fi
  systemctl reload nginx
  rm -f "$backup"
elif ! grep -Fq "style-src 'self' 'unsafe-inline';" "$config"; then
  echo "The WineShelf CSP did not contain the expected style-src directive." >&2
  exit 1
fi
REMOTE_SCRIPT
  echo "Website sync complete. Nginx now allows the slider's inline geometry styles; scripts remain self-hosted."
fi
