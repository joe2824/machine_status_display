<script lang="ts">
  import { untrack } from 'svelte';
  import type { LibraryMedium } from '$lib/stores/mediaLibrary';
  import { t } from '$lib/i18n';
  import { showOSK, syncOSKValue } from '$lib/stores/osk';

  let {
    library,
    onSave,
    onClose,
  }: {
    library: LibraryMedium[];
    onSave: (lib: LibraryMedium[]) => void;
    onClose: () => void;
  } = $props();

  let draft       = $state<LibraryMedium[]>(untrack(() => JSON.parse(JSON.stringify(library))));
  let nameGerman  = $state('');
  let nameEnglish = $state('');

  function addItem() {
    const de = nameGerman.trim();
    if (!de) return;
    draft.push({ id: crypto.randomUUID(), de, en: nameEnglish.trim() });
    nameGerman  = '';
    nameEnglish = '';
  }

  function removeItem(i: number) { draft.splice(i, 1); }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter') addItem();
  }
</script>

<div
  class="fixed inset-0 bg-black/65 z-50 flex items-center justify-center p-6"
  role="none"
  onclick={onClose}
  onkeydown={(e) => e.key === 'Escape' && onClose()}
>
  <div
    class="bg-dialog border border-stroke rounded-2xl w-full max-w-175 max-h-[90vh] overflow-y-auto flex flex-col shadow-[0_24px_64px_rgba(0,0,0,0.8)]"
    role="dialog"
    aria-modal="true"
    tabindex="-1"
    onclick={(e) => e.stopPropagation()}
    onkeydown={(e) => e.stopPropagation()}
  >
    <div class="flex justify-between items-center px-6 pt-6 pb-4 border-b border-rim shrink-0">
      <h2 class="m-0 text-xl font-bold text-ink tracking-wide">{$t.mediaLibrary}</h2>
      <button class="bg-transparent border-none text-muted cursor-pointer text-lg px-2 py-1 rounded hover:text-ink transition-colors leading-none" onclick={onClose} type="button">✕</button>
    </div>

    <div class="p-6 flex flex-col gap-6 flex-1">

      {#if draft.length > 0}
        <div class="flex flex-col gap-2">
          {#each draft as item, i}
            <div class="flex items-center gap-3 bg-overlay border border-stroke rounded-lg px-4 py-2.5">
              <span class="flex-1 text-ink font-semibold">{item.de}</span>
              <span class="text-muted font-medium">/</span>
              <span class="flex-1 text-muted font-medium">{item.en || '—'}</span>
              <button
                class="text-danger/50 hover:text-danger transition-colors cursor-pointer bg-transparent border-none leading-none text-lg px-1"
                onclick={() => removeItem(i)}
                type="button"
                aria-label="Remove"
              >✕</button>
            </div>
          {/each}
        </div>
      {/if}

      <div class="flex flex-col gap-2">
        <span class="text-xs font-bold uppercase tracking-widest text-muted">New</span>
        <div class="flex gap-2">
          <div class="flex-1 flex flex-col gap-1">
            <span class="text-xs text-muted font-semibold">{$t.nameGerman}</span>
            <div class="relative flex items-center">
              <input
                class="w-full bg-overlay border border-stroke rounded-lg px-3 py-2 text-ink font-semibold transition-colors focus:border-highlight focus:outline-none placeholder:text-dim pr-7 text-sm"
                type="text"
                bind:value={nameGerman}
                placeholder="Druckluft"
                onfocus={() => showOSK(nameGerman, $t.nameGerman, (v) => (nameGerman = v))}
                oninput={(e) => syncOSKValue((e.currentTarget as HTMLInputElement).value)}
                onkeydown={handleKeydown}
                autocomplete="off"
                spellcheck={false}
              />
              <span class="absolute right-2 text-dim pointer-events-none text-xs">⌨</span>
            </div>
          </div>
          <div class="flex-1 flex flex-col gap-1">
            <span class="text-xs text-muted font-semibold">{$t.nameEnglish}</span>
            <div class="relative flex items-center">
              <input
                class="w-full bg-overlay border border-stroke rounded-lg px-3 py-2 text-ink font-semibold transition-colors focus:border-highlight focus:outline-none placeholder:text-dim pr-7 text-sm"
                type="text"
                bind:value={nameEnglish}
                placeholder="Compressed Air"
                onfocus={() => showOSK(nameEnglish, $t.nameEnglish, (v) => (nameEnglish = v))}
                oninput={(e) => syncOSKValue((e.currentTarget as HTMLInputElement).value)}
                onkeydown={handleKeydown}
                autocomplete="off"
                spellcheck={false}
              />
              <span class="absolute right-2 text-dim pointer-events-none text-xs">⌨</span>
            </div>
          </div>
          <div class="flex flex-col justify-end">
            <button
              class="px-4 py-2 rounded-lg text-sm font-bold cursor-pointer bg-ink/5 border border-stroke text-muted hover:border-highlight hover:text-ink transition-colors"
              onclick={addItem}
              type="button"
            >+</button>
          </div>
        </div>
      </div>

    </div>

    <div class="flex justify-end gap-2 px-6 pb-6 pt-4 border-t border-rim shrink-0">
      <button
        class="px-5 py-2.5 rounded-lg text-sm font-bold cursor-pointer bg-transparent border border-stroke text-muted hover:border-highlight hover:text-ink transition-colors"
        onclick={onClose}
        type="button"
      >{$t.cancel}</button>
      <button
        class="px-5 py-2.5 rounded-lg text-sm font-bold cursor-pointer bg-ok/10 border border-ok/40 text-ok hover:bg-ok/20 hover:border-ok/70 transition-colors"
        onclick={() => onSave(draft)}
        type="button"
      >{$t.save}</button>
    </div>
  </div>
</div>
