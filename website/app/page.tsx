import type { CSSProperties } from "react";
import BlockFeature from "../slider/src/components/ui/block-feature";
import { GameSlider } from "../slider/src/game-slider";
import { BurinHatch } from "@/components/ui/hero-burin-hatch";
import { ScannerCardStream } from "@/components/ui/scanner-card-stream";

export default function HomePage() {
  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="site-header">
        {" "}
        <div className="header-inner shell">
          {" "}
          <a className="brand" href="#top" aria-label="WineShelf home">
            {" "}
            <img
              src="/assets/wineshelf-icon.png"
              alt=""
              width="42"
              height="42"
            />{" "}
            <span>
              Wine<span className="brand-light">Shelf</span>
            </span>{" "}
          </a>
          <nav className="main-nav" aria-label="Main navigation">
            {" "}
            <a href="#features">Features</a> <a href="#translation">Translation</a>{" "}
            <a href="#setup">How it works</a>{" "}
            <a href="#games">Games</a> <a href="#performance">Performance</a>{" "}
            <a href="#compatibility">Compatibility</a>{" "}
          </nav>
          <a
            className="header-download"
            href="/downloads/WineShelf-universal.dmg?v=source"
            download="WineShelf-universal.dmg"
          >
            {" "}
            Download <span aria-hidden="true">↓</span>{" "}
          </a>{" "}
        </div>{" "}
      </header>
      <main id="main">
        {" "}
        <BurinHatch
          eyebrow="A WINDOWS GAME LIBRARY FOR MACOS"
          headline={["Windows games,", "at home on Mac."]}
          subcopy="WineShelf prepares the Wine runtime, guides setup, and keeps your Windows games and launch options together in one native Mac library."
          primaryCta={{
            label: "Get WineShelf",
            href: "/downloads/WineShelf-universal.dmg?v=source",
          }}
          secondaryCta={{
            label: "Explore the project",
            href: "https://github.com/lAmirshahinxl/WineShelf",
          }}
          plateLabel="A cyan copperplate engraving of a sphere. Hatch lines deepen in shadow and thin to bare paper in the light, representing WineShelf's Windows-to-Mac translation."
          className="hero-burin-home w-full"
        />
        <div className="capability-ribbon" aria-label="WineShelf highlights">
          {" "}
          <div className="ribbon-inner shell">
            {" "}
            <span>
              <i className="ribbon-mark mark-cyan" aria-hidden="true"></i>{" "}
              Native macOS app
            </span>{" "}
            <span>
              <i className="ribbon-mark mark-coral" aria-hidden="true"></i>{" "}
              WineShelf runtime setup
            </span>{" "}
            <span>
              <i className="ribbon-mark mark-white" aria-hidden="true"></i> Free
              and open source
            </span>{" "}
          </div>{" "}
        </div>
        <section
          className="translation-section"
          id="translation"
          aria-labelledby="translation-title"
        >
          <div className="translation-inner shell">
            <div className="translation-heading">
              <p className="eyebrow">
                <span className="eyebrow-dot" aria-hidden="true" /> Windows
                → macOS with WineShelf
              </p>
              <h2 id="translation-title">
                Intel in.
                <br />
                <span>Apple silicon out.</span>
              </h2>
              <p>
                WineShelf prepares the compatibility runtime for Windows apps
                on macOS. Watch Intel processor chips pass through the scanner
                and emerge as Apple silicon.
              </p>
            </div>
            <ScannerCardStream />
            <p className="translation-note">
              The Intel-to-Apple chip change is a visual metaphor for
              WineShelf’s Windows-to-macOS compatibility setup; it does not
              represent a physical processor conversion.
            </p>
          </div>
        </section>
        <section
          className="features section"
          id="features"
          aria-labelledby="features-title"
        >
          {" "}
          <div className="section-heading shell">
            {" "}
            <p className="eyebrow eyebrow-dark">What WineShelf handles</p>{" "}
            <h2 id="features-title">
              Less setup between you
              <br />
              <span>and your games.</span>
            </h2>{" "}
            <p className="section-intro">
              Prepare Wine, add Windows apps, and keep launch settings with each
              entry. WineShelf puts the pieces in one Mac library.
            </p>{" "}
          </div>{" "}
          <div id="feature-block-root" className="feature-grid-shell">
            <BlockFeature />
          </div>{" "}
        </section>
        <section
          className="games-showcase"
          id="games"
          aria-labelledby="games-title"
        >
          {" "}
          <div className="games-showcase-heading shell">
            {" "}
            <p className="eyebrow eyebrow-dark">Games on your shelf</p>{" "}
            <h2 id="games-title">
              A closer look at the games
              <br />
              <span>you want to play.</span>
            </h2>{" "}
            <p>
              Explore familiar PC favorites in a continuous, curved showcase.
            </p>{" "}
          </div>{" "}
          <div id="game-slider-root" className="games-slider-shell">
            <GameSlider />
          </div>{" "}
        </section>
        <section
          className="setup-section"
          id="setup"
          aria-labelledby="setup-title"
        >
          {" "}
          <div className="setup-inner shell">
            {" "}
            <div className="setup-heading">
              {" "}
              <p className="eyebrow">
                <span className="eyebrow-dot" aria-hidden="true"></span> Your
                route from setup to launch
              </p>{" "}
              <h2 id="setup-title">
                Start with what you have.
                <br />
                <span>Build your shelf from there.</span>
              </h2>{" "}
            </div>{" "}
            <div className="setup-steps">
              {" "}
              <article className="setup-step">
                {" "}
                <span className="step-label">FIRST, THE FOUNDATION</span>{" "}
                <div className="step-index">
                  A<span>.</span>
                </div>{" "}
                <h3>Prepare Wine</h3>{" "}
                <p>
                  WineShelf walks you through the Mac requirements and gets its
                  managed Wine runtime ready.
                </p>{" "}
              </article>{" "}
              <article className="setup-step">
                {" "}
                <span className="step-label">THEN, YOUR GAMES</span>{" "}
                <div className="step-index">
                  B<span>.</span>
                </div>{" "}
                <h3>Install or add</h3>{" "}
                <p>
                  Continue with Steam, add a Windows executable, or connect an
                  existing Wine setup.
                </p>{" "}
              </article>{" "}
              <article className="setup-step">
                {" "}
                <span className="step-label">FINALLY, YOUR LIBRARY</span>{" "}
                <div className="step-index">
                  C<span>.</span>
                </div>{" "}
                <h3>Launch from one shelf</h3>{" "}
                <p>
                  Keep your Windows apps and Steam shortcuts together with their
                  prefixes and launch settings.
                </p>{" "}
              </article>{" "}
            </div>{" "}
          </div>{" "}
        </section>
        <section
          className="performance-section section shell"
          id="performance"
          aria-labelledby="performance-title"
        >
          {" "}
          <div className="performance-heading">
            {" "}
            <div className="performance-heading-copy">
              {" "}
              <p className="eyebrow eyebrow-dark">
                Player reports · Wine-based setups
              </p>{" "}
              <h2 id="performance-title">What players have reported.</h2>{" "}
            </div>{" "}
          </div>
          <figure
            className="performance-chart"
            aria-labelledby="fps-chart-title"
            aria-describedby="fps-chart-note"
          >
            {" "}
            <figcaption className="fps-chart-caption">
              {" "}
              <div>
                {" "}
                <p className="fps-chart-kicker">FPS snapshots</p>{" "}
                <h3 id="fps-chart-title">
                  A quick read across reported results.
                </h3>{" "}
                <p id="fps-chart-note">
                  Reports use different Macs, settings, and Wine-based tools, so
                  treat these as snapshots rather than a controlled comparison.
                </p>{" "}
              </div>{" "}
              <span className="fps-chart-scale">Scale · 0–140 FPS</span>{" "}
            </figcaption>
            <div className="fps-chart-axis" aria-hidden="true">
              {" "}
              <span>Game</span>{" "}
              <div className="fps-axis-values">
                <span>0</span>
                <span>35</span>
                <span>70</span>
                <span>105</span>
                <span>140 FPS</span>
              </div>{" "}
              <span>Reported</span>{" "}
            </div>
            <ul
              className="fps-chart-rows"
              aria-label="Reported frame rates by game"
            >
              {" "}
              <li className="fps-chart-row">
                {" "}
                <span className="fps-chart-game">Counter-Strike 2</span>{" "}
                <span className="fps-track" aria-hidden="true">
                  <span
                    className="fps-fill"
                    style={{ "--fps-length": "21.4%" } as CSSProperties}
                  ></span>
                  <span
                    className="fps-range"
                    style={
                      {
                        "--fps-start": "21.4%",
                        "--fps-length": "70%",
                      } as CSSProperties
                    }
                  ></span>
                </span>{" "}
                <span className="fps-chart-value">
                  30–128 <small>range</small>
                </span>{" "}
              </li>{" "}
              <li className="fps-chart-row">
                {" "}
                <span className="fps-chart-game">Dota 2</span>{" "}
                <span className="fps-track" aria-hidden="true">
                  <span
                    className="fps-fill fps-point"
                    style={{ "--fps-length": "21.7%" } as CSSProperties}
                  ></span>
                </span>{" "}
                <span className="fps-chart-value">
                  30.4 <small>avg</small>
                </span>{" "}
              </li>{" "}
              <li className="fps-chart-row">
                {" "}
                <span className="fps-chart-game">Cyberpunk 2077</span>{" "}
                <span className="fps-track" aria-hidden="true">
                  <span
                    className="fps-fill fps-point"
                    style={{ "--fps-length": "35.7%" } as CSSProperties}
                  ></span>
                </span>{" "}
                <span className="fps-chart-value">
                  50 <small>median</small>
                </span>{" "}
              </li>{" "}
              <li className="fps-chart-row">
                {" "}
                <span className="fps-chart-game">GTA V · Legacy</span>{" "}
                <span className="fps-track" aria-hidden="true">
                  <span
                    className="fps-fill"
                    style={{ "--fps-length": "50%" } as CSSProperties}
                  ></span>
                  <span
                    className="fps-range"
                    style={
                      {
                        "--fps-start": "50%",
                        "--fps-length": "7.1%",
                      } as CSSProperties
                    }
                  ></span>
                </span>{" "}
                <span className="fps-chart-value">
                  70–80 <small>range</small>
                </span>{" "}
              </li>{" "}
              <li className="fps-chart-row">
                {" "}
                <span className="fps-chart-game">
                  Red Dead Redemption 2
                </span>{" "}
                <span className="fps-track" aria-hidden="true">
                  <span
                    className="fps-fill fps-point"
                    style={{ "--fps-length": "39.3%" } as CSSProperties}
                  ></span>
                </span>{" "}
                <span className="fps-chart-value">
                  55 <small>median</small>
                </span>{" "}
              </li>{" "}
              <li className="fps-chart-row">
                {" "}
                <span className="fps-chart-game">Baldur’s Gate 3</span>{" "}
                <span className="fps-track" aria-hidden="true">
                  <span
                    className="fps-fill fps-point"
                    style={{ "--fps-length": "42.9%" } as CSSProperties}
                  ></span>
                </span>{" "}
                <span className="fps-chart-value">
                  60 <small>median</small>
                </span>{" "}
              </li>{" "}
              <li className="fps-chart-row">
                {" "}
                <span className="fps-chart-game">The Witcher 3</span>{" "}
                <span className="fps-track" aria-hidden="true">
                  <span
                    className="fps-fill"
                    style={{ "--fps-length": "28.6%" } as CSSProperties}
                  ></span>
                  <span
                    className="fps-range"
                    style={
                      {
                        "--fps-start": "28.6%",
                        "--fps-length": "14.3%",
                      } as CSSProperties
                    }
                  ></span>
                </span>{" "}
                <span className="fps-chart-value">
                  40–60 <small>range</small>
                </span>{" "}
              </li>{" "}
              <li className="fps-chart-row">
                {" "}
                <span className="fps-chart-game">Elden Ring</span>{" "}
                <span className="fps-track" aria-hidden="true">
                  <span
                    className="fps-fill"
                    style={{ "--fps-length": "35.7%" } as CSSProperties}
                  ></span>
                  <span
                    className="fps-range"
                    style={
                      {
                        "--fps-start": "35.7%",
                        "--fps-length": "7.2%",
                      } as CSSProperties
                    }
                  ></span>
                </span>{" "}
                <span className="fps-chart-value">
                  50–60 <small>range</small>
                </span>{" "}
              </li>{" "}
            </ul>
            <div
              className="fps-chart-legend"
              role="group"
              aria-label="Chart legend"
            >
              {" "}
              <span>
                <i className="fps-legend-fill" aria-hidden="true"></i> FPS to
                the reported value
              </span>{" "}
              <span>
                <i className="fps-legend-range" aria-hidden="true"></i> Spread
                between reported low and high
              </span>{" "}
            </div>{" "}
          </figure>
          <div className="performance-table-wrap">
            {" "}
            <table className="performance-table">
              {" "}
              <caption className="visually-hidden">
                Community-reported frame rates for Windows games running in
                Wine-based configurations.
              </caption>{" "}
              <thead>
                {" "}
                <tr>
                  {" "}
                  <th scope="col">Game</th>{" "}
                  <th scope="col">
                    Community FPS reports by Mac and setup
                  </th>{" "}
                </tr>{" "}
              </thead>{" "}
              <tbody>
                {" "}
                <tr>
                  {" "}
                  <th scope="row">Counter-Strike 2</th>{" "}
                  <td>
                    {" "}
                    <ul className="performance-reports">
                      {" "}
                      <li>
                        <span className="report-configuration">
                          M2 MacBook Air
                        </span>
                        <span className="fps-value">30–40 FPS</span>
                        <a
                          href="https://www.reddit.com/r/macgaming/comments/1wd02i4/cs2_on_mac/"
                          aria-label="Counter-Strike 2 report for M2 MacBook Air"
                        >
                          Report ↗
                        </a>
                      </li>{" "}
                      <li>
                        <span className="report-configuration">
                          M2 MacBook Air · 8 GB
                        </span>
                        <span className="fps-value">About 100 FPS</span>
                        <a
                          href="https://www.reddit.com/r/cs2/comments/1wsc8hk/how_rare_is_this/"
                          aria-label="Counter-Strike 2 report for M2 MacBook Air with 8 GB"
                        >
                          Report ↗
                        </a>
                      </li>{" "}
                      <li>
                        <span className="report-configuration">
                          14-inch MacBook Pro · M1 Pro · 16 GB · CrossOver
                        </span>
                        <span className="fps-value">75–115 FPS</span>
                        <a
                          href="https://www.reddit.com/r/macgaming/comments/1waxdn9/cs2_crossover_inconsistent_frame_times/"
                          aria-label="Counter-Strike 2 CrossOver report for 14-inch MacBook Pro with M1 Pro and 16 GB"
                        >
                          Report ↗
                        </a>
                      </li>{" "}
                      <li>
                        <span className="report-configuration">
                          Base M4 Mac mini · CrossOver + CXPatcher
                        </span>
                        <span className="fps-value">90–120 FPS</span>
                        <a
                          href="https://www.reddit.com/r/macgaming/comments/1tni5zl/m4_mac_mini_base_crossover_patched/"
                          aria-label="Counter-Strike 2 report for base M4 Mac mini using CrossOver and CXPatcher"
                        >
                          Report ↗
                        </a>
                      </li>{" "}
                      <li>
                        <span className="report-configuration">
                          MacBook Pro · M2 Pro · 32 GB · Wine + DXMT
                        </span>
                        <span className="fps-value">About 128 FPS</span>
                        <a
                          href="https://github.com/piwas-21/cs2-apple-silicon/blob/main/docs/project/measured-results.md"
                          aria-label="Counter-Strike 2 Wine and DXMT benchmark for MacBook Pro with M2 Pro and 32 GB"
                        >
                          Benchmark ↗
                        </a>
                      </li>{" "}
                    </ul>{" "}
                  </td>{" "}
                </tr>{" "}
                <tr>
                  {" "}
                  <th scope="row">Dota 2</th>{" "}
                  <td>
                    <ul className="performance-reports">
                      <li>
                        <span className="report-configuration">
                          M5 MacBook Air · 32 GB · Windows client via CrossOver
                          Intel, Rosetta, and DXMT · fixed replay
                        </span>
                        <span className="fps-value">30.4 avg FPS</span>
                        <a
                          href="https://www.blendlogic.com/posts/crossover-arm64-fex-mac-gaming.html"
                          aria-label="Dota 2 fixed-replay benchmark on M5 MacBook Air using the Windows client through CrossOver Intel, Rosetta, and DXMT"
                        >
                          Benchmark ↗
                        </a>
                      </li>
                    </ul>
                  </td>{" "}
                </tr>{" "}
                <tr>
                  {" "}
                  <th scope="row">Cyberpunk 2077</th>{" "}
                  <td>
                    <ul className="performance-reports">
                      <li>
                        <span className="report-configuration">
                          Apple silicon · CrossOver · 19 reports across M1–M5
                        </span>
                        <span className="fps-value">Median 50 FPS</span>
                        <a
                          href="https://macgamingdb.app/games/cyberpunk-2077"
                          aria-label="Cyberpunk 2077 CrossOver community median from 19 Apple silicon reports"
                        >
                          Community data ↗
                        </a>
                      </li>
                    </ul>
                  </td>{" "}
                </tr>{" "}
                <tr>
                  {" "}
                  <th scope="row">Grand Theft Auto V (Legacy)</th>{" "}
                  <td>
                    <ul className="performance-reports">
                      <li>
                        <span className="report-configuration">
                          M1 MacBook Air · 8 GB · Steam + CrossOver 23.7 ·
                          custom DXVK
                        </span>
                        <span className="fps-value">70–80 FPS</span>
                        <a
                          href="https://www.reddit.com/r/macgaming/comments/1anh0gd/stutter_on_gta_v_crossover_macbook_m1_8gb/"
                          aria-label="Grand Theft Auto V Legacy report for M1 MacBook Air with 8 GB"
                        >
                          Report ↗
                        </a>
                      </li>
                    </ul>
                  </td>{" "}
                </tr>{" "}
                <tr>
                  {" "}
                  <th scope="row">Red Dead Redemption 2</th>{" "}
                  <td>
                    <ul className="performance-reports">
                      <li>
                        <span className="report-configuration">
                          Apple silicon · CrossOver · 45 reports across M1–M5
                        </span>
                        <span className="fps-value">Median 55 FPS</span>
                        <a
                          href="https://macgamingdb.app/games/red-dead-redemption-2"
                          aria-label="Red Dead Redemption 2 CrossOver community median from 45 Apple silicon reports"
                        >
                          Community data ↗
                        </a>
                      </li>
                    </ul>
                  </td>{" "}
                </tr>{" "}
                <tr>
                  {" "}
                  <th scope="row">Baldur’s Gate 3</th>{" "}
                  <td>
                    <ul className="performance-reports">
                      <li>
                        <span className="report-configuration">
                          Apple silicon · CrossOver · 3 reports across M1–M5
                        </span>
                        <span className="fps-value">Median 60 FPS</span>
                        <a
                          href="https://macgamingdb.app/games/baldur-s-gate-3"
                          aria-label="Baldur’s Gate 3 CrossOver community median from 3 Apple silicon reports"
                        >
                          Community data ↗
                        </a>
                      </li>
                    </ul>
                  </td>{" "}
                </tr>{" "}
                <tr>
                  {" "}
                  <th scope="row">The Witcher 3</th>{" "}
                  <td>
                    <ul className="performance-reports">
                      <li>
                        <span className="report-configuration">
                          M1 MacBook Air · 8 GB · Steam + CrossOver · medium
                          settings
                        </span>
                        <span className="fps-value">40–60 FPS</span>
                        <a
                          href="https://applesilicongames.com/games/GdnUQRXMTXJshNj2xHHPq3/witcher-3"
                          aria-label="The Witcher 3 report for M1 MacBook Air with 8 GB at medium settings"
                        >
                          Report ↗
                        </a>
                      </li>
                    </ul>
                  </td>{" "}
                </tr>{" "}
                <tr>
                  {" "}
                  <th scope="row">Elden Ring</th>{" "}
                  <td>
                    <ul className="performance-reports">
                      <li>
                        <span className="report-configuration">
                          Base M4 Mac mini · 16 GB · CrossOver + D3DMetal
                        </span>
                        <span className="fps-value">50–60 FPS</span>
                        <a
                          href="https://macgamingdb.app/games/elden-ring"
                          aria-label="Elden Ring reports for base M4 Mac mini with 16 GB using CrossOver and D3DMetal"
                        >
                          Reports ↗
                        </a>
                      </li>
                    </ul>
                  </td>{" "}
                </tr>{" "}
              </tbody>{" "}
            </table>{" "}
          </div>{" "}
          <p className="performance-footnote">
            WineShelf uses its own pinned Wine runtime. The reports above show
            other specific Wine-based configurations and don't predict WineShelf
            results.
          </p>{" "}
        </section>
        <section
          className="compatibility-section section shell"
          id="compatibility"
          aria-labelledby="compatibility-title"
        >
          {" "}
          <div className="compatibility-symbol" aria-hidden="true">
            {" "}
            <span className="compat-ring"></span>{" "}
            <span className="compat-core">!</span>{" "}
          </div>{" "}
          <div className="compatibility-copy">
            {" "}
            <p className="eyebrow eyebrow-dark">
              A clear note before you download
            </p>{" "}
            <h2 id="compatibility-title">
              Every game is
              <br />
              <span>its own story.</span>
            </h2>{" "}
            <p>
              Wine does not cover every Windows API or graphics feature, and
              game-specific launchers, DRM, or anti-cheat can also block a
              title. WineShelf checks and prepares the runtime, guides required
              components, and keeps prefixes and launch options together so you
              can tune a supported setup. Some games still need extra work or
              may not run, and FPS varies by game and Mac. WineShelf does not
              include game files or licenses.
            </p>{" "}
            <a className="text-link" href="#performance">
              See community FPS reports <span aria-hidden="true">↗</span>
            </a>{" "}
          </div>{" "}
          <div className="compatibility-stamp" aria-hidden="true">
            {" "}
            <span>MAC</span>
            <b>≠</b>
            <span>WINDOWS</span>{" "}
          </div>{" "}
        </section>
        <section className="download-section" aria-labelledby="download-title">
          {" "}
          <div className="download-inner shell">
            {" "}
            <div>
              {" "}
              <p className="eyebrow">
                <span className="eyebrow-dot" aria-hidden="true"></span> Your
                next game night starts here
              </p>{" "}
              <h2 id="download-title">
                Make room
                <br />
                on your shelf.
              </h2>{" "}
              <p>WineShelf is free to download for macOS 14 and later.</p>{" "}
            </div>{" "}
            <div className="download-action">
              {" "}
              <a
                className="button button-download"
                href="/downloads/WineShelf-universal.dmg?v=source"
                download="WineShelf-universal.dmg"
              >
                Download the latest release <span aria-hidden="true">↓</span>
              </a>{" "}
              <p>Universal app for Intel and Apple silicon Macs.</p>{" "}
            </div>{" "}
          </div>{" "}
        </section>{" "}
      </main>
      <footer className="site-footer">
        {" "}
        <div className="footer-inner shell">
          {" "}
          <a
            className="brand footer-brand"
            href="#top"
            aria-label="WineShelf home"
          >
            {" "}
            <img
              src="/assets/wineshelf-icon.png"
              alt=""
              width="36"
              height="36"
            />{" "}
            <span>
              Wine<span className="brand-light">Shelf</span>
            </span>{" "}
          </a>{" "}
          <p>Made for Mac gamers. Open source under the MIT License.</p>{" "}
          <nav className="footer-links" aria-label="Footer navigation">
            {" "}
            <a href="https://github.com/lAmirshahinxl/WineShelf">GitHub</a>{" "}
            <a href="https://github.com/lAmirshahinxl/WineShelf/issues">
              Feedback
            </a>{" "}
            <a href="https://github.com/lAmirshahinxl/WineShelf/releases">
              Releases
            </a>{" "}
          </nav>{" "}
          <span className="footer-copy">© 2026 WineShelf</span>{" "}
        </div>{" "}
      </footer>
    </>
  );
}
