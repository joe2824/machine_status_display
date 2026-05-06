<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import type { Machine } from '$lib/stores/machines';
  import { t } from '$lib/i18n';
  import { getVersion } from '@tauri-apps/api/app';
  import { invoke } from '@tauri-apps/api/core';

  let appVersion = $state('…');
  let usbDebugLog = $state<string[] | null>(null);
  let usbDebugRunning = $state(false);
  let usbDebugInterval: ReturnType<typeof setInterval> | null = null;
  let serviceLog = $state<string[] | null>(null);
  let serviceLogRunning = $state(false);
  let serviceLogInterval: ReturnType<typeof setInterval> | null = null;

  async function runUsbDebug() {
    usbDebugRunning = true;
    usbDebugLog = await invoke<string[]>('debug_usb_scan');
    serviceLog = null;
    usbDebugRunning = false;
    if (!usbDebugInterval) {
      usbDebugInterval = setInterval(async () => {
        if (usbDebugLog !== null) {
          usbDebugLog = await invoke<string[]>('debug_usb_scan');
        } else {
          clearInterval(usbDebugInterval!);
          usbDebugInterval = null;
        }
      }, 5000);
    }
  }

  function closeUsbDebug() {
    usbDebugLog = null;
    if (usbDebugInterval) { clearInterval(usbDebugInterval); usbDebugInterval = null; }
  }

  async function runServiceLog() {
    serviceLogRunning = true;
    serviceLog = await invoke<string[]>('get_service_log');
    closeUsbDebug();
    serviceLogRunning = false;
    if (!serviceLogInterval) {
      serviceLogInterval = setInterval(async () => {
        if (serviceLog !== null) {
          serviceLog = await invoke<string[]>('get_service_log');
        } else {
          clearInterval(serviceLogInterval!);
          serviceLogInterval = null;
        }
      }, 5000);
    }
  }

  function closeServiceLog() {
    serviceLog = null;
    if (serviceLogInterval) { clearInterval(serviceLogInterval); serviceLogInterval = null; }
  }

  onDestroy(() => {
    if (usbDebugInterval) { clearInterval(usbDebugInterval); usbDebugInterval = null; }
    if (serviceLogInterval) { clearInterval(serviceLogInterval); serviceLogInterval = null; }
  });

  let {
    machines,
    onEdit,
    onAdd,
    onOpenMediaLibrary,
    onClose,
  }: {
    machines: Machine[];
    onEdit: (m: Machine) => void;
    onAdd: () => void;
    onOpenMediaLibrary: () => void;
    onClose: () => void;
  } = $props();

  onMount(async () => {
    appVersion = await getVersion();
  });

  const phaseBadgeClass: Record<string, string> = {
    Installation: 'text-blue-400 bg-blue-400/10 border-blue-400/30',
    Commissioning: 'text-amber-400 bg-amber-400/10 border-amber-400/30',
    'Test run':    'text-orange-400 bg-orange-400/10 border-orange-400/30',
    FAT:           'text-green-400 bg-green-400/10 border-green-400/30',
  };
</script>

<div
  class="fixed inset-0 bg-black/65 z-50 flex items-center justify-center p-6"
  role="none"
  onclick={onClose}
  onkeydown={(e) => e.key === 'Escape' && onClose()}
>
  <div
    class="bg-dialog border border-stroke rounded-2xl flex flex-col shadow-[0_24px_64px_rgba(0,0,0,0.8)] w-full max-w-175 max-h-[88vh]"
    role="dialog"
    aria-modal="true"
    tabindex="-1"
    onclick={(e) => e.stopPropagation()}
    onkeydown={(e) => e.stopPropagation()}
  >
    <div class="flex justify-between items-center px-6 pt-6 pb-4 border-b border-rim shrink-0">
      <h2 class="m-0 text-xl font-bold text-ink tracking-wide">{$t.manageMachines}</h2>
      <div class="flex items-center gap-2">
        <button
          class="flex items-center gap-1.5 border border-stroke rounded-lg px-3 py-2.5 text-xs font-semibold text-muted hover:border-highlight hover:text-ink transition-colors bg-transparent cursor-pointer"
          onclick={onOpenMediaLibrary}
          type="button"
          title={$t.mediaLibrary}
        >
          <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M17.7 7.7a2.5 2.5 0 1 1 1.8 4.3H2"/>
            <path d="M9.6 4.6A2 2 0 1 1 11 8H2"/>
            <path d="M12.6 19.4A2 2 0 1 0 14 16H2"/>
          </svg>
          {$t.manageMedia}
        </button>
        <button class="bg-transparent border-none text-muted cursor-pointer text-lg px-3 py-2.5 min-w-[2.75rem] min-h-[2.75rem] flex items-center justify-center rounded hover:text-ink transition-colors leading-none" onclick={onClose} type="button">✕</button>
      </div>
    </div>

    <div class="p-4 overflow-y-auto flex-1">
      <div class="grid grid-cols-2 gap-3">
        {#each machines as machine (machine.id)}
          <button
            class="flex flex-col items-start gap-3 p-5 bg-card border-2 border-stroke rounded-xl cursor-pointer text-left transition-colors hover:border-highlight hover:bg-card-hover active:bg-base min-h-36"
            onclick={() => onEdit(machine)}
            type="button"
          >
            <span class="text-xs font-bold uppercase tracking-wide border rounded px-2 py-0.5 {phaseBadgeClass[machine.phase] ?? 'text-zinc-400 bg-zinc-400/10 border-zinc-400/30'}">
              {$t.phases[machine.phase] ?? machine.phase}
            </span>
            <span class="text-2xl font-black text-ink tracking-tight leading-none flex-1 flex items-center">
              {machine.number || '—'}
            </span>
            <span class="text-xs text-muted font-semibold flex items-center gap-1">
              <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/>
              </svg>
              {$t.edit}
            </span>
          </button>
        {/each}

        <button
          class="flex flex-col items-center justify-center gap-2 p-5 bg-transparent border-2 border-dashed border-stroke rounded-xl cursor-pointer text-dim transition-colors hover:border-highlight hover:text-muted hover:bg-highlight/5 active:bg-highlight/10 min-h-36"
          onclick={onAdd}
          type="button"
        >
          <span class="text-4xl font-thin leading-none">+</span>
          <span class="text-sm font-semibold uppercase tracking-widest">{$t.addMachine}</span>
        </button>
      </div>
    </div>

    {#if usbDebugLog}
      <div class="px-6 py-3 border-t border-rim shrink-0 bg-black/30 max-h-48 overflow-y-auto">
        <div class="flex justify-between items-center mb-2">
          <span class="text-xs font-bold text-amber-400">USB Scan Debug</span>
          <button class="text-xs text-dim hover:text-muted bg-transparent border-none cursor-pointer px-2 py-1 min-w-[2rem] min-h-[2rem] flex items-center justify-center" onclick={closeUsbDebug} type="button">✕</button>
        </div>
        {#each usbDebugLog as line}
          <div class="text-xs font-mono text-muted leading-5 whitespace-pre">{line}</div>
        {/each}
      </div>
    {/if}

    {#if serviceLog}
      <div class="px-6 py-3 border-t border-rim shrink-0 bg-black/30 max-h-48 overflow-y-auto">
        <div class="flex justify-between items-center mb-2">
          <span class="text-xs font-bold text-sky-400">Service Journal</span>
          <button class="text-xs text-dim hover:text-muted bg-transparent border-none cursor-pointer px-2 py-1 min-w-[2rem] min-h-[2rem] flex items-center justify-center" onclick={closeServiceLog} type="button">✕</button>
        </div>
        {#each serviceLog as line}
          <div class="text-xs font-mono text-muted leading-5 whitespace-pre">{line}</div>
        {/each}
      </div>
    {/if}

    <div class="flex items-center justify-between px-6 py-3 border-t border-rim shrink-0 text-xs text-dim">
      <button
        class="text-xs text-dim bg-transparent border-none cursor-default p-2 select-none"
        onclick={runUsbDebug}
        disabled={usbDebugRunning}
        type="button"
      >v{appVersion}</button>
      <span>github.com/joe2824/machine_status_display</span>
      <button
        class="bg-transparent border-none text-dim hover:text-muted cursor-pointer p-2.5 rounded transition-colors"
        onclick={runServiceLog}
        disabled={serviceLogRunning}
        type="button"
        title="Service journal"
      >
      <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
          <polyline points="14 2 14 8 20 8"/>
          <line x1="16" y1="13" x2="8" y2="13"/>
          <line x1="16" y1="17" x2="8" y2="17"/>
          <polyline points="10 9 9 9 8 9"/>
        </svg>
      </button>
    </div>
  </div>
</div>
