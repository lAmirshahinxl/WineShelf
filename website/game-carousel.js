(() => {
  const carousel = document.querySelector("[data-game-carousel]");
  if (!carousel) return;

  const stage = carousel.querySelector("[data-carousel-stage]");
  const slides = Array.from(carousel.querySelectorAll("[data-game-slide]"));
  const previousButton = carousel.querySelector("[data-carousel-previous]");
  const nextButton = carousel.querySelector("[data-carousel-next]");
  const toggleButton = carousel.querySelector("[data-carousel-toggle]");
  const pagination = carousel.querySelector("[data-carousel-pagination]");
  const title = carousel.querySelector("[data-carousel-title]");
  const announcement = carousel.querySelector("[data-carousel-announcement]");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

  if (!stage || !slides.length || !previousButton || !nextButton || !toggleButton || !pagination) return;

  const names = slides.map((slide) => slide.querySelector(".game-card-copy strong")?.textContent.trim() || "Featured game");
  let currentIndex = 0;
  let timer = null;
  let userPaused = reduceMotion.matches;
  let pointerInside = false;
  let pageVisible = document.visibilityState !== "hidden";

  const dots = slides.map((slide, index) => {
    const dot = document.createElement("button");
    dot.className = "carousel-dot";
    dot.type = "button";
    dot.setAttribute("aria-label", `Show ${names[index]}`);
    dot.addEventListener("click", () => showSlide(index, true));
    pagination.append(dot);
    return dot;
  });

  function rotationAllowed() {
    return !userPaused && !reduceMotion.matches && !pointerInside && pageVisible;
  }

  function updateRotation() {
    window.clearInterval(timer);
    timer = null;

    if (rotationAllowed()) {
      timer = window.setInterval(() => showSlide(currentIndex + 1), 5600);
    }

    const isPlaying = timer !== null;
    toggleButton.setAttribute("aria-label", isPlaying ? "Pause carousel" : "Play carousel");
    toggleButton.title = reduceMotion.matches ? "Automatic rotation is disabled by your motion preference" : isPlaying ? "Pause automatic rotation" : "Play automatic rotation";
    toggleButton.disabled = reduceMotion.matches;
  }

  function showSlide(requestedIndex, announce = false) {
    currentIndex = (requestedIndex + slides.length) % slides.length;
    const middle = Math.floor(slides.length / 2);

    slides.forEach((slide, index) => {
      let position = index - currentIndex;
      if (position > middle) position -= slides.length;
      if (position < -middle) position += slides.length;

      const distance = Math.abs(position);
      const opacity = [1, 0.68, 0.34, 0.12][distance] ?? 0;
      const scale = [1, 0.83, 0.68, 0.56][distance] ?? 0.5;
      const depth = 6 - distance;
      const active = distance === 0;
      const link = slide.querySelector("a");

      slide.style.setProperty("--card-position", position);
      slide.style.setProperty("--card-depth", depth);
      slide.style.setProperty("--card-opacity", opacity);
      slide.style.setProperty("--card-scale", scale);
      slide.dataset.current = String(active);
      slide.setAttribute("aria-hidden", String(!active));
      slide.inert = !active;

      if (link) link.tabIndex = active ? 0 : -1;

      if (!active) {
        const image = slide.querySelector("img[loading='lazy']");
        if (image && distance === 1) image.loading = "eager";
      }

      dots[index].setAttribute("aria-current", String(active));
    });

    if (title) title.textContent = names[currentIndex];
    if (announce && announcement) {
      announcement.textContent = `Showing ${names[currentIndex]}, slide ${currentIndex + 1} of ${slides.length}.`;
    }
  }

  previousButton.addEventListener("click", () => showSlide(currentIndex - 1, true));
  nextButton.addEventListener("click", () => showSlide(currentIndex + 1, true));

  toggleButton.addEventListener("click", () => {
    if (reduceMotion.matches) return;
    userPaused = timer !== null;
    updateRotation();
  });

  stage.addEventListener("keydown", (event) => {
    if (event.altKey || event.ctrlKey || event.metaKey) return;

    if (event.key === "ArrowLeft") {
      event.preventDefault();
      showSlide(currentIndex - 1, true);
    } else if (event.key === "ArrowRight") {
      event.preventDefault();
      showSlide(currentIndex + 1, true);
    } else if (event.key === "Home") {
      event.preventDefault();
      showSlide(0, true);
    } else if (event.key === "End") {
      event.preventDefault();
      showSlide(slides.length - 1, true);
    }
  });

  carousel.addEventListener("focusin", () => {
    userPaused = true;
    updateRotation();
  });

  carousel.addEventListener("pointerenter", (event) => {
    if (event.pointerType !== "touch") {
      pointerInside = true;
      updateRotation();
    }
  });

  carousel.addEventListener("pointerleave", (event) => {
    if (event.pointerType !== "touch") {
      pointerInside = false;
      updateRotation();
    }
  });

  document.addEventListener("visibilitychange", () => {
    pageVisible = document.visibilityState !== "hidden";
    updateRotation();
  });

  reduceMotion.addEventListener("change", () => {
    if (reduceMotion.matches) userPaused = true;
    updateRotation();
  });

  carousel.classList.add("is-ready");
  stage.classList.add("is-ready");
  showSlide(currentIndex);
  updateRotation();
})();
