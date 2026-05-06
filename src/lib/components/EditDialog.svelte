<script lang="ts">
  import { untrack } from 'svelte';
  import type { Machine, Phase } from '$lib/stores/machines';
  import type { LibraryMedium } from '$lib/stores/mediaLibrary';
  import { t, locale } from '$lib/i18n';
  import { showOSK, showNumericOSK, syncOSKValue, commitOSK, hideOSK } from '$lib/stores/osk';
  import { CircleCheck, TriangleAlert, OctagonAlert, X } from 'lucide-svelte';

  function onOSKKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter')  { commitOSK(); e.preventDefault(); }
    if (e.key === 'Escape') { hideOSK();   e.preventDefault(); e.stopPropagation(); }
  }

  let {
    machine,
    library = [],
    isNew = false,
    onSave,
    onDelete,
    onClose,
  }: {
    machine: Machine;
    library?: LibraryMedium[];
    isNew?: boolean;
    onSave: (m: Machine) => void;
    onDelete: (id: string) => void;
    onClose: () => void;
  } = $props();

  // Intentional snapshot for draft editing
  let draft = $state<Machine>(untrack(() => JSON.parse(JSON.stringify(machine))));

  // Remaining days: null = unlimited (days=0 or no date), number = days left
  let draftRemaining = $derived(
    draft.workPermit && draft.workPermitDays > 0 && draft.workPermitDate
      ? Math.max(0, Math.ceil(
          draft.workPermitDays -
          (Date.now() - new Date(draft.workPermitDate).getTime()) / 86_400_000
        ))
      : null
  );

  function resetWorkPermitTimer() {
    draft.workPermitDate = new Date().toISOString();
  }

  const phases: Phase[] = ['Installation', 'Commissioning', 'Test run', 'FAT'];
  const eStopOptions = ['OK', 'Teilweise', 'Ausgeloest'] as const;

  const phaseSelectedClass: Record<string, string> = {
    Installation: 'bg-blue-400/10 border-blue-400 text-blue-400',
    Commissioning: 'bg-amber-400/10 border-amber-400 text-amber-400',
    'Test run':    'bg-orange-400/10 border-orange-400 text-orange-400',
    FAT:           'bg-green-400/10 border-green-400 text-green-400',
  };

  const eStopSelectedClass: Record<string, string> = {
    OK:         'bg-ok/10 border-ok text-ok',
    Teilweise:  'bg-partial/10 border-partial text-partial',
    Ausgeloest: 'bg-danger/10 border-danger text-danger',
  };

  const defaultOptionClass = 'bg-overlay border-stroke text-muted hover:border-highlight hover:text-ink';

  let dialogTitle = $derived(
    isNew ? $t.newMachine : `${draft.number || '?'} – ${$t.editMachine}`
  );

  let availableFromLibrary = $derived(
    library.filter((lib) => !draft.media.some((m) => m.de === lib.de && m.en === lib.en))
  );

  function addFromLibrary(lib: LibraryMedium) {
    draft.media.push({ de: lib.de, en: lib.en, active: false });
  }

  function removeMedia(i: number) { draft.media.splice(i, 1); }

  function mediaLabel(m: { de: string; en: string }) {
    return $locale === 'de' ? m.de : (m.en || m.de);
  }
</script>

<div
  class="fixed inset-0 bg-black/65 z-50 flex items-center justify-center p-6"
  role="none"
  onclick={onClose}
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
      <h2 class="m-0 text-xl font-bold text-ink tracking-wide">{dialogTitle}</h2>
      <button class="bg-transparent border-none text-muted cursor-pointer text-lg px-3 py-2.5 min-w-[2.75rem] min-h-[2.75rem] flex items-center justify-center rounded hover:text-ink transition-colors leading-none" onclick={onClose} type="button">✕</button>
    </div>

    <div class="p-6 flex flex-col gap-6 flex-1">

      <div class="grid grid-cols-2 gap-4">
        <div class="flex flex-col gap-2">
          <label class="text-xs font-bold uppercase tracking-widest text-muted" for="machine-number">{$t.machineNumber}</label>
          <div class="relative flex items-center">
            <input
              id="machine-number"
              class="w-full bg-overlay border border-stroke rounded-lg px-4 py-3 text-ink text-lg font-semibold transition-colors focus:border-highlight focus:outline-none placeholder:text-dim pr-10"
              type="text"
              bind:value={draft.number}
              placeholder="{$t.machineNumber}…"
              onfocus={() => showOSK(draft.number, $t.machineNumber, (v) => (draft.number = v))}
              oninput={(e) => syncOSKValue((e.currentTarget as HTMLInputElement).value)}
              onkeydown={onOSKKeydown}
              autocomplete="off"
              spellcheck={false}
            />
            <span class="absolute right-3 text-dim text-xl pointer-events-none">⌨</span>
          </div>
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-xs font-bold uppercase tracking-widest text-muted" for="responsible">{$t.responsible}</label>
          <div class="relative flex items-center">
            <input
              id="responsible"
              class="w-full bg-overlay border border-stroke rounded-lg px-4 py-3 text-ink text-lg font-semibold transition-colors focus:border-highlight focus:outline-none placeholder:text-dim pr-10"
              type="text"
              bind:value={draft.responsible}
              placeholder="{$t.responsible}…"
              onfocus={() => showOSK(draft.responsible, $t.responsible, (v) => (draft.responsible = v))}
              oninput={(e) => syncOSKValue((e.currentTarget as HTMLInputElement).value)}
              onkeydown={onOSKKeydown}
              autocomplete="off"
              spellcheck={false}
            />
            <span class="absolute right-3 text-dim text-xl pointer-events-none">⌨</span>
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-2">
        <span class="text-xs font-bold uppercase tracking-widest text-muted">{$t.phase}</span>
        <div class="flex flex-wrap gap-2">
          {#each phases as phase}
            <button
              class="border rounded px-4 py-3 text-sm font-semibold cursor-pointer transition-colors whitespace-nowrap
                {draft.phase === phase ? phaseSelectedClass[phase] : defaultOptionClass}"
              onclick={() => { draft.phase = phase; if (phase === 'FAT') draft.safety.emergencyStop = 'OK'; }}
              type="button"
            >
              {$t.phases[phase] ?? phase}
            </button>
          {/each}
        </div>
      </div>

      <div class="flex flex-col gap-3">
        <span class="text-xs font-bold uppercase tracking-widest text-muted">{$t.media}</span>

        {#if draft.media.length > 0}
          <div class="flex flex-wrap gap-2">
            {#each draft.media as item, i}
              <div class="flex items-center gap-0 rounded border overflow-hidden {item.active ? 'border-ok/50' : 'border-stroke'}">
                <button
                  class="flex items-center gap-2 px-4 py-2.5 text-sm font-semibold cursor-pointer transition-colors
                    {item.active ? 'bg-ok/10 text-ok hover:bg-ok/20' : 'bg-overlay text-muted hover:bg-stroke/20 hover:text-ink'}"
                  onclick={() => (draft.media[i].active = !draft.media[i].active)}
                  type="button"
                >
                  <span class="leading-none">{item.active ? '✓' : '✗'}</span>
                  {mediaLabel(item)}
                  {#if item.en && item.de !== item.en}
                    <span class="opacity-40 text-xs">/ {$locale === 'de' ? item.en : item.de}</span>
                  {/if}
                </button>
                <button
                  class="px-3 py-2.5 text-danger/50 hover:text-danger hover:bg-danger/10 transition-colors cursor-pointer bg-transparent border-none border-l border-stroke/50 text-base leading-none"
                  onclick={() => removeMedia(i)}
                  type="button"
                  aria-label="Remove"
                >✕</button>
              </div>
            {/each}
          </div>
        {/if}

        {#if availableFromLibrary.length > 0}
          <div class="flex flex-col gap-1.5">
            <span class="text-xs text-muted font-semibold">{$t.fromLibrary}</span>
            <div class="flex flex-wrap gap-2">
              {#each availableFromLibrary as lib}
                <button
                  class="flex items-center gap-1.5 border rounded px-3 py-2.5 text-xs font-semibold cursor-pointer transition-colors bg-overlay border-stroke text-muted hover:border-highlight hover:text-ink"
                  onclick={() => addFromLibrary(lib)}
                  type="button"
                >
                  <span class="text-ok">+</span>
                  {$locale === 'de' ? lib.de : (lib.en || lib.de)}
                </button>
              {/each}
            </div>
          </div>
        {/if}

      </div>

      <div class="flex flex-col gap-2">
        <span class="text-xs font-bold uppercase tracking-widest text-muted">{$t.emergencyStop}</span>
        <div class="flex flex-wrap gap-2">
          {#each eStopOptions as opt}
            <button
              class="border rounded px-4 py-3 text-sm font-semibold cursor-pointer transition-colors
                {draft.safety.emergencyStop === opt ? eStopSelectedClass[opt] : defaultOptionClass}"
              onclick={() => (draft.safety.emergencyStop = opt)}
              type="button"
            >
              {#if opt === 'OK'}<CircleCheck class="w-4 h-4 inline-block mr-1" />
              {:else if opt === 'Teilweise'}<TriangleAlert class="w-4 h-4 inline-block mr-1" />
              {:else}<OctagonAlert class="w-4 h-4 inline-block mr-1" />{/if}
              {$t.emergencyStopValues[opt] ?? opt}
            </button>
          {/each}
        </div>
      </div>

      <div class="flex flex-col gap-2">
        <label class="text-xs font-bold uppercase tracking-widest text-muted" for="note">{$t.note}</label>
        <div class="relative flex items-center">
          <input
            id="note"
            class="w-full bg-overlay border border-stroke rounded-lg px-4 py-3 text-ink text-sm font-medium transition-colors focus:border-highlight focus:outline-none placeholder:text-dim {draft.note ? 'pr-16' : 'pr-10'}"
            type="text"
            bind:value={draft.note}
            placeholder={$t.notePlaceholder}
            onfocus={() => showOSK(draft.note, $t.note, (v) => (draft.note = v))}
            oninput={(e) => syncOSKValue((e.currentTarget as HTMLInputElement).value)}
            onkeydown={onOSKKeydown}
            autocomplete="off"
            spellcheck={false}
          />
          {#if draft.note}
            <button
              class="absolute right-8 text-muted hover:text-danger transition-colors cursor-pointer bg-transparent border-none p-0.5 leading-none"
              onclick={() => { draft.note = ''; syncOSKValue(''); }}
              type="button"
              aria-label="Clear"
            ><X class="w-4 h-4" /></button>
          {/if}
          <span class="absolute right-3 text-dim text-xl pointer-events-none">⌨</span>
        </div>
      </div>

      <div class="flex flex-col gap-3">
        <span class="text-xs font-bold uppercase tracking-widest text-muted">{$t.workPermit}</span>

        <label class="flex items-center gap-3 cursor-pointer select-none">
          <input
            type="checkbox"
            class="w-5 h-5 rounded accent-orange-400 cursor-pointer"
            bind:checked={draft.workPermit}
            onchange={() => {
              if (draft.workPermit) draft.workPermitDate = new Date().toISOString();
            }}
          />
          <span class="text-sm font-semibold {draft.workPermit ? 'text-orange-300' : 'text-muted'}">
            {$t.workPermitWarning}
          </span>
        </label>

        {#if draft.workPermit}
          <div class="flex items-center gap-3 pl-8">
            <span class="text-xs text-muted font-semibold whitespace-nowrap">{$t.workPermitDays}</span>
            <input
              type="text"
              inputmode="numeric"
              pattern="[0-9]*"
              class="w-20 bg-overlay border border-stroke rounded-lg px-3 py-2 text-ink text-sm font-semibold text-center focus:border-highlight focus:outline-none"
              value={draft.workPermitDays}
              onfocus={() => showNumericOSK(String(draft.workPermitDays), $t.workPermitDays, (v) => {
                const n = parseInt(v, 10);
                draft.workPermitDays = (!isNaN(n) && n >= 0) ? n : 0;
              })}
              oninput={(e) => {
                const n = parseInt((e.currentTarget as HTMLInputElement).value, 10);
                if (!isNaN(n) && n >= 0) draft.workPermitDays = n;
                syncOSKValue((e.currentTarget as HTMLInputElement).value);
              }}
              onkeydown={onOSKKeydown}
              autocomplete="off"
            />
            <span class="text-xs text-muted">{$t.workPermitDaysUnit}</span>
          </div>

          <div class="flex items-center gap-3 pl-8">
            <span class="text-xs text-muted font-semibold whitespace-nowrap">{$t.workPermitRemainingLabel}</span>
            <span class="text-sm font-bold font-mono {draftRemaining === null ? 'text-muted' : draftRemaining <= 1 ? 'text-red-400' : 'text-orange-300'}">
              {draftRemaining === null
                ? $t.workPermitUnlimited
                : `${draftRemaining} ${$t.workPermitDaysLeft}`}
            </span>
            <button
              type="button"
              class="text-xs font-semibold px-3 py-2 rounded-lg border border-stroke text-muted hover:border-highlight hover:text-ink transition-colors bg-transparent cursor-pointer"
              onclick={resetWorkPermitTimer}
              title={$t.workPermitReset}
            >↺ {$t.workPermitReset}</button>
          </div>
        {/if}
      </div>

    </div>

    <div class="flex justify-between items-center px-6 pb-6 pt-4 border-t border-rim shrink-0 gap-3">
      {#if !isNew}
        <button
          class="px-5 py-3.5 rounded-lg text-sm font-bold cursor-pointer bg-danger/10 border border-danger/40 text-danger hover:bg-danger/20 hover:border-danger/70 transition-colors"
          onclick={() => onDelete(draft.id)}
          type="button"
        >{$t.deleteMachine}</button>
      {:else}
        <div></div>
      {/if}
      <div class="flex gap-2">
        <button
          class="px-5 py-3.5 rounded-lg text-sm font-bold cursor-pointer bg-transparent border border-stroke text-muted hover:border-highlight hover:text-ink transition-colors"
          onclick={onClose}
          type="button"
        >{$t.cancel}</button>
        <button
          class="px-5 py-3.5 rounded-lg text-sm font-bold cursor-pointer bg-ok/10 border border-ok/40 text-ok hover:bg-ok/20 hover:border-ok/70 transition-colors"
          onclick={() => onSave(draft)}
          type="button"
        >{$t.save}</button>
      </div>
    </div>
  </div>
</div>
