import { defineConfig } from "vite";
import zaloMiniApp from "zmp-vite-plugin";
import react from "@vitejs/plugin-react";

export default () => {
  return defineConfig({
    root: "./src",
    base: "",
    build: { outDir: "../www", emptyOutDir: true },
    plugins: [zaloMiniApp(), react()],
  });
};
