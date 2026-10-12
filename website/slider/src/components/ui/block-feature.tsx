import {
  ArrowDownToLine,
  ArrowUpRight,
  Check,
  FileDown,
  FolderOpen,
  Laptop,
  SlidersHorizontal,
  Wine,
} from "lucide-react";
import { IconBrandSteam } from "@tabler/icons-react";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

function Card({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return <article className={cn("feature-card", className)}>{children}</article>;
}

function CardHeading({
  icon,
  label,
  title,
  children,
}: {
  icon: ReactNode;
  label: string;
  title: string;
  children: ReactNode;
}) {
  return (
    <div className="feature-card-copy">
      <p className="feature-card-label">
        <span className="feature-card-icon" aria-hidden="true">
          {icon}
        </span>
        {label}
      </p>
      <h3>{title}</h3>
      <p>{children}</p>
    </div>
  );
}

function StatusRow({ children }: { children: ReactNode }) {
  return (
    <div className="feature-status-row">
      <span className="feature-status-check" aria-hidden="true">
        <Check />
      </span>
      <span>{children}</span>
      <span className="feature-status-ready">READY</span>
    </div>
  );
}

export default function BlockFeature() {
  return (
    <div className={cn("feature-grid grid gap-5 md:grid-cols-2 lg:grid-cols-3")}>
      <Card className="feature-card-runtime">
        <div className="runtime-visual" aria-hidden="true">
          <div className="visual-window-bar">
            <span className="window-dots"><i /><i /><i /></span>
            <span>WINE SETUP</span>
            <span className="visual-window-state">CHECKLIST</span>
          </div>
          <div className="runtime-visual-body">
            <div className="runtime-mark"><Wine /></div>
            <div className="runtime-checks">
              <StatusRow>Mac requirements</StatusRow>
              <StatusRow>Verified Wine runtime</StatusRow>
              <StatusRow>Steam setup, when you need it</StatusRow>
            </div>
          </div>
          <div className="runtime-visual-foot">
            <span>ONE GUIDED SETUP</span>
            <span>MACOS 14+</span>
          </div>
        </div>
        <CardHeading
          icon={<Wine />}
          label="Managed Wine setup"
          title="Get the foundation ready."
        >
          WineShelf checks your Mac, prepares its pinned Wine runtime, and guides you through the required setup.
        </CardHeading>
      </Card>

      <Card className="feature-card-steam">
        <div className="steam-visual" aria-hidden="true">
          <div className="steam-app-tile"><IconBrandSteam /></div>
          <div className="steam-visual-copy">
            <span>STEAM PREFIX</span>
            <strong>Your games, within reach.</strong>
            <span className="steam-open-label">OPEN GAME PAGE <ArrowUpRight /></span>
          </div>
        </div>
        <CardHeading
          icon={<IconBrandSteam />}
          label="Steam games"
          title="Install, then launch from your shelf."
        >
          Open a supported game’s Steam page in WineShelf’s Steam setup. A shortcut joins your library after the install finishes.
        </CardHeading>
      </Card>

      <Card className="feature-card-exe">
        <div className="exe-visual" aria-hidden="true">
          <div className="exe-file"><FileDown /><span>setup.exe</span></div>
          <span className="exe-arrow"><ArrowDownToLine /></span>
          <div className="exe-destination"><FolderOpen /><span>Wine prefix</span></div>
        </div>
        <CardHeading
          icon={<FileDown />}
          label="Windows apps"
          title="Bring an installer. Keep the setup."
        >
          Choose or drop a Windows executable. WineShelf prepares a fresh prefix, launches it, and adds the app to your library.
        </CardHeading>
      </Card>

      <Card className="feature-card-library">
        <div className="library-visual" aria-hidden="true">
          <div className="library-visual-heading">
            <FolderOpen />
            <span>YOUR LIBRARY</span>
            <span className="library-count">TOGETHER</span>
          </div>
          <div className="library-row"><span className="library-app-mark mark-steam"><IconBrandSteam /></span><span>Steam shortcuts</span><ArrowUpRight /></div>
          <div className="library-row"><span className="library-app-mark mark-wine"><Wine /></span><span>Windows apps</span><ArrowUpRight /></div>
          <div className="library-row"><span className="library-app-mark mark-settings"><SlidersHorizontal /></span><span>Prefixes &amp; settings</span><ArrowUpRight /></div>
        </div>
        <CardHeading
          icon={<FolderOpen />}
          label="One game library"
          title="Keep your Windows games together."
        >
          Steam shortcuts and Windows apps live side by side, with each entry’s Wine prefix and launch settings close at hand.
        </CardHeading>
      </Card>

      <Card className="feature-card-controls">
        <div className="controls-visual" aria-hidden="true">
          <div className="controls-heading"><SlidersHorizontal /><span>APP SETTINGS</span><span className="controls-menu">•••</span></div>
          <div className="controls-field">
            <span>LAUNCH ARGUMENTS</span>
            <code>-windowed</code>
          </div>
          <div className="controls-field">
            <span>ENVIRONMENT</span>
            <code>DXVK_HUD=0</code>
          </div>
          <div className="controls-saved"><Check /><span>Saved with this app</span></div>
        </div>
        <CardHeading
          icon={<SlidersHorizontal />}
          label="Per-app controls"
          title="Tune the launch for each title."
        >
          Set launch arguments and environment options per app, then keep its Wine setup and logs nearby.
        </CardHeading>
      </Card>

      <Card className="feature-card-mac">
        <div className="mac-visual" aria-hidden="true">
          <div className="mac-visual-heading"><Laptop /><span>MADE FOR MAC</span></div>
          <div className="mac-platform-row">
            <div><span className="platform-symbol">Intel</span><strong>Intel Mac</strong><small>Native x86_64</small></div>
            <span className="platform-divider" />
            <div><span className="platform-symbol platform-apple">M</span><strong>Apple silicon</strong><small>Wine through Rosetta 2</small></div>
          </div>
          <span className="mac-requirement">UNIVERSAL APP · MACOS 14 OR LATER</span>
        </div>
        <CardHeading
          icon={<Laptop />}
          label="Mac support"
          title="One app for Intel and Apple silicon."
        >
          WineShelf is a universal macOS app. Its managed Wine runtime uses Rosetta 2 on Apple silicon Macs.
        </CardHeading>
      </Card>
    </div>
  );
}
