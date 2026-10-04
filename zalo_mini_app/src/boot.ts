// Runs before the rest of the app: shows a visible message while the app starts and prints any
// start-up error on screen, so a failure is never just a blank page.
const root = () => document.getElementById("app");
const booting = () => !!root()?.querySelector("[data-boot]");

const show = (title: string, detail?: string) => {
  const el = root();
  if (!el) return;
  el.innerHTML = "";
  const box = document.createElement("div");
  box.setAttribute("data-boot", "1");
  box.setAttribute("style", "padding:48px 20px;text-align:center;font:15px/1.5 -apple-system,Helvetica,Arial,sans-serif;color:#6b5a4a");
  const h = document.createElement("div");
  h.textContent = title;
  h.setAttribute("style", "font-weight:600;margin-bottom:8px");
  box.appendChild(h);
  if (detail) {
    const d = document.createElement("div");
    d.textContent = detail;
    d.setAttribute("style", "font-size:12px;color:#b14a3d;word-break:break-word;text-align:left");
    box.appendChild(d);
  }
  el.appendChild(box);
};

const describe = (e: unknown): string => {
  if (e instanceof Error) return `${e.name}: ${e.message}`;
  try { return typeof e === "string" ? e : JSON.stringify(e); } catch { return String(e); }
};

show("Đang khởi động...");

const seen: string[] = [];

// A script error before the first render means the app cannot start: say why instead of a blank page.
window.addEventListener("error", (ev) => {
  const text = `${ev.message || describe(ev.error)}${ev.filename ? ` (${ev.filename.split("/").pop()}:${ev.lineno})` : ""}`;
  seen.push(text);
  if (ev.error && booting()) show("Không khởi động được", text);
});
// Rejected promises are only noted: some SDK calls reject harmlessly while the app is starting up.
window.addEventListener("unhandledrejection", (ev) => {
  seen.push(describe(ev.reason));
});

// Still showing the boot message a few seconds later: the app did not start.
setTimeout(() => {
  if (booting()) show("Ứng dụng chưa khởi động được", seen.length ? seen.join("\n") : "Không ghi nhận lỗi nào. Hãy thoát hẳn Zalo rồi mở lại.");
}, 5000);

export {};
