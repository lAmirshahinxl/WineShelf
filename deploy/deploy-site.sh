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

for command_name in rsync ssh shasum cut sed cp mktemp grep; do
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

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/wineshelf-site-deploy.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
cp -pR "$website_dir/." "$staging_dir/"

css_hash="$(shasum -a 256 "$staging_dir/styles.css" | cut -c1-12)"
stylesheet_placeholder='href="/styles.css?v=source"'
if ! grep -Fq "$stylesheet_placeholder" "$staging_dir/index.html"; then
  echo "Expected stylesheet placeholder was not found in website/index.html." >&2
  exit 1
fi

sed "s|href=\"/styles\\.css?v=source\"|href=\"/styles.css?v=${css_hash}\"|" \
  "$staging_dir/index.html" > "$staging_dir/index.html.tmp"
mv "$staging_dir/index.html.tmp" "$staging_dir/index.html"

rsync_options=(-rltz --checksum --human-readable)
if (( dry_run )); then
  rsync_options+=(--dry-run --itemize-changes)
  echo "Previewing website sync to $target:$remote_path (stylesheet version $css_hash)"
else
  echo "Syncing website to $target:$remote_path (stylesheet version $css_hash)"
fi

rsync "${rsync_options[@]}" -e 'ssh -o BatchMode=yes -o ConnectTimeout=10' -- \
  "$staging_dir/" "$target:$remote_path/"

if (( dry_run )); then
  echo "Dry run complete. No server files were changed."
else
  echo "Website sync complete."
fi
