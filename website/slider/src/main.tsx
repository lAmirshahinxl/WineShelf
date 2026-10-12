import * as React from "react";
import { createRoot } from "react-dom/client";
import { GameSlider } from "./game-slider";
import "./index.css";

const mount = document.getElementById("game-slider-root");

if (mount) {
  createRoot(mount).render(
    <React.StrictMode>
      <GameSlider />
    </React.StrictMode>,
  );
}
