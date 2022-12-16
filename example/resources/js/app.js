import "../css/app.css";

import { createApp, h } from "vue";
import { createInertiaApp } from "@inertiajs/inertia-vue3";
import { InertiaProgress } from "@inertiajs/progress";

const appName =
  window.document.getElementsByTagName("title")[0]?.innerText || "Dart Inertia";

createInertiaApp({
  title: (title) => `${title} - ${appName}`,
  resolve: (name) =>
    resolvePageComponent(
      `./Pages/${name}.vue`,
      import.meta.glob("./Pages/**/*.vue")
    ),
  setup({ el, app, props, plugin }) {
    return createApp({ render: () => h(app, props) })
      .use(plugin)
      .mount(el);
  },
});

InertiaProgress.init({ color: "#8B58E1" });

async function resolvePageComponent(path, pages) {
  const page = pages[path];

  if (typeof page === "undefined") {
    throw new Error(`Page not found: ${path}`);
  }

  return typeof page === "function" ? page() : page;
}
