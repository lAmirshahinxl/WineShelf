import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "../styles.css";
import "../performance-chart.css";
import "../slider/src/index.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://wineshelf.site"),
  title: "WineShelf — Your Windows games, at home on Mac",
  description:
    "WineShelf prepares Wine for macOS, guides Steam and Windows app setup, and keeps games and launch options in one library.",
  alternates: {
    canonical: "/",
  },
  openGraph: {
    type: "website",
    title: "WineShelf — Your Windows games, at home on Mac",
    description:
      "Prepare Wine, set up Steam or Windows apps, and manage game prefixes and launch options from one Mac library.",
    url: "/",
    images: ["/assets/game-shelf.png"],
  },
  icons: {
    icon: "/assets/favicon-32.png",
    apple: "/assets/wineshelf-icon.png",
  },
};

export const viewport: Viewport = {
  themeColor: "#071638",
};

export default function RootLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
