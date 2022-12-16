import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import path from "path";

const publicDirectory = "public";
const buildDirectory = "build";

export default defineConfig(({ ssrBuild }) => ({
  publicDir: publicDirectory,
  build: {
    manifest: true,
    outDir: ssrBuild ? "ssr" : path.join(publicDirectory, buildDirectory),
    rollupOptions: {
      input: ssrBuild ? "./resources/js/ssr.js" : "./resources/js/app.js",
    },
  },
  plugins: [
    vue({
      template: {
        transformAssetUrls: {
          base: null,
          includeAbsolute: false,
        },
      },
    }),
  ],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./resources/js"),
    },
  },
  ssr: {
    noExternal: ["@inertiajs/server"],
  },
}));
