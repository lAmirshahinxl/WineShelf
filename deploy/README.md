# Website deployment

The deploy script syncs the contents of `website/` to the Nginx document root
configured for `wineshelf.site`.

## Configure once

Create the ignored local config and set the SSH alias or direct origin address:

```sh
cp deploy/deploy-site.local.example deploy/deploy-site.local
```

Edit `deploy/deploy-site.local` so `WINESHELF_DEPLOY_TARGET` names an SSH
config alias or `user@origin-ip`. The SSH account must already have write
access to `/var/www/wineshelf.site`, or to the directory selected with
`WINESHELF_DEPLOY_PATH`.

## Deploy

From the repository root, preview the transfer first:

```sh
./deploy/deploy-site.sh --dry-run
```

Run the sync when the target looks right:

```sh
./deploy/deploy-site.sh
```

The sync adds and overwrites files without deleting remote files. It generates
a content-hash stylesheet URL in the deployed HTML so browser and CDN caches
fetch the matching CSS after every change. No SSH keys or server-specific target
values belong in Git.
