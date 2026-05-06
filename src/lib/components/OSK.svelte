<script lang="ts">
  import { oskState, hideOSK, commitOSK } from '$lib/stores/osk';
  import { locale } from '$lib/i18n';

  let shifted = $state(true);

  const qwertzRows = [
    ['1','2','3','4','5','6','7','8','9','0','-'],
    ['q','w','e','r','t','z','u','i','o','p','ü'],
    ['a','s','d','f','g','h','j','k','l','ö','ä'],
    ['y','x','c','v','b','n','m',',','.','ß'],
  ];

  const qwertyRows = [
    ['1','2','3','4','5','6','7','8','9','0','-'],
    ['q','w','e','r','t','y','u','i','o','p'],
    ['a','s','d','f','g','h','j','k','l'],
    ['z','x','c','v','b','n','m',',','.'],
  ];

  let rows = $derived($locale === 'de' ? qwertzRows : qwertyRows);

  function pressKey(key: string) {
    oskState.update((s) => {
      const newVal = s.value + (shifted ? key.toUpperCase() : key);
      s.callback?.(newVal);
      return { ...s, value: newVal };
    });
  }

  function pressBackspace() {
    oskState.update((s) => {
      const newVal = s.value.slice(0, -1);
      s.callback?.(newVal);
      return { ...s, value: newVal };
    });
  }

  function pressClear() {
    oskState.update((s) => {
      s.callback?.('');
      return { ...s, value: '' };
    });
  }

  function pressSpace() {
    oskState.update((s) => {
      const newVal = s.value + ' ';
      s.callback?.(newVal);
      return { ...s, value: newVal };
    });
  }
</script>

{#if $oskState.visible}
  <div
    class="fixed inset-0 bg-black/50 z-100 flex items-end"
    role="none"
    onclick={hideOSK}
  >
    <div
      class="w-full bg-overlay border-t border-stroke osk-pad osk-gap flex flex-col shadow-[0_-8px_32px_rgba(0,0,0,0.6)]"
      role="none"
      onclick={(e) => e.stopPropagation()}
      onmousedown={(e) => e.preventDefault()}
    >
      <div class="flex items-center px-2 gap-3 bg-card border border-stroke rounded-lg osk-preview-pad osk-preview-min-h">
        <span class="osk-preview-label text-muted font-semibold whitespace-nowrap shrink-0">
          {$oskState.label}
        </span>
        <span class="flex-1 osk-preview-text text-ink font-semibold tracking-wide overflow-hidden text-ellipsis whitespace-nowrap">
          {$oskState.value || '​'}
        </span>
        <button
          class="bg-transparent border-none text-muted cursor-pointer rounded px-1 hover:text-danger transition-colors leading-none shrink-0"
          onclick={pressClear}
          type="button"
        >✕</button>
      </div>

      {#if $oskState.mode === 'numeric'}
        <!-- Numpad layout -->
        <div class="flex justify-center">
          <div class="grid grid-cols-3 osk-row-gap" style="width: fit-content;">
            {#each ['7','8','9','4','5','6','1','2','3'] as digit}
              <button
                class="osk-text osk-key-pad osk-numpad-min-w bg-key/10 border border-b-[3px] border-key/20 border-b-key/10 rounded text-key font-bold cursor-pointer leading-none text-center hover:bg-key/20 active:translate-y-px active:border-b transition-[background,transform] duration-75"
                onclick={() => pressKey(digit)}
                type="button"
              >{digit}</button>
            {/each}
            <button
              class="osk-text osk-key-pad osk-numpad-min-w bg-danger/10 border border-b-[3px] border-danger/20 border-b-danger/10 rounded text-danger font-semibold cursor-pointer leading-none text-center hover:bg-danger/20 active:translate-y-px active:border-b transition-[background,transform] duration-75"
              onclick={pressBackspace}
              type="button"
            >⌫</button>
            <button
              class="osk-text osk-key-pad osk-numpad-min-w bg-key/10 border border-b-[3px] border-key/20 border-b-key/10 rounded text-key font-bold cursor-pointer leading-none text-center hover:bg-key/20 active:translate-y-px active:border-b transition-[background,transform] duration-75"
              onclick={() => pressKey('0')}
              type="button"
            >0</button>
            <button
              class="osk-text osk-key-pad osk-numpad-min-w bg-ok/10 border border-ok/30 rounded text-ok font-bold cursor-pointer leading-none text-center hover:bg-ok/20 transition-colors"
              onclick={commitOSK}
              type="button"
            >↵</button>
          </div>
        </div>
      {:else}
        <!-- QWERTZ / QWERTY rows -->
        {#each rows as row, rowIdx}
          <div class="flex justify-center osk-row-gap">
            {#if rowIdx === 3}
              <button
                class="osk-text osk-key-pad osk-shift-min-w border rounded font-semibold cursor-pointer leading-none text-center transition-colors
                  {shifted ? 'bg-accent/20 border-accent/50 text-accent' : 'bg-key/10 border-key/20 text-muted hover:bg-key/20'}"
                onclick={() => (shifted = !shifted)}
                type="button"
              >⇧</button>
            {/if}

            {#each row as key}
              <button
                class="osk-text osk-key-pad osk-key-min-w bg-key/10 border border-b-[3px] border-key/20 border-b-key/10 rounded text-key font-semibold cursor-pointer leading-none text-center hover:bg-key/20 active:translate-y-px active:border-b transition-[background,transform] duration-75"
                onclick={() => pressKey(key)}
                type="button"
              >
                {shifted ? key.toUpperCase() : key}
              </button>
            {/each}

            {#if rowIdx === 0}
              <button
                class="osk-text osk-key-pad osk-bs-min-w bg-danger/10 border border-b-[3px] border-danger/20 border-b-danger/10 rounded text-danger font-semibold cursor-pointer leading-none text-center hover:bg-danger/20 active:translate-y-px active:border-b transition-[background,transform] duration-75"
                onclick={pressBackspace}
                type="button"
              >⌫</button>
            {/if}

            {#if rowIdx === 3}
              <button
                class="osk-text osk-key-pad osk-shift-min-w border rounded font-semibold cursor-pointer leading-none text-center transition-colors
                  {shifted ? 'bg-accent/20 border-accent/50 text-accent' : 'bg-key/10 border-key/20 text-muted hover:bg-key/20'}"
                onclick={() => (shifted = !shifted)}
                type="button"
              >⇧</button>
            {/if}
          </div>
        {/each}

        <div class="flex justify-center osk-row-gap mt-1">
          <button
            class="osk-text osk-key-pad osk-shift-min-w bg-danger/10 border border-danger/30 rounded text-danger font-bold cursor-pointer leading-none text-center hover:bg-danger/20 transition-colors"
            onclick={hideOSK}
            type="button"
          >✕</button>
          <button
            class="osk-text osk-key-pad flex-1 max-w-100 bg-key/10 border border-key/20 rounded text-muted font-semibold cursor-pointer leading-none text-center hover:bg-key/20 active:translate-y-px transition-[background,transform] duration-75"
            onclick={pressSpace}
            type="button"
          >Space</button>
          <button
            class="osk-text osk-key-pad osk-enter-min-w bg-ok/10 border border-ok/30 rounded text-ok font-bold cursor-pointer leading-none text-center hover:bg-ok/20 transition-colors"
            onclick={() => { commitOSK(); shifted = false; }}
            type="button"
          >↵ OK</button>
        </div>
      {/if}
    </div>
  </div>
{/if}
