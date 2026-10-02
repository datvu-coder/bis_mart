import { defineConfig } from "vite";
import zaloMiniApp from "zmp-vite-plugin";
import react from "@vitejs/plugin-react";

export default () => {
  return defineConfig({
    root: "./src",
    base: "",
    build: { outDir: "../www", emptyOutDir: true },
    plugins: [
      // Config lives here (not in a root app-config.json): `zmp deploy -e` prefers a root
      // app-config.json, whose asset lists are empty, over the generated www/app-config.json.
      zaloMiniApp({
        app: {
          title: "Bi'S MART Công việc",
          headerTitle: "Bi'S MART Công việc",
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
