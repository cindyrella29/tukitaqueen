(() => {
const canvas = document.getElementById("purpleParticles");
const ctx = canvas ? canvas.getContext("2d") : null;
const passwordInput = document.getElementById("password");
const eyeToggle = document.querySelector(".eye-toggle");

let width = 0;
let height = 0;
let particles = [];
let raf = 0;
let lastSparkle = 0;

function resizeCanvas() {
  if (!canvas || !ctx) {
    return;
  }

  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  width = window.innerWidth;
  height = window.innerHeight;
  canvas.width = Math.floor(width * dpr);
  canvas.height = Math.floor(height * dpr);
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

  const amount = Math.min(118, Math.max(58, Math.floor((width * height) / 16500)));
  particles = Array.from({ length: amount }, createParticle);
}

function createParticle() {
  const size = Math.random() * 1.8 + .45;
  return {
    x: Math.random() * width,
    y: Math.random() * height,
    size,
    speedX: (Math.random() - .5) * .22,
    speedY: -(Math.random() * .28 + .08),
    drift: Math.random() * .012 + .004,
    phase: Math.random() * Math.PI * 2,
    alpha: Math.random() * .42 + .18
  };
}

function drawParticle(particle, time) {
  if (!ctx) {
    return;
  }

  particle.phase += particle.drift;
  particle.x += particle.speedX + Math.sin(particle.phase) * .09;
  particle.y += particle.speedY;

  if (particle.y < -12 || particle.x < -18 || particle.x > width + 18) {
    Object.assign(particle, createParticle(), {
      y: height + Math.random() * 40
    });
  }

  const pulse = .65 + Math.sin(time * .002 + particle.phase) * .35;
  const radius = particle.size * (1 + pulse * .85);
  const gradient = ctx.createRadialGradient(particle.x, particle.y, 0, particle.x, particle.y, radius * 5);
  gradient.addColorStop(0, `rgba(217, 70, 239, ${particle.alpha * pulse})`);
  gradient.addColorStop(.32, `rgba(193, 91, 255, ${particle.alpha * .45})`);
  gradient.addColorStop(1, "rgba(160, 32, 240, 0)");

  ctx.beginPath();
  ctx.fillStyle = gradient;
  ctx.arc(particle.x, particle.y, radius * 5, 0, Math.PI * 2);
  ctx.fill();
}

function animate(time) {
  if (!ctx) {
    return;
  }

  ctx.clearRect(0, 0, width, height);
  ctx.globalCompositeOperation = "lighter";
  particles.forEach((particle) => drawParticle(particle, time));
  raf = requestAnimationFrame(animate);
}

if (eyeToggle && passwordInput) {
  eyeToggle.addEventListener("click", () => {
    const visible = passwordInput.type === "text";
    passwordInput.type = visible ? "password" : "text";
    eyeToggle.classList.toggle("is-visible", !visible);
    eyeToggle.setAttribute("aria-pressed", String(!visible));
    eyeToggle.setAttribute("aria-label", visible ? "Mostrar contraseña" : "Ocultar contraseña");
  });
}

window.addEventListener("pointermove", (event) => {
  const now = Date.now();

  if (now - lastSparkle < 44) {
    return;
  }

  lastSparkle = now;

  const sparkle = document.createElement("span");
  const driftX = `${(Math.random() - .5) * 34}px`;
  const driftY = `${-14 - Math.random() * 28}px`;

  sparkle.className = "cursor-sparkle";
  sparkle.style.left = `${event.clientX}px`;
  sparkle.style.top = `${event.clientY}px`;
  sparkle.style.setProperty("--spark-x", driftX);
  sparkle.style.setProperty("--spark-y", driftY);

  document.body.appendChild(sparkle);
  sparkle.addEventListener("animationend", () => sparkle.remove(), { once: true });
}, { passive: true });

if (canvas && ctx) {
  window.addEventListener("resize", resizeCanvas, { passive: true });
  resizeCanvas();
  cancelAnimationFrame(raf);
  raf = requestAnimationFrame(animate);
}
})();
