import { TiltedGridHero, type TiltedGridImage } from "@/components/ui/tilted-grid-hero";

const GAME_IMAGES: TiltedGridImage[] = [
  { src: "/assets/game-banners/counter-strike-2.jpg", alt: "Counter-Strike 2" },
  { src: "/assets/game-banners/dota-2.jpg", alt: "Dota 2" },
  { src: "/assets/game-banners/call-of-duty-modern-warfare-iii.jpg", alt: "Call of Duty: Modern Warfare III" },
  { src: "/assets/game-banners/cyberpunk-2077.jpg", alt: "Cyberpunk 2077" },
  { src: "/assets/game-banners/grand-theft-auto-v.jpg", alt: "Grand Theft Auto V" },
  { src: "/assets/game-banners/elden-ring.jpg", alt: "Elden Ring" },
  { src: "/assets/game-banners/baldurs-gate-3.jpg", alt: "Baldur’s Gate 3" },
  { src: "/assets/game-banners/the-witcher-3.jpg", alt: "The Witcher 3" },
  { src: "/assets/game-banners/red-dead-redemption-2.jpg", alt: "Red Dead Redemption 2" },
  { src: "/assets/game-banners/apex-legends.jpg", alt: "Apex Legends" },
];

export function GameSlider() {
  return (
    <TiltedGridHero images={GAME_IMAGES} className="games-carousel-frame">
      <div className="games-carousel-overlay">
        <p className="games-carousel-kicker">THE GAMES YOU WANT TO PLAY · POWERED BY WINESHELF</p>
        <p className="games-carousel-note">
          Counter-Strike 2 · Dota 2 · Call of Duty · Cyberpunk 2077 · Elden Ring · and more
        </p>
      </div>
    </TiltedGridHero>
  );
}
