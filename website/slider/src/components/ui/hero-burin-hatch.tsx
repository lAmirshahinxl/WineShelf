"use client";

import { useEffect, useRef } from "react";

const DEG = Math.PI / 180;
const RADIUS_FRAC = 0.38;
const MERIDIANS = 80;
const MERIDIAN_STEP = 4.5 * DEG;
const LAT_MIN = -88 * DEG;
const LAT_STEP = 1.5 * DEG;
const LAT_N = 118;
const WIDTH_A = 3;
const SHADE_POW = 3;
const PARALLELS = 25;
const PARALLEL_STEP = 6 * DEG;
const PARALLEL_MIN = -72 * DEG;
const LON_N = 240;
const LON_STEP = 1.5 * DEG;
const CROSS_THRESHOLD = 0.2;
const WIDTH_B = 1.8;
const ALPHA_A = 0.9;
const ALPHA_B = 0.75;
const ALPHA_SILHOUETTE = 0.35;
const SILHOUETTE_W = 1.1;
const SPIN = 0.06;
const AZ_PERIOD = 26;
const EL_PERIOD = 19;
const LIGHT_TAU = 0.45;
const POINTER_Z = 0.62;
const DT_MAX = 1 / 30;
const BUF = 260;

const globeGames = [
  { title: "Cyberpunk 2077", image: "cyberpunk-2077.jpg" },
  { title: "Elden Ring", image: "elden-ring.jpg" },
  { title: "Baldur’s Gate 3", image: "baldurs-gate-3.jpg" },
  { title: "The Witcher 3", image: "the-witcher-3.jpg" },
  { title: "Red Dead Redemption 2", image: "red-dead-redemption-2.jpg" },
  { title: "Grand Theft Auto V", image: "grand-theft-auto-v.jpg" },
  { title: "Apex Legends", image: "apex-legends.jpg" },
  { title: "Counter-Strike 2", image: "counter-strike-2.jpg" },
  { title: "Dota 2", image: "dota-2.jpg" },
];

const globeBands = [
  { latitude: 80, columns: 3 },
  { latitude: 60, columns: 9 },
  { latitude: 40, columns: 13 },
  { latitude: 20, columns: 16 },
  { latitude: 0, columns: 18 },
  { latitude: -20, columns: 16 },
  { latitude: -40, columns: 13 },
  { latitude: -60, columns: 9 },
  { latitude: -80, columns: 3 },
];

export interface BurinHatchCta {
  label: string;
  href?: string;
  onClick?: () => void;
}

export interface BurinHatchProps {
  eyebrow?: string;
  headline?: string | string[];
  subcopy?: string;
  primaryCta: BurinHatchCta;
  secondaryCta?: BurinHatchCta;
  plateLabel?: string;
  className?: string;
}

export function BurinHatch({
  eyebrow,
  headline = "Cut the light in",
  subcopy,
  primaryCta,
  secondaryCta,
  plateLabel = "An engraved sphere: hatch lines deepen in shadow and thin to bare paper in the light.",
  className = "",
}: BurinHatchProps) {
  const rootRef = useRef<HTMLElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const mosaicCanvasRef = useRef<HTMLCanvasElement>(null);
  const headlineLines = Array.isArray(headline) ? headline : [headline];

  useEffect(() => {
    const root = rootRef.current;
    const canvas = canvasRef.current;
    if (!root || !canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    let ink = "currentColor";
    let cssW = 0;
    let cssH = 0;
    let sized = false;

    const latCos = new Float64Array(LAT_N);
    const latSin = new Float64Array(LAT_N);
    for (let k = 0; k < LAT_N; k++) {
      const phi = LAT_MIN + k * LAT_STEP;
      latCos[k] = Math.cos(phi);
      latSin[k] = Math.sin(phi);
    }
    const meridCos = new Float64Array(MERIDIANS);
    const meridSin = new Float64Array(MERIDIANS);
    for (let m = 0; m < MERIDIANS; m++) {
      const lam = m * MERIDIAN_STEP;
      meridCos[m] = Math.cos(lam);
      meridSin[m] = Math.sin(lam);
    }
    const parCos = new Float64Array(PARALLELS);
    const parSin = new Float64Array(PARALLELS);
    for (let p = 0; p < PARALLELS; p++) {
      const phi = PARALLEL_MIN + p * PARALLEL_STEP;
      parCos[p] = Math.cos(phi);
      parSin[p] = Math.sin(phi);
    }
    const lonCos = new Float64Array(LON_N);
    const lonSin = new Float64Array(LON_N);
    for (let j = 0; j < LON_N; j++) {
      const lam = j * LON_STEP;
      lonCos[j] = Math.cos(lam);
      lonSin[j] = Math.sin(lam);
    }

    const xs = new Float64Array(BUF);
    const ys = new Float64Array(BUF);
    const ws = new Float64Array(BUF);
    const nxs = new Float64Array(BUF);
    const nys = new Float64Array(BUF);

    const emitRun = (path: Path2D, n: number) => {
      if (n < 2) return;
      for (let i = 0; i < n; i++) {
        const a = i > 0 ? i - 1 : i;
        const b = i < n - 1 ? i + 1 : i;
        const tx = xs[b]! - xs[a]!;
        const ty = ys[b]! - ys[a]!;
        const len = Math.hypot(tx, ty) || 1;
        const nx = -ty / len;
        const ny = tx / len;
        nxs[i] = nx;
        nys[i] = ny;
        const halfWidth = ws[i]! * 0.5;
        const px = xs[i]! + nx * halfWidth;
        const py = ys[i]! + ny * halfWidth;
        if (i === 0) path.moveTo(px, py);
        else path.lineTo(px, py);
      }
      for (let i = n - 1; i >= 0; i--) {
        const halfWidth = ws[i]! * 0.5;
        path.lineTo(xs[i]! - nxs[i]! * halfWidth, ys[i]! - nys[i]! * halfWidth);
      }
      path.closePath();
    };

    const readTokens = () => {
      ink = getComputedStyle(canvas).color;
    };
    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      if (rect.width < 4 || rect.height < 4) {
        sized = false;
        return;
      }
      cssW = rect.width;
      cssH = rect.height;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = Math.max(1, Math.round(cssW * dpr));
      canvas.height = Math.max(1, Math.round(cssH * dpr));
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      sized = true;
    };

    let lam0 = 0;
    let lx = 0;
    let ly = 0;
    let lz = 1;
    const ambient = (t: number, out: Float64Array) => {
      const az = 0.9 + 0.35 * Math.sin((2 * Math.PI * t) / AZ_PERIOD);
      const el = 0.5 + 0.18 * Math.sin((2 * Math.PI * t) / EL_PERIOD + 1.1);
      const ce = Math.cos(el);
      out[0] = ce * Math.sin(az);
      out[1] = Math.sin(el);
      out[2] = ce * Math.cos(az);
    };
    const target = new Float64Array(3);

    const draw = () => {
      if (!sized) return;
      ctx.clearRect(0, 0, cssW, cssH);
      const cx = cssW / 2;
      const cy = cssH / 2;
      const Rs = RADIUS_FRAC * Math.min(cssW, cssH);
      const c0 = Math.cos(lam0);
      const s0 = Math.sin(lam0);
      const pathA = new Path2D();
      const pathB = new Path2D();

      for (let m = 0; m < MERIDIANS; m++) {
        const sL = meridSin[m]! * c0 + meridCos[m]! * s0;
        const cL = meridCos[m]! * c0 - meridSin[m]! * s0;
        let n = 0;
        for (let k = 0; k < LAT_N; k++) {
          const cp = latCos[k]!;
          const nz = cp * cL;
          if (nz <= 0) {
            if (n > 1) emitRun(pathA, n);
            n = 0;
            continue;
          }
          const nx = cp * sL;
          const ny = latSin[k]!;
          const d = nx * lx + ny * ly + nz * lz;
          const u = d < 0 ? 1 : d > 1 ? 0 : 1 - d;
          xs[n] = cx + Rs * nx;
          ys[n] = cy - Rs * ny;
          ws[n] = Math.min(WIDTH_A, WIDTH_A * Math.pow(u, SHADE_POW));
          n++;
        }
        if (n > 1) emitRun(pathA, n);
      }

      const j0 = (((Math.round((Math.PI - lam0) / LON_STEP) % LON_N) + LON_N) % LON_N) | 0;
      for (let p = 0; p < PARALLELS; p++) {
        const cp = parCos[p]!;
        const sp = parSin[p]!;
        let n = 0;
        for (let q = 0; q < LON_N; q++) {
          const j = (j0 + q) % LON_N;
          const sL = lonSin[j]! * c0 + lonCos[j]! * s0;
          const cL = lonCos[j]! * c0 - lonSin[j]! * s0;
          const nz = cp * cL;
          const nx = cp * sL;
          const ny = sp;
          const d = nz > 0 ? nx * lx + ny * ly + nz * lz : 1;
          if (nz <= 0 || d >= CROSS_THRESHOLD) {
            if (n > 1) emitRun(pathB, n);
            n = 0;
            continue;
          }
          xs[n] = cx + Rs * nx;
          ys[n] = cy - Rs * ny;
          ws[n] = WIDTH_B * Math.min(1, (CROSS_THRESHOLD - d) / CROSS_THRESHOLD);
          n++;
        }
        if (n > 1) emitRun(pathB, n);
      }

      ctx.fillStyle = ink;
      ctx.globalAlpha = ALPHA_A;
      ctx.fill(pathA);
      ctx.globalAlpha = ALPHA_B;
      ctx.fill(pathB);
      ctx.globalAlpha = ALPHA_SILHOUETTE;
      ctx.strokeStyle = ink;
      ctx.lineWidth = SILHOUETTE_W;
      ctx.beginPath();
      ctx.arc(cx, cy, Rs, 0, Math.PI * 2);
      ctx.stroke();
      ctx.globalAlpha = 1;
    };

    if (reduced) {
      const still = () => {
        ambient(0, target);
        lx = target[0]!;
        ly = target[1]!;
        lz = target[2]!;
        lam0 = 0;
        draw();
      };
      readTokens();
      resize();
      still();
      const ro = new ResizeObserver(() => {
        resize();
        still();
      });
      ro.observe(canvas);
      const mo = new MutationObserver(() => {
        readTokens();
        still();
      });
      mo.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] });
      return () => {
        ro.disconnect();
        mo.disconnect();
      };
    }

    let raf = 0;
    let last = 0;
    let t = 0;
    let hasPointer = false;
    let pxN = 0;
    let pyN = 0;
    ambient(0, target);
    lx = target[0]!;
    ly = target[1]!;
    lz = target[2]!;

    const loop = (now: number) => {
      const dt = last ? Math.min(DT_MAX, (now - last) / 1000) : 1 / 60;
      last = now;
      t += dt;
      lam0 += SPIN * dt;
      if (lam0 > Math.PI * 2) lam0 -= Math.PI * 2;
      if (hasPointer) {
        const m = Math.hypot(pxN, pyN, POINTER_Z) || 1;
        target[0] = pxN / m;
        target[1] = pyN / m;
        target[2] = POINTER_Z / m;
      } else {
        ambient(t, target);
      }
      const k = Math.min(1, dt / LIGHT_TAU);
      lx += (target[0]! - lx) * k;
      ly += (target[1]! - ly) * k;
      lz += (target[2]! - lz) * k;
      const len = Math.hypot(lx, ly, lz) || 1;
      lx /= len;
      ly /= len;
      lz /= len;
      draw();
      if (document.hidden) raf = 0;
      else raf = requestAnimationFrame(loop);
    };
    const onPointerMove = (e: PointerEvent) => {
      if (e.pointerType === "touch" || !sized) return;
      const rect = canvas.getBoundingClientRect();
      const Rs = RADIUS_FRAC * Math.min(rect.width, rect.height);
      if (Rs < 1) return;
      pxN = (e.clientX - rect.left - rect.width / 2) / Rs;
      pyN = -(e.clientY - rect.top - rect.height / 2) / Rs;
      hasPointer = true;
    };
    const onPointerLeave = () => {
      hasPointer = false;
    };
    const onVis = () => {
      if (!document.hidden && !raf) {
        last = 0;
        raf = requestAnimationFrame(loop);
      }
    };

    readTokens();
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);
    const mo = new MutationObserver(readTokens);
    mo.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] });
    root.addEventListener("pointermove", onPointerMove);
    root.addEventListener("pointerleave", onPointerLeave);
    document.addEventListener("visibilitychange", onVis);
    raf = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(raf);
      raf = 0;
      ro.disconnect();
      mo.disconnect();
      root.removeEventListener("pointermove", onPointerMove);
      root.removeEventListener("pointerleave", onPointerLeave);
      document.removeEventListener("visibilitychange", onVis);
    };
  }, []);

  useEffect(() => {
    const canvas = mosaicCanvasRef.current;
    if (!canvas) return;

    const gl = canvas.getContext("webgl", { alpha: true, antialias: true, powerPreference: "low-power" });
    if (!gl) return;

    let disposed = false;
    let raf = 0;
    let startTime = 0;
    let pixelWidth = 0;
    let pixelHeight = 0;
    let atlasReady = false;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    const vertexSource = `
      attribute vec2 a_position;
      void main() {
        gl_Position = vec4(a_position, 0.0, 1.0);
      }
    `;
    const fragmentSource = `
      precision highp float;
      uniform vec2 u_resolution;
      uniform float u_rotation;
      uniform sampler2D u_atlas;

      void main() {
        vec2 point = (gl_FragCoord.xy - u_resolution * 0.5) / (0.5 * min(u_resolution.x, u_resolution.y));
        float radiusSquared = dot(point, point);
        if (radiusSquared > 1.0) discard;

        vec3 surface = vec3(point, sqrt(max(0.0, 1.0 - radiusSquared)));
        float cosine = cos(u_rotation);
        float sine = sin(u_rotation);
        vec3 globe = vec3(
          cosine * surface.x - sine * surface.z,
          surface.y,
          sine * surface.x + cosine * surface.z
        );

        float longitude = atan(globe.x, globe.z);
        float latitude = asin(clamp(globe.y, -1.0, 1.0));
        vec2 uv = vec2(fract(longitude / 6.28318530718 + 0.5), latitude / 3.14159265359 + 0.5);
        vec4 color = texture2D(u_atlas, uv);

        vec3 lightDirection = normalize(vec3(-0.38, 0.48, 0.79));
        float light = 0.66 + 0.34 * max(dot(surface, lightDirection), 0.0);
        float limb = smoothstep(0.0, 0.24, surface.z);
        color.rgb *= light * mix(0.72, 1.0, limb);
        gl_FragColor = color;
      }
    `;

    const compile = (type: number, source: string) => {
      const shader = gl.createShader(type);
      if (!shader) return null;
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        gl.deleteShader(shader);
        return null;
      }
      return shader;
    };

    const vertexShader = compile(gl.VERTEX_SHADER, vertexSource);
    const fragmentShader = compile(gl.FRAGMENT_SHADER, fragmentSource);
    if (!vertexShader || !fragmentShader) return;

    const program = gl.createProgram();
    if (!program) return;
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);
    gl.deleteShader(vertexShader);
    gl.deleteShader(fragmentShader);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      gl.deleteProgram(program);
      return;
    }

    const positions = gl.createBuffer();
    const texture = gl.createTexture();
    if (!positions || !texture) {
      gl.deleteProgram(program);
      return;
    }

    gl.bindBuffer(gl.ARRAY_BUFFER, positions);
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]),
      gl.STATIC_DRAW,
    );
    gl.useProgram(program);
    const positionLocation = gl.getAttribLocation(program, "a_position");
    gl.enableVertexAttribArray(positionLocation);
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

    const resolutionLocation = gl.getUniformLocation(program, "u_resolution");
    const rotationLocation = gl.getUniformLocation(program, "u_rotation");
    const atlasLocation = gl.getUniformLocation(program, "u_atlas");
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.uniform1i(atlasLocation, 0);
    gl.clearColor(0, 0, 0, 0);

    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const nextWidth = Math.max(1, Math.round(rect.width * dpr));
      const nextHeight = Math.max(1, Math.round(rect.height * dpr));
      if (nextWidth === pixelWidth && nextHeight === pixelHeight) return;
      pixelWidth = nextWidth;
      pixelHeight = nextHeight;
      canvas.width = pixelWidth;
      canvas.height = pixelHeight;
      gl.viewport(0, 0, pixelWidth, pixelHeight);
      gl.uniform2f(resolutionLocation, pixelWidth, pixelHeight);
    };

    const draw = (now: number) => {
      if (disposed) return;
      resize();
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.uniform1f(rotationLocation, reduced ? 0 : ((now - startTime) / 1000) * SPIN);
      gl.drawArrays(gl.TRIANGLES, 0, 6);
      if (!reduced && !document.hidden) raf = requestAnimationFrame(draw);
      else raf = 0;
    };

    const makeAtlas = (images: HTMLImageElement[]) => {
      const atlas = document.createElement("canvas");
      atlas.width = 2048;
      atlas.height = 1024;
      const context = atlas.getContext("2d");
      if (!context) return;

      context.fillStyle = "#00d3dc";
      context.fillRect(0, 0, atlas.width, atlas.height);
      const bandHeight = atlas.height / globeBands.length;
      const gutter = 2;

      globeBands.forEach((band, row) => {
        const cellWidth = atlas.width / band.columns;
        for (let column = 0; column < band.columns; column++) {
          const gameIndex = (column * 5 + row * 3) % globeGames.length;
          const image = images[gameIndex];
          const x = column * cellWidth + gutter;
          const y = row * bandHeight + gutter;
          const width = cellWidth - gutter * 2;
          const height = bandHeight - gutter * 2;

          if (image?.naturalWidth && image.naturalHeight) {
            const crop = Math.min(image.naturalWidth, image.naturalHeight);
            const sx = (image.naturalWidth - crop) / 2;
            const sy = (image.naturalHeight - crop) / 2;
            context.drawImage(image, sx, sy, crop, crop, x, y, width, height);
          } else {
            context.fillStyle = "#10264d";
            context.fillRect(x, y, width, height);
          }
        }
      });

      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1);
      gl.bindTexture(gl.TEXTURE_2D, texture);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, atlas);
      atlasReady = true;
      startTime = performance.now();
      if (reduced) draw(startTime);
      else if (!document.hidden) raf = requestAnimationFrame(draw);
    };

    const imageLoads = globeGames.map(({ image }) => new Promise<HTMLImageElement>((resolve) => {
      const gameImage = new Image();
      gameImage.onload = () => resolve(gameImage);
      gameImage.onerror = () => resolve(gameImage);
      gameImage.src = `/assets/game-banners/${image}`;
    }));

    Promise.all(imageLoads).then((images) => {
      if (!disposed) makeAtlas(images);
    });

    const observer = new ResizeObserver(() => {
      resize();
      if (reduced && atlasReady) draw(performance.now());
    });
    observer.observe(canvas);
    const onVisibilityChange = () => {
      if (!reduced && !document.hidden && !raf) {
        startTime = performance.now();
        raf = requestAnimationFrame(draw);
      }
    };
    document.addEventListener("visibilitychange", onVisibilityChange);

    return () => {
      disposed = true;
      cancelAnimationFrame(raf);
      observer.disconnect();
      document.removeEventListener("visibilitychange", onVisibilityChange);
      gl.deleteTexture(texture);
      gl.deleteBuffer(positions);
      gl.deleteProgram(program);
    };
  }, []);

  const ctaFocus = "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ns-accent";

  return (
    <section
      ref={rootRef}
      data-hero="burin"
      className={"relative isolate flex items-center overflow-hidden bg-transparent " + className}
    >
      <div className="mx-auto grid w-full max-w-6xl grid-cols-1 items-center gap-10 px-6 py-16 lg:grid-cols-2 lg:gap-14 lg:py-24">
        <div className="hero-copy order-1 lg:order-1">
          {eyebrow ? (
            <p className="eyebrow">
              <span className="eyebrow-dot" aria-hidden="true" />
              {eyebrow}
            </p>
          ) : null}
          <h1
            className="hero-title font-semibold text-ns-paper"
            style={{
              fontSize: "clamp(42px, 4vw, 52px)",
              lineHeight: 1.04,
              letterSpacing: "-0.065em",
            }}
          >
            {headlineLines.map((line, i) => (
              <span
                key={i}
                className={i === headlineLines.length - 1 ? "hero-title-accent" : "hero-title-primary"}
              >
                {line}
              </span>
            ))}
          </h1>
          {subcopy ? (
            <p className="hero-description">
              {subcopy}
            </p>
          ) : null}
          <div className="hero-actions">
            {primaryCta.href ? (
              <a
                href={primaryCta.href}
                data-cta="primary"
                onClick={primaryCta.onClick}
                className={"button button-primary " + ctaFocus}
              >
                {primaryCta.label}
                <span aria-hidden="true">↓</span>
              </a>
            ) : (
              <button
                type="button"
                data-cta="primary"
                onClick={primaryCta.onClick}
                className={"button button-primary " + ctaFocus}
              >
                {primaryCta.label}
                <span aria-hidden="true">↓</span>
              </button>
            )}
            {secondaryCta ? (
              secondaryCta.href ? (
                <a
                  href={secondaryCta.href}
                  onClick={secondaryCta.onClick}
                  className={"button button-quiet " + ctaFocus}
                >
                  {secondaryCta.label}
                  <span aria-hidden="true">↗</span>
                </a>
              ) : (
                <button
                  type="button"
                  onClick={secondaryCta.onClick}
                  className={"button button-quiet " + ctaFocus}
                >
                  {secondaryCta.label}
                  <span aria-hidden="true">↗</span>
                </button>
              )
            ) : null}
          </div>
        </div>

        <div
          data-burin-stage
          className="hero-planet-stage order-2 lg:order-2"
        >
          <canvas
            ref={canvasRef}
            aria-hidden="true"
            className="block h-full w-full text-ns-accent"
          />
          <div
            className="planet-game-surface"
            role="img"
            aria-label={`${plateLabel} covered with a mosaic of small square covers from ${globeGames.map((game) => game.title).join(", ")}.`}
          >
            <canvas ref={mosaicCanvasRef} className="planet-game-canvas" aria-hidden="true" />
            <span className="planet-game-shading" aria-hidden="true" />
          </div>
        </div>
      </div>
    </section>
  );
}

export default BurinHatch;
