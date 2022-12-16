import "../css/app.css";

import { createSSRApp, h } from "vue";
import { renderToString } from "@vue/server-renderer";
import { createInertiaApp } from "@inertiajs/inertia-vue3";
import createServer from "@inertiajs/server";

const appName = "Dart Inertia";

createServer((page) =>
  createInertiaApp({
    page,
    render: renderToString,
    title: (title) => `${title} - ${appName}`,
    resolve: (name) =>
      resolvePageComponent(
        `./Pages/${name}.vue`,
        import.meta.glob("./Pages/**/*.vue")
      ),
    setup({ app, props, plugin }) {
      return createSSRApp({ render: () => h(app, props) }).use(plugin);
    },
  })
);

async function resolvePageComponent(path, pages) {
  const page = pages[path];

  if (typeof page === "undefined") {
    throw new Error(`Page not found: ${path}`);
  }

  return typeof page === "function" ? page() : page;
}
