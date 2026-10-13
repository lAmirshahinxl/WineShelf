import type { Metadata, Viewport } from "next";
import Script from "next/script";
import type { ReactNode } from "react";
import { preload } from "react-dom";
import "../styles.css";
import "../performance-chart.css";
import "../slider/src/index.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://wineshelf.site"),
  verification: {
    google: "sjxPcDAiGoMYqedFGo4xssraqgpqEvLDnJVNDK2VnfM",
  },
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
  themeColor: "#0b0c1d",
};

const gameBannerImages = [
  "baldurs-gate-3.jpg",
  "call-of-duty-modern-warfare-iii.jpg",
  "counter-strike-2.jpg",
  "cyberpunk-2077.jpg",
  "dota-2.jpg",
  "elden-ring.jpg",
  "grand-theft-auto-v.jpg",
  "red-dead-redemption-2.jpg",
  "the-witcher-3.jpg",
  "apex-legends.jpg",
];

const googleAnalyticsId = "G-SY484H8QFC";

export default function RootLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  for (const image of gameBannerImages) {
    preload(`/assets/game-banners/${image}`, { as: "image" });
  }

  return (
    <html lang="en">
      <body>
        {children}
        <Script
          src={`https://www.googletagmanager.com/gtag/js?id=${googleAnalyticsId}`}
          strategy="afterInteractive"
        />
        <Script id="google-analytics" strategy="afterInteractive">
          {`window.dataLayer = window.dataLayer || [];
function gtag(){window.dataLayer.push(arguments);}
gtag('js', new Date());
gtag('config', '${googleAnalyticsId}');`}
        </Script>
      </body>
    </html>
  );
}
