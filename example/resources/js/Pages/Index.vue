<script setup>
import { Link } from "@inertiajs/inertia-vue3";
import { Inertia } from "@inertiajs/inertia";
import { Head } from "@inertiajs/inertia-vue3";

const props = defineProps({
  prop: String,
  lazy: String,
});

const loadlazy = () => {
  Inertia.reload({ only: ["lazy"] });
};
</script>

<template>
  <Head>
    <title>Home</title>
    <meta name="description" content="Dart with package:inertia" />
  </Head>

  <div class="flex flex-col gap-4">
    <div class="current-time">Current time {{ prop }}</div>
    <div class="link-class">
      <Link href="/second">Second page</Link>
    </div>
    <div><button @click="loadlazy">Load lazy</button>{{ lazy }}</div>
  </div>
</template>
