"use client";

import {
  ArrowLeftRight,
  Pause,
  Play,
  RotateCcw,
} from "lucide-react";
import * as THREE from "three";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

const CARD_WIDTH = 400;
const CARD_HEIGHT = 250;
const cpuModels = [
  { input: "CORE i9-14900K", output: "M4 MAX" },
  { input: "CORE i7-14700K", output: "M4 PRO" },
  { input: "CORE i5-14600K", output: "M4" },
  { input: "CORE ULTRA 9", output: "M3 ULTRA" },
  { input: "XEON W", output: "M3 MAX" },
];

type ScannerCardStreamProps = {
  showControls?: boolean;
  showSpeed?: boolean;
  initialSpeed?: number;
  direction?: -1 | 1;
  repeat?: number;
  cardGap?: number;
  friction?: number;
};

type CpuChipFaceProps = {
  platform: "intel" | "apple";
  model: string;
};

type CardStreamState = {
  position: number;
  velocity: number;
  direction: -1 | 1;
  isDragging: boolean;
  lastMouseX: number;
  lastPointerTime: number;
  lastPointerDelta: number;
  activePointerId: number | null;
  lastTime: number;
  cardLineWidth: number;
  containerWidth: number;
  friction: number;
  minVelocity: number;
};

type ScannerParticle = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  alpha: number;
  life: number;
  decay: number;
};

function CpuChipFace({ platform, model }: CpuChipFaceProps) {
  const isApple = platform === "apple";

  return (
    <div
      className={`cpu-chip-face ${isApple ? "cpu-chip-face-apple" : "cpu-chip-face-intel"}`}
      aria-hidden="true"
    >
      <div className="cpu-chip-grid" />
      <div className="cpu-chip-topline">
        <span>{isApple ? "APPLE SILICON" : "WINDOWS · X86_64"}</span>
        <span className="cpu-chip-state">{isApple ? "ARM64" : "INTEL"}</span>
      </div>
      <div className={`cpu-package cpu-package-${platform}`}>
        <div className="cpu-package-surface">
          <span className={`cpu-package-maker cpu-package-maker-${platform}`}>
            {isApple ? "Apple" : "intel"}
          </span>
          <span className="cpu-package-model">{model}</span>
          <span className="cpu-package-type">
            {isApple ? "APPLE SILICON" : "CORE PROCESSOR"}
          </span>
        </div>
      </div>
      <div className="cpu-chip-bottomline">
        <span>{isApple ? "MACOS · APPLE SILICON" : "WINDOWS · INTEL PC"}</span>
        <span>{isApple ? "WINESHELF OUTPUT" : "WINESHELF INPUT"}</span>
      </div>
    </div>
  );
}

export function ScannerCardStream({
  showControls = false,
  showSpeed = false,
  initialSpeed = 300,
  direction = 1,
  repeat = 6,
  cardGap = 60,
  friction = 0.992,
}: ScannerCardStreamProps) {
  const [speed, setSpeed] = useState(initialSpeed);
  const [isPaused, setIsPaused] = useState(false);
  const [isScanning, setIsScanning] = useState(false);
  const [streamDirection, setStreamDirection] = useState(direction);
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false);
  const viewportRef = useRef<HTMLDivElement>(null);
  const cardLineRef = useRef<HTMLDivElement>(null);
  const particleCanvasRef = useRef<HTMLCanvasElement>(null);
  const scannerCanvasRef = useRef<HTMLCanvasElement>(null);
  const isPausedRef = useRef(isPaused);
  const reducedMotionRef = useRef(false);
  const animationControlRef = useRef<((isRunning: boolean) => void) | null>(null);
  const cardStreamState = useRef<CardStreamState>({
    position: 0,
    velocity: initialSpeed,
    direction,
    isDragging: false,
    lastMouseX: 0,
    lastPointerTime: 0,
    lastPointerDelta: 0,
    activePointerId: null,
    lastTime: 0,
    cardLineWidth: 0,
    containerWidth: 0,
    friction,
    minVelocity: 85,
  });
  const scannerState = useRef({ isScanning: false });

  const cards = useMemo(() => {
    const safeRepeat = Math.max(0, Math.floor(repeat));
    const totalCards = cpuModels.length * safeRepeat;
    return Array.from({ length: totalCards }, (_, index) => ({
      id: index,
      input: cpuModels[index % cpuModels.length].input,
      output: cpuModels[index % cpuModels.length].output,
    }));
  }, [repeat]);

  const toggleAnimation = useCallback(() => {
    setIsPaused((paused) => !paused);
  }, []);

  const resetPosition = useCallback(() => {
    const viewport = viewportRef.current;
    const cardLine = cardLineRef.current;
    if (!viewport || !cardLine) return;

    const state = cardStreamState.current;
    state.containerWidth = viewport.clientWidth;
    state.cardLineWidth = cardLine.scrollWidth;
    state.position = direction === -1 ? viewport.clientWidth : -state.cardLineWidth;
    state.velocity = initialSpeed;
    state.direction = direction;
    state.isDragging = false;
    setSpeed(initialSpeed);
    setIsPaused(false);
    setStreamDirection(direction);
  }, [initialSpeed, direction]);

  const changeDirection = useCallback(() => {
    const nextDirection = cardStreamState.current.direction === 1 ? -1 : 1;
    cardStreamState.current.direction = nextDirection;
    setStreamDirection(nextDirection);
  }, []);

  useEffect(() => {
    isPausedRef.current = isPaused;
    animationControlRef.current?.(!isPaused && !reducedMotionRef.current);
  }, [isPaused]);

  useEffect(() => {
    const viewport = viewportRef.current;
    const cardLine = cardLineRef.current;
    const particleCanvas = particleCanvasRef.current;
    const scannerCanvas = scannerCanvasRef.current;
    if (!viewport || !cardLine || !particleCanvas || !scannerCanvas) return;

    const state = cardStreamState.current;
    state.containerWidth = viewport.clientWidth;
    state.velocity = initialSpeed;
    state.direction = direction;
    state.friction = friction;
    state.cardLineWidth = cardLine.scrollWidth || (CARD_WIDTH + cardGap) * cards.length;
    state.position = direction === -1 ? viewport.clientWidth : -state.cardLineWidth;
    state.lastTime = performance.now();

    let renderer: THREE.WebGLRenderer | null = null;
    try {
      renderer = new THREE.WebGLRenderer({
        canvas: particleCanvas,
        alpha: true,
        antialias: true,
        powerPreference: "low-power",
      });
    } catch {
      // The card scanner still works without the decorative WebGL particles.
    }

    const scene = new THREE.Scene();
    const camera = new THREE.OrthographicCamera(
      -viewport.clientWidth / 2,
      viewport.clientWidth / 2,
      125,
      -125,
      1,
      1000,
    );
    camera.position.z = 100;
    renderer?.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
    renderer?.setSize(viewport.clientWidth, CARD_HEIGHT);
    renderer?.setClearColor(0x000000, 0);

    const particleCount = 400;
    const geometry = new THREE.BufferGeometry();
    const positions = new Float32Array(particleCount * 3);
    const velocities = new Float32Array(particleCount);
    const alphas = new Float32Array(particleCount);
    const textureCanvas = document.createElement("canvas");
    textureCanvas.width = 100;
    textureCanvas.height = 100;
    const textureContext = textureCanvas.getContext("2d");
    if (textureContext) {
      const half = 50;
      const gradient = textureContext.createRadialGradient(
        half,
        half,
        0,
        half,
        half,
        half,
      );
      gradient.addColorStop(0.025, "#fff");
      gradient.addColorStop(0.1, "hsl(217, 61%, 33%)");
      gradient.addColorStop(0.25, "hsl(217, 64%, 6%)");
      gradient.addColorStop(1, "transparent");
      textureContext.fillStyle = gradient;
      textureContext.arc(half, half, half, 0, Math.PI * 2);
      textureContext.fill();
    }
    const texture = new THREE.CanvasTexture(textureCanvas);

    for (let index = 0; index < particleCount; index += 1) {
      positions[index * 3] = (Math.random() - 0.5) * viewport.clientWidth * 2;
      positions[index * 3 + 1] = (Math.random() - 0.5) * CARD_HEIGHT;
      velocities[index] = Math.random() * 60 + 30;
      alphas[index] = (Math.random() * 8 + 2) / 10;
    }

    geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));
    geometry.setAttribute("alpha", new THREE.BufferAttribute(alphas, 1));
    const material = new THREE.ShaderMaterial({
      uniforms: { pointTexture: { value: texture } },
      vertexShader:
        "attribute float alpha; varying float vAlpha; void main() { vAlpha = alpha; vec4 mvPosition = modelViewMatrix * vec4(position, 1.0); gl_PointSize = 15.0; gl_Position = projectionMatrix * mvPosition; }",
      fragmentShader:
        "uniform sampler2D pointTexture; varying float vAlpha; void main() { gl_FragColor = vec4(1.0, 1.0, 1.0, vAlpha) * texture2D(pointTexture, gl_PointCoord); }",
      transparent: true,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
      vertexColors: false,
    });
    scene.add(new THREE.Points(geometry, material));

    const scannerContext = scannerCanvas.getContext("2d");
    let canvasWidth = Math.max(viewport.clientWidth, 1);
    scannerCanvas.width = canvasWidth;
    scannerCanvas.height = 300;
    let scannerParticles: ScannerParticle[] = [];
    const baseMaxParticles = 800;
    let currentMaxParticles = baseMaxParticles;
    const scanTargetMaxParticles = 2500;
    const createScannerParticle = (): ScannerParticle => ({
      x: canvasWidth / 2 + (Math.random() - 0.5) * 3,
      y: Math.random() * 300,
      vx: Math.random() * 0.8 + 0.2,
      vy: (Math.random() - 0.5) * 0.3,
      radius: Math.random() * 0.6 + 0.4,
      alpha: Math.random() * 0.4 + 0.6,
      life: 1,
      decay: Math.random() * 0.02 + 0.005,
    });
    for (let index = 0; index < baseMaxParticles; index += 1) {
      scannerParticles.push(createScannerParticle());
    }

    const updateCardEffects = () => {
      const viewportRect = viewport.getBoundingClientRect();
      const scannerX = viewportRect.left + viewportRect.width / 2;
      const scannerWidth = 8;
      const scannerLeft = scannerX - scannerWidth / 2;
      const scannerRight = scannerX + scannerWidth / 2;
      let anyCardIsScanning = false;

      cardLine.querySelectorAll<HTMLElement>(".card-wrapper").forEach((wrapper) => {
        const rect = wrapper.getBoundingClientRect();
        const inputChip = wrapper.querySelector<HTMLElement>(".cpu-card-input");
        const outputChip = wrapper.querySelector<HTMLElement>(".cpu-card-output");
        if (!inputChip || !outputChip || rect.width === 0) return;

        if (rect.left < scannerRight && rect.right > scannerLeft) {
          anyCardIsScanning = true;
          wrapper.dataset.scanned = "true";
          const intersectLeft = Math.max(scannerLeft - rect.left, 0);
          const intersectRight = Math.min(scannerRight - rect.left, rect.width);
          const leftPercent = (intersectLeft / rect.width) * 100;
          const rightPercent = (intersectRight / rect.width) * 100;

          if (state.direction === -1) {
            inputChip.style.clipPath = `inset(0 0 0 ${leftPercent}%)`;
            outputChip.style.clipPath = `inset(0 ${100 - rightPercent}% 0 0)`;
          } else {
            inputChip.style.clipPath = `inset(0 ${100 - leftPercent}% 0 0)`;
            outputChip.style.clipPath = `inset(0 0 0 ${rightPercent}%)`;
          }
        } else {
          delete wrapper.dataset.scanned;
          const hasPassedScanner = state.direction === -1
            ? rect.right < scannerLeft
            : rect.left > scannerRight;
          if (hasPassedScanner) {
            inputChip.style.clipPath = "inset(0 100% 0 0)";
            outputChip.style.clipPath = "inset(0 0 0 0)";
          } else {
            inputChip.style.clipPath = "inset(0 0 0 0)";
            outputChip.style.clipPath = "inset(0 100% 0 0)";
          }
        }
      });

      if (scannerState.current.isScanning !== anyCardIsScanning) {
        scannerState.current.isScanning = anyCardIsScanning;
        setIsScanning(anyCardIsScanning);
      }
    };

    const handlePointerDown = (event: PointerEvent) => {
      if (event.button !== 0 || !event.isPrimary) return;
      state.isDragging = true;
      state.activePointerId = event.pointerId;
      state.lastMouseX = event.clientX;
      state.lastPointerTime = performance.now();
      state.lastPointerDelta = 0;
      cardLine.classList.add("is-dragging");
      cardLine.setPointerCapture(event.pointerId);
    };

    const handlePointerMove = (event: PointerEvent) => {
      if (!state.isDragging || state.activePointerId !== event.pointerId) return;
      const deltaX = event.clientX - state.lastMouseX;
      const now = performance.now();
      const deltaTime = Math.max((now - state.lastPointerTime) / 1000, 0.001);
      state.position += deltaX;
      state.lastPointerDelta = deltaX;
      state.lastMouseX = event.clientX;
      state.lastPointerTime = now;
      if (deltaX !== 0) {
        const nextDirection = deltaX > 0 ? 1 : -1;
        if (state.direction !== nextDirection) {
          state.direction = nextDirection;
          setStreamDirection(nextDirection);
        }
        state.velocity = Math.max(
          state.minVelocity,
          Math.min(Math.abs(deltaX / deltaTime), 600),
        );
        cardLine.style.transform = `translate3d(${state.position}px, 0, 0)`;
      }
    };

    const handlePointerUp = (event: PointerEvent) => {
      if (state.activePointerId !== event.pointerId) return;
      state.isDragging = false;
      state.activePointerId = null;
      cardLine.classList.remove("is-dragging");
      if (cardLine.hasPointerCapture(event.pointerId)) {
        cardLine.releasePointerCapture(event.pointerId);
      }
      if (state.lastPointerDelta !== 0) {
        state.direction = state.lastPointerDelta > 0 ? 1 : -1;
      }
    };

    const handleWheel = (event: WheelEvent) => {
      const delta = event.shiftKey ? event.deltaY : event.deltaX;
      if (delta === 0) return;
      event.preventDefault();
      state.position -= delta;
      const nextDirection = delta > 0 ? -1 : 1;
      if (state.direction !== nextDirection) {
        state.direction = nextDirection;
        setStreamDirection(nextDirection);
      }
      state.velocity = Math.max(state.minVelocity, Math.min(Math.abs(delta) * 8, 600));
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
      event.preventDefault();
      const step = event.shiftKey ? CARD_WIDTH : 80;
      const movingRight = event.key === "ArrowLeft";
      state.position += movingRight ? step : -step;
      const nextDirection = movingRight ? 1 : -1;
      if (state.direction !== nextDirection) {
        state.direction = nextDirection;
        setStreamDirection(nextDirection);
      }
      state.velocity = Math.max(state.velocity, state.minVelocity);
    };

    cardLine.addEventListener("pointerdown", handlePointerDown);
    cardLine.addEventListener("keydown", handleKeyDown);
    window.addEventListener("pointermove", handlePointerMove);
    window.addEventListener("pointerup", handlePointerUp);
    window.addEventListener("pointercancel", handlePointerUp);
    viewport.addEventListener("wheel", handleWheel, { passive: false });

    let animationFrameId = 0;
    let lastSpeedUpdate = 0;
    const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    reducedMotionRef.current = motionQuery.matches;
    setPrefersReducedMotion(motionQuery.matches);

    const animate = (currentTime: number) => {
      const deltaTime = Math.min(
        Math.max((currentTime - state.lastTime) / 1000, 0),
        0.05,
      );
      state.lastTime = currentTime;

      if (!isPausedRef.current && !state.isDragging) {
        if (state.velocity > state.minVelocity) {
          state.velocity = Math.max(
            state.minVelocity,
            state.velocity * state.friction,
          );
        }
        state.position += state.velocity * state.direction * deltaTime;
        if (currentTime - lastSpeedUpdate > 120) {
          setSpeed(Math.round(state.velocity));
          lastSpeedUpdate = currentTime;
        }
      }

      const containerWidth = viewport.clientWidth;
      const cardLineWidth = cardLine.scrollWidth || state.cardLineWidth;
      state.containerWidth = containerWidth;
      state.cardLineWidth = cardLineWidth;
      if (state.position < -cardLineWidth) state.position = containerWidth;
      else if (state.position > containerWidth) state.position = -cardLineWidth;
      cardLine.style.transform = `translate3d(${state.position}px, 0, 0)`;
      updateCardEffects();

      const time = currentTime * 0.001;
      for (let index = 0; index < particleCount; index += 1) {
        const xOffset = index * 3;
        positions[xOffset] += velocities[index] * deltaTime;
        if (positions[xOffset] > containerWidth / 2 + 100) {
          positions[xOffset] = -containerWidth / 2 - 100;
        }
        positions[xOffset + 1] += Math.sin(time + index * 0.1) * 0.5;
        alphas[index] = Math.max(
          0.1,
          Math.min(1, alphas[index] + (Math.random() - 0.5) * 0.05),
        );
      }
      geometry.attributes.position.needsUpdate = true;
      geometry.attributes.alpha.needsUpdate = true;
      renderer?.render(scene, camera);

      if (scannerContext) {
        scannerContext.clearRect(0, 0, canvasWidth, 300);
        const targetCount = scannerState.current.isScanning
          ? scanTargetMaxParticles
          : baseMaxParticles;
        currentMaxParticles += (targetCount - currentMaxParticles) * 0.05;
        while (scannerParticles.length < currentMaxParticles) {
          scannerParticles.push(createScannerParticle());
        }
        while (scannerParticles.length > currentMaxParticles) scannerParticles.pop();
        scannerParticles.forEach((particle) => {
          particle.x += particle.vx;
          particle.y += particle.vy;
          particle.life -= particle.decay;
          if (particle.life <= 0 || particle.x > canvasWidth) {
            Object.assign(particle, createScannerParticle());
          }
          scannerContext.globalAlpha = particle.alpha * particle.life;
          scannerContext.fillStyle = "white";
          scannerContext.beginPath();
          scannerContext.arc(particle.x, particle.y, particle.radius, 0, Math.PI * 2);
          scannerContext.fill();
        });
        scannerContext.globalAlpha = 1;
      }

      animationFrameId =
        reducedMotionRef.current || isPausedRef.current
          ? 0
          : window.requestAnimationFrame(animate);
    };

    const stopAnimation = () => {
      window.cancelAnimationFrame(animationFrameId);
      animationFrameId = 0;
      renderer?.render(scene, camera);
    };

    const startAnimation = () => {
      if (animationFrameId || reducedMotionRef.current || isPausedRef.current) return;
      state.lastTime = performance.now();
      animationFrameId = window.requestAnimationFrame(animate);
    };

    cardLine.style.transform = `translate3d(${state.position}px, 0, 0)`;
    updateCardEffects();
    renderer?.render(scene, camera);

    animationControlRef.current = (isRunning) => {
      if (isRunning) startAnimation();
      else stopAnimation();
    };

    const handleMotionChange = () => {
      reducedMotionRef.current = motionQuery.matches;
      setPrefersReducedMotion(motionQuery.matches);
      if (motionQuery.matches) {
        stopAnimation();
      } else startAnimation();
    };

    motionQuery.addEventListener("change", handleMotionChange);
    startAnimation();

    const resize = () => {
      const width = Math.max(viewport.clientWidth, 1);
      state.containerWidth = width;
      canvasWidth = width;
      scannerCanvas.width = width;
      scannerCanvas.height = 300;
      camera.left = -width / 2;
      camera.right = width / 2;
      camera.updateProjectionMatrix();
      renderer?.setSize(width, CARD_HEIGHT);
      if (reducedMotionRef.current) renderer?.render(scene, camera);
    };
    window.addEventListener("resize", resize);

    return () => {
      window.cancelAnimationFrame(animationFrameId);
      cardLine.removeEventListener("pointerdown", handlePointerDown);
      cardLine.removeEventListener("keydown", handleKeyDown);
      window.removeEventListener("pointermove", handlePointerMove);
      window.removeEventListener("pointerup", handlePointerUp);
      window.removeEventListener("pointercancel", handlePointerUp);
      viewport.removeEventListener("wheel", handleWheel);
      window.removeEventListener("resize", resize);
      motionQuery.removeEventListener("change", handleMotionChange);
      animationControlRef.current = null;
      geometry.dispose();
      material.dispose();
      texture.dispose();
      renderer?.dispose();
    };
  }, [cards, cardGap, direction, friction, initialSpeed]);

  return (
    <div className="scanner-card-stream" data-paused={isPaused}>
      <div className="scanner-card-stream-toolbar">
        <div className="scanner-card-stream-legend" aria-hidden="true">
          <span>{streamDirection === 1 ? "WINDOWS · INTEL X86" : "APPLE SILICON · MACOS"}</span>
          <span className="scanner-card-stream-legend-arrow">
            {streamDirection === 1 ? "→ WINESHELF →" : "← WINESHELF ←"}
          </span>
          <span>{streamDirection === 1 ? "APPLE SILICON · MACOS" : "WINDOWS · INTEL X86"}</span>
        </div>
        <div className="scanner-card-stream-actions">
          {showSpeed && (
            <span className="scanner-card-stream-speed" aria-live="off">
              {speed} PX/S
            </span>
          )}
          {showControls && !prefersReducedMotion && (
            <>
              <button
                type="button"
                className="scanner-card-stream-button"
                onClick={toggleAnimation}
                aria-label={isPaused ? "Resume card stream" : "Pause card stream"}
                aria-pressed={isPaused}
              >
                {isPaused ? <Play aria-hidden="true" /> : <Pause aria-hidden="true" />}
              </button>
              <button
                type="button"
                className="scanner-card-stream-button"
                onClick={resetPosition}
                aria-label="Reset card stream"
              >
                <RotateCcw aria-hidden="true" />
              </button>
              <button
                type="button"
                className="scanner-card-stream-button"
                onClick={changeDirection}
                aria-label="Reverse card stream direction"
              >
                <ArrowLeftRight aria-hidden="true" />
              </button>
            </>
          )}
          {showControls && prefersReducedMotion && (
            <span className="scanner-card-stream-motion-note">
              MOTION REDUCED
            </span>
          )}
        </div>
      </div>

      <div
        ref={viewportRef}
        className="scanner-card-stream-viewport relative h-[360px] w-full overflow-hidden"
        role="region"
        aria-label="Windows Intel processors transforming into Apple silicon with WineShelf"
      >
        <canvas
          ref={particleCanvasRef}
          className="scanner-card-stream-particles pointer-events-none absolute left-0 top-1/2 z-0 h-[250px] w-full -translate-y-1/2"
          aria-hidden="true"
        />
        <canvas
          ref={scannerCanvasRef}
          className="scanner-card-stream-scanner-particles pointer-events-none absolute left-0 top-1/2 z-10 h-[300px] w-full -translate-y-1/2"
          aria-hidden="true"
        />

        <div
          className={`scanner-card-stream-beam pointer-events-none absolute left-1/2 top-1/2 z-20 h-[280px] w-0.5 rounded-full transition-opacity duration-300 ${
            isScanning ? "opacity-100" : "opacity-0"
          }`}
          aria-hidden="true"
        />

        <div className="absolute left-0 top-1/2 z-[5] flex h-[250px] w-full -translate-y-1/2 items-center">
          <div
            ref={cardLineRef}
            className="scanner-card-line flex cursor-grab select-none items-center whitespace-nowrap will-change-transform"
            role="group"
            tabIndex={0}
            aria-label="Moving processor chips. Drag or use the left and right arrow keys to change their direction."
            style={{ gap: `${cardGap}px` }}
          >
            {cards.map((card) => (
              <div
                key={card.id}
                className="card-wrapper relative h-[250px] w-[400px] shrink-0"
              >
                <div className="cpu-card-input absolute left-0 top-0 z-[2] h-full w-full overflow-hidden rounded-[15px] shadow-[0_15px_40px_rgba(0,0,0,0.4)]">
                  <CpuChipFace platform="intel" model={card.input} />
                </div>
                <div className="cpu-card-output absolute left-0 top-0 z-[1] h-full w-full overflow-hidden rounded-[15px]">
                  <CpuChipFace platform="apple" model={card.output} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
