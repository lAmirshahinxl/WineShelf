# Website deployment

The deploy script syncs the contents of `website/` to the Nginx document root
configured for `wineshelf.site`. It also downloads the latest universal DMG
from the private GitHub repository and serves it at
`/downloads/WineShelf-universal.dmg`, so visitors can download the app without
GitHub access.

## Configure once

Create the ignored local config and set the SSH alias or direct origin address:

```sh
cp deploy/deploy-site.local.example deploy/deploy-site.local
```

Edit `deploy/deploy-site.local` so `WINESHELF_DEPLOY_TARGET` names an SSH
config alias or `user@origin-ip`. The SSH account must already have write
access to `/var/www/wineshelf.site`, or to the directory selected with
`WINESHELF_DEPLOY_PATH`. Install GitHub CLI and authenticate it with an account
that can read the private WineShelf repository; the deploy script uses it to
fetch the release DMG.

## Deploy

From the repository root, preview the transfer first:

```sh
./deploy/deploy-site.sh --dry-run
```

Run the sync when the target looks right:

```sh
./deploy/deploy-site.sh
```

The sync builds the React/TypeScript game showcase with Vite, adds and overwrites
files without deleting remote files, and removes the slider source project from
the public staging directory. It generates content-hash URLs for the page and
slider stylesheets and script, plus a release-versioned download URL in the
deployed HTML, so browser and CDN caches fetch the matching files after an
update.

The curved slider sets per-tile geometry at runtime. After a successful sync,
the script updates the WineShelf Nginx Content Security Policy to allow inline
styles for that geometry, validates the Nginx configuration, and reloads it.
Scripts remain self-hosted and the script restores the prior config if Nginx
validation fails. The SSH account needs passwordless sudo for this Nginx update.
No SSH keys or server-specific target values belong in Git.
