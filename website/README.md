# WineShelf website

The website is a Next.js App Router project in this directory. It uses React
components for the feature cards and game showcase and exports static files for
the existing Nginx host.

## Requirements

- Node.js 20.9 or later
- npm

## Development and build

```sh
npm install
npm run dev
```

Create the static site with:

```sh
npm run build
```

The export is written to `out/`. To preview it locally, serve that directory
with any static file server. The repository deploy script builds this export,
adds the latest WineShelf DMG, and syncs the result to the configured Nginx
document root.
