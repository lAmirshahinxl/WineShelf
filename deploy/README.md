# Website deployment

The deploy script builds the static Next.js export from `website/` and syncs
the generated files to the Nginx document root configured for `wineshelf.site`.
It also downloads the latest universal DMG from the private GitHub repository
and serves it at `/downloads/WineShelf-universal.dmg`, so visitors can download
the app without GitHub access.

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

The sync adds and overwrites files without deleting remote files. Next.js emits
content-hashed static assets, and the deploy script adds the release version to
both DMG download links in the exported HTML. No SSH keys or server-specific
target values belong in Git.
