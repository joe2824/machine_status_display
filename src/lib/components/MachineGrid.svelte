<script lang="ts">
  import type { Machine } from '$lib/stores/machines';
  import MachineCard from './MachineCard.svelte';
  import { t } from '$lib/i18n';

  let { machines }: { machines: Machine[] } = $props();

  function cols(n: number): number {
    if (n <= 1) return 1;
    if (n <= 2) return 2;
    if (n <= 4) return 2;
    if (n <= 6) return 3;
    if (n <= 9) return 3;
    return 4;
  }

  let gridCols = $derived(cols(machines.length));
</script>

<div
  class="grid w-screen h-screen bg-base grid-gutter auto-rows-fr"
  style="grid-template-columns: repeat({gridCols}, 1fr);"
>
  {#each machines as machine (machine.id)}
    <div class="min-w-0 min-h-0 overflow-hidden">
      <MachineCard {machine} />
    </div>
  {/each}

  {#if machines.length === 0}
    <div class="min-w-0 min-h-0 flex items-center justify-center">
      <p class="text-muted text-2xl font-semibold text-center">{$t.noMachines}</p>
    </div>
  {/if}
</div>
