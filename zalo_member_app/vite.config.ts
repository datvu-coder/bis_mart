import { defineConfig } from "vite";
import zaloMiniApp from "zmp-vite-plugin";
import react from "@vitejs/plugin-react";

export default () => {
  return defineConfig({
    root: "./src",
    base: "",
    build: { outDir: "../www", emptyOutDir: true },
    plugins: [
      zaloMiniApp({
        app: {
          title: "Bi'S MART Member",
          headerTitle: "Bi'S MART Member",
          headerColor: "#C1622B",
          textColor: "white",
          statusBar: "normal",
          leftButton: "back",
        },
        listCSS: [],
        listSyncJS: [],
        listAsyncJS: [],
      }),
      react(),
    ],
  });
};
