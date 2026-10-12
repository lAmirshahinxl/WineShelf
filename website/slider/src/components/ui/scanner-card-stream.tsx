"use client";

import {
  ArrowLeftRight,
  Pause,
  Play,
  RotateCcw,
} from "lucide-react";
import * as THREE from "three";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

const defaultCardImages = [
  "https://cdn.21st.dev/assets/mirror/cc/cccd26411c3961f0580866608ca10525bc100d36d60b00d439da67123860e5b3.png",
  "https://cdn.21st.dev/assets/mirror/39/3989b198f5af613fd45d5b37bb893cf76b8286fe0615a51343b16a3f9a44fe60.png",
  "https://cdn.21st.dev/assets/mirror/7a/7a27e9dafc45d10870073cb64440dabeb2e5972118fd9375958fb40afb088028.png",
  "https://cdn.21st.dev/assets/mirror/8b/8bd2f1455818bd7c15824695de33d5d77b28dec91589221409d61b25e3c36994.png",
  "https://cdn.21st.dev/assets/mirror/e4/e4cb1e5ee85993bc30b089641c817ce87f4f7fabfe204fd628a9cbc969d38f34.png",
];

const ASCII_CHARS =
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789(){}[]<>;:,._-+=!@#$%^&*|\\/\"'`~?";
const CARD_WIDTH = 400;
const CARD_HEIGHT = 250;

const generateCode = (width: number, height: number, seed?: number): string => {
  let randomState = seed ?? Math.floor(Math.random() * 0xffffffff);
  const random = () => {
    randomState = (randomState * 1664525 + 1013904223) >>> 0;
    return randomState / 0x100000000;
  };

  let output = "";
  for (let row = 0; row < height; row += 1) {
    for (let column = 0; column < width; column += 1) {
      output += ASCII_CHARS[Math.floor(random() * ASCII_CHARS.length)];
    }
    output += "\n";
  }
  return output;
};

type ScannerCardStreamProps = {
  showControls?: boolean;
  showSpeed?: boolean;
  initialSpeed?: number;
  direction?: -1 | 1;
  cardImages?: string[];
  repeat?: number;
  cardGap?: number;
  friction?: number;
  scanEffect?: "clip" | "scramble";
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

export function ScannerCardStream({
  showControls = false,
  showSpeed = false,
  initialSpeed = 150,
  direction = -1,
  cardImages = defaultCardImages,
  repeat = 6,
  cardGap = 60,
  friction = 0.95,
  scanEffect = "scramble",
}: ScannerCardStreamProps) {
  const [speed, setSpeed] = useState(initialSpeed);
  const [isPaused, setIsPaused] = useState(false);
  const [isScanning, setIsScanning] = useState(false);
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false);
  const viewportRef = useRef<HTMLDivElement>(null);
  const cardLineRef = useRef<HTMLDivElement>(null);
  const particleCanvasRef = useRef<HTMLCanvasElement>(null);
  const scannerCanvasRef = useRef<HTMLCanvasElement>(null);
  const originalAscii = useRef(new Map<number, string>());
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
    minVelocity: 30,
  });
  const scannerState = useRef({ isScanning: false });

  const cards = useMemo(() => {
    const safeRepeat = Math.max(0, Math.floor(repeat));
    const totalCards = cardImages.length * safeRepeat;
    return Array.from({ length: totalCards }, (_, index) => ({
      id: index,
      image: cardImages[index % cardImages.length],
      ascii: generateCode(
        Math.floor(CARD_WIDTH / 6.5),
        Math.floor(CARD_HEIGHT / 13),
        index + 1,
      ),
    }));
  }, [cardImages, repeat]);

  const toggleAnimation = useCallback(() => {
    setIsPaused((paused) => !paused);
  }, []);

  const resetPosition = useCallback(() => {
    const viewport = viewportRef.current;
    const cardLine = cardLineRef.current;
    if (!viewport || !cardLine) return;

    const state = cardStreamState.current;
    state.position = viewport.clientWidth;
    state.containerWidth = viewport.clientWidth;
    state.cardLineWidth = cardLine.scrollWidth;
    state.velocity = initialSpeed;
    state.direction = direction;
    state.isDragging = false;
    setSpeed(initialSpeed);
    setIsPaused(false);
  }, [initialSpeed, direction]);

  const changeDirection = useCallback(() => {
    cardStreamState.current.direction =
      cardStreamState.current.direction === 1 ? -1 : 1;
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

    cards.forEach((card) => originalAscii.current.set(card.id, card.ascii));
    const state = cardStreamState.current;
    state.containerWidth = viewport.clientWidth;
    state.position = viewport.clientWidth;
    state.velocity = initialSpeed;
    state.direction = direction;
    state.friction = friction;
    state.cardLineWidth = cardLine.scrollWidth || (CARD_WIDTH + cardGap) * cards.length;
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

    const scrambleIntervals = new Set<number>();
    const runScrambleEffect = (element: HTMLElement, cardId: number) => {
      if (element.dataset.scrambling === "true") return;
      element.dataset.scrambling = "true";
      const originalText = originalAscii.current.get(cardId) ?? "";
      let scrambleCount = 0;
      const interval = window.setInterval(() => {
        element.textContent = generateCode(
          Math.floor(CARD_WIDTH / 6.5),
          Math.floor(CARD_HEIGHT / 13),
        );
        scrambleCount += 1;
        if (scrambleCount >= 10) {
          window.clearInterval(interval);
          scrambleIntervals.delete(interval);
          element.textContent = originalText;
          delete element.dataset.scrambling;
        }
      }, 30);
      scrambleIntervals.add(interval);
    };

    const updateCardEffects = () => {
      const viewportRect = viewport.getBoundingClientRect();
      const scannerX = viewportRect.left + viewportRect.width / 2;
      const scannerWidth = 8;
      const scannerLeft = scannerX - scannerWidth / 2;
      const scannerRight = scannerX + scannerWidth / 2;
      let anyCardIsScanning = false;

      cardLine.querySelectorAll<HTMLElement>(".card-wrapper").forEach((wrapper, index) => {
        const rect = wrapper.getBoundingClientRect();
        const normalCard = wrapper.querySelector<HTMLElement>(".card-normal");
        const asciiCard = wrapper.querySelector<HTMLElement>(".card-ascii");
        const asciiContent = asciiCard?.querySelector<HTMLElement>("pre");
        if (!normalCard || !asciiCard || !asciiContent || rect.width === 0) return;

        if (rect.left < scannerRight && rect.right > scannerLeft) {
          anyCardIsScanning = true;
          if (scanEffect === "scramble" && wrapper.dataset.scanned !== "true") {
            runScrambleEffect(asciiContent, Number(wrapper.dataset.cardId ?? index));
          }
          wrapper.dataset.scanned = "true";
          const intersectLeft = Math.max(scannerLeft - rect.left, 0);
          const intersectRight = Math.min(scannerRight - rect.left, rect.width);
          normalCard.style.setProperty(
            "--clip-right",
            `${(intersectLeft / rect.width) * 100}%`,
          );
          asciiCard.style.setProperty(
            "--clip-left",
            `${(intersectRight / rect.width) * 100}%`,
          );
        } else {
          delete wrapper.dataset.scanned;
          if (rect.right < scannerLeft) {
            normalCard.style.setProperty("--clip-right", "100%");
            asciiCard.style.setProperty("--clip-left", "100%");
          } else {
            normalCard.style.setProperty("--clip-right", "0%");
            asciiCard.style.setProperty("--clip-left", "0%");
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
        state.direction = deltaX > 0 ? 1 : -1;
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
      state.direction = delta > 0 ? -1 : 1;
      state.velocity = Math.max(state.minVelocity, Math.min(Math.abs(delta) * 8, 600));
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
      event.preventDefault();
      const step = event.shiftKey ? CARD_WIDTH : 80;
      const movingRight = event.key === "ArrowLeft";
      state.position += movingRight ? step : -step;
      state.direction = movingRight ? 1 : -1;
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
      scrambleIntervals.forEach((interval) => window.clearInterval(interval));
      geometry.dispose();
      material.dispose();
      texture.dispose();
      renderer?.dispose();
    };
  }, [cards, cardGap, direction, friction, initialSpeed, scanEffect]);

  return (
    <div className="scanner-card-stream" data-paused={isPaused}>
      <div className="scanner-card-stream-toolbar">
        <div className="scanner-card-stream-legend" aria-hidden="true">
          <span>MACOS-COMPATIBLE OUTPUT</span>
          <span className="scanner-card-stream-legend-arrow">← WINE SCAN ←</span>
          <span>WINDOWS APP INPUT</span>
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
        aria-label="Windows to macOS card scanner"
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
            aria-label="Moving cards. Drag or use the left and right arrow keys to change their direction."
            style={{ gap: `${cardGap}px` }}
          >
            {cards.map((card) => (
              <div
                key={card.id}
                data-card-id={card.id}
                className="card-wrapper relative h-[250px] w-[400px] shrink-0"
              >
                <div className="card-normal card absolute left-0 top-0 z-[2] h-full w-full overflow-hidden rounded-[15px] bg-transparent shadow-[0_15px_40px_rgba(0,0,0,0.4)]">
                  <img
                    src={card.image}
                    alt=""
                    draggable={false}
                    className="h-full w-full rounded-[15px] object-cover brightness-110 contrast-110 transition-all duration-300 ease-in-out hover:brightness-125 hover:contrast-125"
                  />
                </div>
                <div className="card-ascii card absolute left-0 top-0 z-[1] h-full w-full overflow-hidden rounded-[15px] bg-transparent">
                  <pre className="ascii-content animate-glitch absolute left-0 top-0 m-0 box-border h-full w-full overflow-hidden whitespace-pre p-0 text-left align-top font-mono text-[11px] leading-[13px] text-[rgba(220,210,255,0.6)]">
                    {card.ascii}
                  </pre>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
