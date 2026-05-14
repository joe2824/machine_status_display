<script lang="ts">
  let { de = '', en = '', class: cls = '' }: { de?: string; en?: string; class?: string } = $props();

  type IconKind = 'air' | 'power' | 'nitrogen' | 'water' | 'coolwater' | 'steam' | 'hydraulic' | 'vacuum' | 'oxygen' | 'ozone' | 'hotwater' | 'wrench';

  function classify(d: string, e: string): IconKind {
    const s = (d + ' ' + e).toLowerCase();
    // Most specific first to avoid prefix collisions
    if (s.includes('hydraul'))                                                        return 'hydraulic';
    if (s.includes('dampf')  || s.includes('steam') || s.includes('vapor'))          return 'steam';
    if (s.includes('vakuum') || s.includes('vacuum') || s.includes('vac'))           return 'vacuum';
    if (s.includes('druck')  || s.includes('luft')  || s.includes('air') ||
        s.includes('pneum')  || s.includes('compress'))                               return 'air';
    if (s.includes('span')   || s.includes('strom') || s.includes('power') ||
        s.includes('elec')   || s.includes('volt'))                                   return 'power';
    if (s.includes('stick')  || s.includes('nitro') || s.includes('n2') ||
        s.includes('n₂') || s.includes('inert'))                                 return 'nitrogen';
    if (s.includes('ozon') || s.includes('ozone') || s.includes('o₃'))          return 'ozone';
    if (s.includes('sauerstoff') || s.includes('oxygen') || s.includes(' o2') || s.includes('o₂'))
                                                                                      return 'oxygen';
    if (s.includes('hei\xdf')   || s.includes('heiss') || s.includes('hot water'))   return 'hotwater';
    if (s.includes('k\xfchl')   || s.includes('cool'))                               return 'coolwater';
    if (s.includes('wass')   || s.includes('water'))                                  return 'water';
    return 'wrench';
  }

  let kind = $derived(classify(de, en));
</script>

<svg
  class={cls}
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width="1.5"
  stroke-linecap="round"
  stroke-linejoin="round"
  aria-hidden="true"
>
  {#if kind === 'air'}
    <!-- Manometer — DIN 2403, centered (12,12) r=9, y=3–21 -->
    <circle cx="12" cy="12" r="9" />
    <path d="M3.5 12h2M12 3.5v2M20.5 12h-2" stroke-linecap="round" />
    <path d="M12 12l-3.5-5" stroke-width="2" stroke-linecap="round" />
    <circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none" />

  {:else if kind === 'power'}
    <!-- ISO 7010 W012 — Electrical hazard: equilateral triangle + lightning, y=3–22 -->
    <path d="M12 3L2 22h20z" stroke-linejoin="round" />
    <path d="M13 10l-2.5 5h3l-2.5 4" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" />

  {:else if kind === 'nitrogen'}
    <!-- ISO W026 — Pressurised gas: N2 cylinder x=6.5–17.5, y=2.5–21 -->
    <path d="M8 2.5h8" stroke-linecap="round" />
    <line x1="12" y1="2.5" x2="12" y2="5" />
    <rect x="10" y="5" width="4" height="2" rx="1" />
    <rect x="6.5" y="7" width="11" height="14" rx="3" />
    <line x1="10" y1="11" x2="10" y2="15" />
    <line x1="14" y1="11" x2="14" y2="15" />
    <line x1="10" y1="11" x2="14" y2="15" />

  {:else if kind === 'water'}
    <!-- Water droplet — classic Lucide shape -->
    <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" />

  {:else if kind === 'coolwater'}
    <!-- Snowflake — DIN 2403 cooling, y=2–22 full fill -->
    <line x1="12" y1="2" x2="12" y2="22" />
    <line x1="2" y1="12" x2="22" y2="12" />
    <line x1="4.93" y1="4.93" x2="19.07" y2="19.07" />
    <line x1="19.07" y1="4.93" x2="4.93" y2="19.07" />
    <path d="m9 3 3 2 3-2M9 21l3-2 3 2M3 9l2 3-2 3M21 9l-2 3 2 3" />

  {:else if kind === 'steam'}
    <!-- Steam wisps — DIN 2403, 3 S-curves y=3–21 -->
    <path d="M7 21Q5 18 7 15Q9 12 7 9Q5 6 7 3" stroke-linecap="round" />
    <path d="M12 21Q14 18 12 15Q10 12 12 9Q14 6 12 3" stroke-linecap="round" />
    <path d="M17 21Q15 18 17 15Q19 12 17 9Q15 6 17 3" stroke-linecap="round" />

  {:else if kind === 'hydraulic'}
    <!-- ISO 1219 hydraulic cylinder: closed end + body + piston + rod + ports -->
    <path d="M2 9v6" stroke-width="3" stroke-linecap="round" />
    <rect x="2" y="9" width="15" height="6" rx="1" />
    <line x1="10" y1="9" x2="10" y2="15" />
    <path d="M17 12h5" stroke-width="2.5" stroke-linecap="round" />
    <path d="M6 6v3M13 6v3" stroke-linecap="round" />
    <path d="M6 15v3M13 15v3" stroke-linecap="round" />

  {:else if kind === 'vacuum'}
    <!-- Vacuum gauge — needle at empty/zero, centered (12,12) r=9 -->
    <circle cx="12" cy="12" r="9" />
    <path d="M7.5 16.5a7 7 0 0 1 9-9" stroke-linecap="round" />
    <path d="M12 12l-3.5-4" stroke-linecap="round" />
    <circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none" />

  {:else if kind === 'oxygen'}
    <!-- ISO 7010 W009 — Oxidising material: flame above circle, y=3–21 -->
    <path d="M12 3c-1 2.5-3.5 4.5-3.5 7a3.5 3.5 0 0 0 7 0c0-2-1-3.5-2-5.5 0 1.5-.5 2.5-1.5 2.5z" fill="currentColor" stroke="none" />
    <circle cx="12" cy="17.5" r="4" />

  {:else if kind === 'ozone'}
    <!-- ISO W009 O₃ variant: double flame (stronger oxidizer than O₂) + circle -->
    <path d="M9 3c-1 2-2.5 3-2.5 5a2.5 2.5 0 0 0 5 0c0-1.5-.8-2.5-1.5-4 0 1-.5 1.5-1 1.5z" fill="currentColor" stroke="none" />
    <path d="M15 3c-1 2-2.5 3-2.5 5a2.5 2.5 0 0 0 5 0c0-1.5-.8-2.5-1.5-4 0 1-.5 1.5-1 1.5z" fill="currentColor" stroke="none" />
    <circle cx="12" cy="17.5" r="4" />

  {:else if kind === 'hotwater'}
    <!-- Heißoberfläche (ISO W017 inspired): hot surface line + heat waves -->
    <line x1="2" y1="21" x2="22" y2="21" stroke-width="2.5" stroke-linecap="round" />
    <path d="M6 17Q4.5 14 6 11Q7.5 8 6 5" stroke-linecap="round" />
    <path d="M12 17Q10.5 14 12 11Q13.5 8 12 5" stroke-linecap="round" />
    <path d="M18 17Q16.5 14 18 11Q19.5 8 18 5" stroke-linecap="round" />

  {:else}
    <!-- Wrench — generic utility -->
    <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" />
  {/if}
</svg>
