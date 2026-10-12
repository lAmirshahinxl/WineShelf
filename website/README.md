# WineShelf website

The website is a Next.js App Router project in this directory. It uses React
components for the feature cards and game showcase and exports static files for
the existing Nginx host.

The active home page is `app/page.tsx`. The root `index.html` is retained as a
reference to the previous static source; it is not included in the Next.js
export or deployment.

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

## Design system

The landing page uses a local shadcn/ui component layer for buttons, cards, and
badges. Its component setup is in `components.json`; shared color and radius
tokens are in `slider/src/index.css`, and site-wide composition and motion live
in `styles.css`. UI components are stored in `slider/src/components/ui/` to
match the existing import alias. Add further shadcn/ui components from this
directory with `npx shadcn@latest add <component>`.
