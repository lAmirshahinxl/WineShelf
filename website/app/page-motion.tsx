"use client";

import { useEffect } from "react";

export default function PageMotion() {
  useEffect(() => {
    const blocks = Array.from(
      document.querySelectorAll<HTMLElement>(
        "main > section, main > .capability-ribbon",
      ),
    );

    if (
      window.matchMedia("(prefers-reduced-motion: reduce)").matches ||
      !("IntersectionObserver" in window)
    ) {
      return;
    }

    const isInView = (element: HTMLElement) => {
      const bounds = element.getBoundingClientRect();
      return bounds.top < window.innerHeight * 0.92 && bounds.bottom > 0;
    };

    blocks.forEach((block) => {
      block.dataset.motion = isInView(block) ? "visible" : "pending";
    });
    document.documentElement.classList.add("motion-ready");

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          const block = entry.target as HTMLElement;
          block.dataset.motion = "visible";
          observer.unobserve(block);
        });
      },
      { threshold: 0.08, rootMargin: "0px 0px -6% 0px" },
    );

    blocks
      .filter((block) => block.dataset.motion === "pending")
      .forEach((block) => observer.observe(block));

    return () => {
      observer.disconnect();
      document.documentElement.classList.remove("motion-ready");
    };
  }, []);

  return null;
}
