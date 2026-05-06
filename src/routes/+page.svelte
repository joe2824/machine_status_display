<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { machines, loadMachines, saveMachine, deleteMachine, createEmptyMachine } from '$lib/stores/machines';
  import type { Machine } from '$lib/stores/machines';
  import { mediaLibrary, loadMediaLibrary, saveMediaLibrary } from '$lib/stores/mediaLibrary';
  import MachineGrid from '$lib/components/MachineGrid.svelte';
  import MachineManager from '$lib/components/MachineManager.svelte';
  import EditDialog from '$lib/components/EditDialog.svelte';
  import MediaLibraryDialog from '$lib/components/MediaLibraryDialog.svelte';
  import OSK from '$lib/components/OSK.svelte';
  import { locale, t } from '$lib/i18n';
  import { pixelShift, startBurnInProtection, stopBurnInProtection } from '$lib/stores/burnin';
  import { invoke } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';

  let managerOpen      = $state(false);
  let mediaLibraryOpen = $state(false);
  let editingMachine   = $state<Machine | null>(null);
  let isNew            = $state(false);

  // USB update
  let usbUpdate     = $state<{ path: string; version: string } | null>(null);
  let usbInstalling = $state(false);

  // OTA update
  let otaUpdate     = $state<{ version: string; path: string } | null>(null);
  let otaInstalling = $state(false);

  let unlistenUsb: (() => void) | null = null;
  let unlistenOta: (() => void) | null = null;
  let cursorTimer: ReturnType<typeof setTimeout> | null = null;

  function resetCursorTimer() {
    document.documentElement.style.cursor = '';
    if (cursorTimer) clearTimeout(cursorTimer);
    cursorTimer = setTimeout(() => {
      document.documentElement.style.cursor = 'none';
    }, 5000);
  }

  onMount(async () => {
    await Promise.all([loadMachines(), loadMediaLibrary()]);
    startBurnInProtection();
    document.addEventListener('mousemove', resetCursorTimer);
    resetCursorTimer();
    unlistenUsb = await listen<{ path: string; version: string }>('usb-update-available', (e) => {
      usbUpdate = e.payload;
    });
    unlistenOta = await listen<{ version: string; path: string }>('ota-update-available', (e) => {
      otaUpdate = e.payload;
    });
  });
  onDestroy(() => {
    stopBurnInProtection();
    unlistenUsb?.();
    unlistenOta?.();
    document.removeEventListener('mousemove', resetCursorTimer);
    if (cursorTimer) clearTimeout(cursorTimer);
  });

  async function installUsbUpdate() {
    if (!usbUpdate) return;
    usbInstalling = true;
    try {
      await invoke('install_usb_update', { path: usbUpdate.path });
    } catch {
      usbInstalling = false;
    }
  }

  async function installOtaUpdate() {
    if (!otaUpdate) return;
    otaInstalling = true;
    try {
      await invoke('install_ota_update', { path: otaUpdate.path });
    } catch {
      otaInstalling = false;
    }
  }

  function handleManagerEdit(machine: Machine) {
    managerOpen = false;
    isNew = false;
    editingMachine = JSON.parse(JSON.stringify(machine));
  }

  function handleManagerAdd() {
    managerOpen = false;
    isNew = true;
    editingMachine = createEmptyMachine();
  }

  async function handleSave(machine: Machine) {
    await saveMachine(machine);
    editingMachine = null;
  }

  async function handleDelete(id: string) {
    await deleteMachine(id);
    editingMachine = null;
  }

  async function handleLibrarySave(lib: typeof $mediaLibrary) {
    await saveMediaLibrary(lib);
    mediaLibraryOpen = false;
  }
</script>

<svelte:head>
  <title>{$t.appTitle}</title>
</svelte:head>

<div class="relative w-screen h-screen overflow-hidden bg-base">

  <div
    class="w-full h-full"
    style="transform: translate({$pixelShift.x}px, {$pixelShift.y}px); transition: transform 3s ease-in-out;"
  >
    <div class="fixed top-3 right-3 z-200 flex gap-2 items-center">
      <button
        class="bg-card border border-stroke rounded-lg text-muted text-xs font-bold uppercase tracking-widest px-3 py-2 hover:border-highlight hover:text-ink transition-colors"
        onclick={() => locale.update((l) => (l === 'de' ? 'en' : 'de'))}
        type="button"
        title="Sprache wechseln"
      >
        {$locale === 'de' ? 'EN' : 'DE'}
      </button>

      <button
        class="bg-card border border-stroke rounded-lg text-muted px-2.5 py-2 hover:border-highlight hover:text-ink transition-colors flex items-center"
        onclick={() => (managerOpen = true)}
        type="button"
        title="Maschinen verwalten"
      >
        <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/>
        </svg>
      </button>
    </div>

    <MachineGrid machines={$machines} />
  </div>

  {#if managerOpen}
    <MachineManager
      machines={$machines}
      onEdit={handleManagerEdit}
      onAdd={handleManagerAdd}
      onOpenMediaLibrary={() => (mediaLibraryOpen = true)}
      onClose={() => (managerOpen = false)}
    />
  {/if}

  {#if editingMachine}
    <EditDialog
      machine={editingMachine}
      library={$mediaLibrary}
      {isNew}
      onSave={handleSave}
      onDelete={handleDelete}
      onClose={() => { editingMachine = null; managerOpen = true; }}
    />
  {/if}

  {#if mediaLibraryOpen}
    <MediaLibraryDialog
      library={$mediaLibrary}
      onSave={handleLibrarySave}
      onClose={() => (mediaLibraryOpen = false)}
    />
  {/if}

  <OSK />

  {#if usbUpdate}
    <div class="fixed bottom-0 left-0 right-0 z-300 bg-blue-600/95 backdrop-blur text-white px-6 py-4 flex items-center justify-between gap-4 shadow-[0_-4px_24px_rgba(0,0,0,0.5)]">
      <div class="flex flex-col">
        <span class="font-bold text-base">{$t.usbUpdateAvailable}</span>
        <span class="text-blue-200 text-sm">Version {usbUpdate.version}</span>
      </div>
      <div class="flex gap-3 shrink-0">
        <button
          class="px-4 py-2 rounded-lg text-sm font-semibold bg-white/10 hover:bg-white/20 transition-colors border border-white/20 cursor-pointer"
          onclick={() => (usbUpdate = null)}
          type="button"
          disabled={usbInstalling}
        >{$t.usbUpdateIgnore}</button>
        <button
          class="px-4 py-2 rounded-lg text-sm font-bold bg-white text-blue-700 hover:bg-blue-50 transition-colors cursor-pointer disabled:opacity-60"
          onclick={installUsbUpdate}
          type="button"
          disabled={usbInstalling}
        >{usbInstalling ? $t.usbUpdateInstalling : $t.usbUpdateInstall}</button>
      </div>
    </div>
  {/if}

  {#if otaUpdate && !usbUpdate}
    <div class="fixed bottom-0 left-0 right-0 z-300 bg-emerald-700/95 backdrop-blur text-white px-6 py-4 flex items-center justify-between gap-4 shadow-[0_-4px_24px_rgba(0,0,0,0.5)]">
      <div class="flex flex-col">
        <span class="font-bold text-base">{$t.otaUpdateAvailable}</span>
        <span class="text-emerald-200 text-sm">Version {otaUpdate.version}</span>
      </div>
      <div class="flex gap-3 shrink-0">
        <button
          class="px-4 py-2 rounded-lg text-sm font-semibold bg-white/10 hover:bg-white/20 transition-colors border border-white/20 cursor-pointer"
          onclick={() => (otaUpdate = null)}
          type="button"
          disabled={otaInstalling}
        >{$t.otaUpdateIgnore}</button>
        <button
          class="px-4 py-2 rounded-lg text-sm font-bold bg-white text-emerald-700 hover:bg-emerald-50 transition-colors cursor-pointer disabled:opacity-60"
          onclick={installOtaUpdate}
          type="button"
          disabled={otaInstalling}
        >{otaInstalling ? $t.otaUpdateInstalling : $t.otaUpdateInstall}</button>
      </div>
    </div>
  {/if}
</div>
