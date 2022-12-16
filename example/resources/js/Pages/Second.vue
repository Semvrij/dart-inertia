<script setup>
import { Link } from "@inertiajs/inertia-vue3";
import { Head } from "@inertiajs/inertia-vue3";

const props = defineProps({
  prop: String,
});
</script>

<template>
  <Head>
    <title>Second</title>
    <meta name="description" content="Dart with package:inertia" />
  </Head>

  <div>
    <Link href="/" class="text-green-500">Back to home page</Link>
  </div>
</template>
