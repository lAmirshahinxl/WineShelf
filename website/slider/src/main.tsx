import * as React from "react";
import { createRoot } from "react-dom/client";
import BlockFeature from "@/components/ui/block-feature";
import { GameSlider } from "./game-slider";
import "./index.css";

const gameSliderMount = document.getElementById("game-slider-root");
const featureMount = document.getElementById("feature-block-root");

if (gameSliderMount) {
  createRoot(gameSliderMount).render(
    <React.StrictMode>
      <GameSlider />
    </React.StrictMode>,
  );
}

if (featureMount) {
  createRoot(featureMount).render(
    <React.StrictMode>
      <BlockFeature />
    </React.StrictMode>,
  );
}
