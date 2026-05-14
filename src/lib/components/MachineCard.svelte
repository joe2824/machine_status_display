<script lang="ts">
  import { onMount } from 'svelte';
  import type { Machine } from '$lib/stores/machines';
  import { t, locale } from '$lib/i18n';
  import MediaIcon from './MediaIcon.svelte';
  import { TriangleAlert, Info, CircleCheck, OctagonAlert, Megaphone, UserRound, Clock } from 'lucide-svelte';

  let { machine }: { machine: Machine } = $props();

  // Ticks every 60 s — forces $derived(formattedDate) to recalculate
  let tick = $state(0);
  onMount(() => {
    const id = setInterval(() => { tick++; }, 60_000);
    return () => clearInterval(id);
  });

  const phaseBadgeClass: Record<string, string> = {
    Installation: 'text-blue-400 bg-blue-400/10 border-blue-400/30',
    Commissioning: 'text-amber-400 bg-amber-400/10 border-amber-400/30',
    'Test run':    'text-orange-400 bg-orange-400/10 border-orange-400/30',
    FAT:           'text-green-400 bg-green-400/10 border-green-400/30',
  };

  const eStopBarClass: Record<string, string> = {
    OK:         'bg-ok/15 border-ok/60 text-ok',
    Teilweise:  'bg-partial/15 border-partial/60 text-partial',
    Ausgeloest: 'bg-danger/25 border-danger text-danger',
  };

  let phaseClass  = $derived(phaseBadgeClass[machine.phase] ?? 'text-zinc-400 bg-zinc-400/10 border-zinc-400/30');
  let phaseLabel  = $derived($t.phases[machine.phase] ?? machine.phase);
  let eStopClass  = $derived(eStopBarClass[machine.safety.emergencyStop] ?? 'bg-stroke/30 border-stroke text-ink');
  let eStopLabel  = $derived($t.emergencyStopValues[machine.safety.emergencyStop] ?? machine.safety.emergencyStop);
  let isDanger    = $derived(machine.safety.emergencyStop === 'Ausgeloest');

  let powerActive = $derived(
    machine.media.some((m) => {
      const s = (m.de + ' ' + m.en).toLowerCase();
      return m.active && (s.includes('span') || s.includes('strom') || s.includes('power') || s.includes('elec') || s.includes('volt'));
    })
  );

  function activeMediumClass(de: string, en: string): string {
    const s = (de + ' ' + en).toLowerCase();
    // DIN 2403 pipeline identification colors
    if (s.includes('hydraul'))
      return 'bg-amber-500/20 border-amber-500 text-amber-400';       // RAL 1003 Signalgelb
    if (s.includes('dampf') || s.includes('steam') || s.includes('vapor'))
      return 'bg-slate-400/20 border-slate-400 text-slate-300';        // RAL 9006 Weißaluminium
    if (s.includes('vakuum') || s.includes('vacuum'))
      return 'bg-violet-500/20 border-violet-500 text-violet-400';     // technical process
    if (s.includes('druck') || s.includes('luft') || s.includes('air') || s.includes('pneum') || s.includes('compress'))
      return 'bg-sky-500/20 border-sky-500 text-sky-400';              // RAL 5015 Himmelblau
    if (s.includes('span') || s.includes('strom') || s.includes('power') || s.includes('elec') || s.includes('volt'))
      return 'bg-yellow-400/20 border-yellow-400 text-yellow-300';     // ISO 7010 W012 — electrical warning
    if (s.includes('stick') || s.includes('nitro') || s.includes('n2') || s.includes('n₂') || s.includes('inert'))
      return 'bg-gray-500/20 border-gray-500 text-gray-400';           // RAL 9005 Tiefschwarz (adapted)
    if (s.includes('ozon') || s.includes('ozone') || s.includes('o₃'))
      return 'bg-purple-500/20 border-purple-500 text-purple-400';     // oxidizer — distinct from O2
    if (s.includes('sauerstoff') || s.includes('oxygen') || s.includes(' o2') || s.includes('o₂'))
      return 'bg-red-500/20 border-red-500 text-red-400';              // RAL 3000 Feuerrot
    if (s.includes('heiß') || s.includes('heiss') || s.includes('hot water'))
      return 'bg-orange-500/20 border-orange-500 text-orange-400';     // RAL 3001 Signalrot
    if (s.includes('kühl') || s.includes('cool'))
      return 'bg-blue-500/20 border-blue-500 text-blue-400';           // RAL 5019 Capriblau
    if (s.includes('wass') || s.includes('water'))
      return 'bg-green-500/20 border-green-500 text-green-400';        // RAL 6018 Gelbgrün
    return 'bg-teal-500/20 border-teal-500 text-teal-400';
  }

  let workPermitActive = $derived(
    tick >= 0 &&
    machine.workPermit && (
      machine.workPermitDays === 0 ||
      !machine.workPermitDate ||
      (Date.now() - new Date(machine.workPermitDate).getTime()) / 86_400_000 < machine.workPermitDays
    )
  );


  let activeMedia    = $derived(machine.media.filter((m) => m.active));
  let mediaLabel     = (m: { de: string; en: string }) => $locale === 'de' ? m.de : (m.en || m.de);
  function relativeTime(iso: string, lang: string, _tick: number): string {
    if (!iso) return '';
    const diff = Date.now() - new Date(iso).getTime();
    const sec  = Math.floor(diff / 1000);
    const min  = Math.floor(sec / 60);
    const h    = Math.floor(min / 60);
    const d    = Math.floor(h / 24);
    const mo   = Math.floor(d / 30);
    const y    = Math.floor(d / 365);
    const rtf  = new Intl.RelativeTimeFormat(lang, { numeric: 'auto' });
    if (sec  < 60)  return rtf.format(-sec,  'second');
    if (min  < 60)  return rtf.format(-min,  'minute');
    if (h    < 24)  return rtf.format(-h,    'hour');
    if (d    < 30)  return rtf.format(-d,    'day');
    if (mo   < 12)  return rtf.format(-mo,   'month');
    return rtf.format(-y, 'year');
  }

  let formattedDate = $derived(relativeTime(machine.lastChanged, $locale === 'de' ? 'de' : 'en', tick));
</script>

<div class="cq-size flex flex-col w-full h-full bg-card border border-rim rounded-xl overflow-hidden">
  <div class="flex flex-col h-full p-cq gap-cq justify-between">

    <div class="flex flex-col gap-cq">

      <div class="flex items-center space-x-5">
        <span class="text-cq-badge font-bold uppercase tracking-wide border rounded-[0.3em] px-[0.65em] py-[0.2em] shrink-0 {phaseClass}">
          {phaseLabel}
        </span>
        <div class="flex flex-col space-y-1 items-start">
          {#if machine.responsible}
            <span class="flex gap-[0.25em] items-center text-cq-meta text-muted font-semibold">
              <UserRound class="size-cq-meta shrink-0" />
              {machine.responsible}
            </span>
          {/if}
          {#if formattedDate}
            <span class="flex gap-[0.25em] items-center text-cq-meta text-dim">
              <Clock class="size-cq-meta shrink-0" />
              {formattedDate}
            </span>
          {/if}
        </div>
      </div>

      <div class="overflow-hidden">
        <span class="text-cq-nummer font-black tracking-tight text-ink overflow-hidden text-ellipsis whitespace-nowrap block">
          {machine.number || '—'}
        </span>
      </div>

      {#if workPermitActive}
        <div class="flex items-center gap-[0.4em] text-cq-status bg-orange-400/15 border border-orange-400/50 text-orange-300 font-bold rounded-lg p-cq-nh">
          <Megaphone class="size-cq-status shrink-0" />
          <span class="leading-tight">{$t.workPermitWarning}</span>
        </div>
      {/if}

      {#if machine.note}
        <div class="flex items-center gap-[0.4em] text-cq-status bg-ink/5 border border-stroke text-muted font-medium rounded-lg px-[0.6em] py-[0.35em]">
          <Info class="size-cq-status shrink-0 opacity-60" />
          <span class="leading-tight wrap-break-word">{machine.note}</span>
        </div>
      {/if}
    </div>

    <div class="flex flex-col gap-cq">
      {#if activeMedia.length > 0}
        <div class="flex flex-wrap gap-cq-tiles">
          {#each activeMedia as item}
            <div class="flex-1 flex flex-col items-center justify-between p-cq-tile rounded-lg border-2 transition-colors {activeMediumClass(item.de, item.en)}">
              <MediaIcon de={item.de} en={item.en} class="size-cq-tile-icon" />
              <span class="text-cq-tile-label font-bold uppercase tracking-wide text-center leading-tight mt-[0.3em]">
                {mediaLabel(item)}
              </span>
            </div>
          {/each}
        </div>
      {/if}

      {#if powerActive}
        <div
          class="flex items-center gap-cq-nh p-cq-nh rounded-lg border-2 font-black uppercase tracking-wider {eStopClass}"
          class:animate-achtung={isDanger}
        >
          <span class="shrink-0">
            {#if machine.safety.emergencyStop === 'OK'}
              <CircleCheck class="size-cq-nh" />
            {:else if machine.safety.emergencyStop === 'Teilweise'}
              <TriangleAlert class="size-cq-nh" />
            {:else}
              <OctagonAlert class="size-cq-nh" />
            {/if}
          </span>
          <div class="flex flex-col min-w-0">
            <span class="text-cq-tile-label font-semibold opacity-60 tracking-widest">{$t.emergencyStop}</span>
            <span class="text-cq-nh leading-tight">{eStopLabel}</span>
          </div>
        </div>
      {/if}
    </div>
  </div>
</div>
