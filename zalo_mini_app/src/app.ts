// Diagnostic build: no React, no SDK. If this shows on a phone, Zalo runs our code fine.
const el = document.getElementById("app");
if (el) {
  el.innerHTML = "";
  const box = document.createElement("div");
  box.setAttribute("style", "padding:60px 20px;text-align:center;font:16px/1.6 -apple-system,Helvetica,Arial,sans-serif;color:#3b2a1a");
  const t = document.createElement("div");
  t.textContent = "Bản thử tối giản: mã JS đang chạy";
  t.setAttribute("style", "font-weight:700;font-size:18px;margin-bottom:12px");
  const c = document.createElement("div");
  box.appendChild(t);
  box.appendChild(c);
  el.appendChild(box);
  let s = 0;
  const tick = () => { c.textContent = `Đã chạy ${s}s`; s += 1; };
  tick();
  setInterval(tick, 1000);
} else {
  document.title = "no #app";
}
