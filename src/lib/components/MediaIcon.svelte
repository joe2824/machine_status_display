<script lang="ts">
  let { de = '', en = '', class: cls = '' }: { de?: string; en?: string; class?: string } = $props();

  type IconKind = 'air' | 'power' | 'nitrogen' | 'water' | 'coolwater' | 'steam' | 'hydraulic' | 'vacuum' | 'oxygen' | 'hotwater' | 'wrench';

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
        s.includes('n₂')     || s.includes('inert'))                                  return 'nitrogen';
    if (s.includes('sauerstoff') || s.includes('oxygen') || s.includes(' o2') || s.includes('o₂'))
                                                                                      return 'oxygen';
    if (s.includes('heiß')   || s.includes('heiss') || s.includes('hot water'))      return 'hotwater';
    if (s.includes('kühl')   || s.includes('cool'))                                   return 'coolwater';
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
    <!-- Wind / compressed air -->
    <path d="M17.7 7.7a2.5 2.5 0 1 1 1.8 4.3H2" />
    <path d="M9.6 4.6A2 2 0 1 1 11 8H2" />
    <path d="M12.6 19.4A2 2 0 1 0 14 16H2" />

  {:else if kind === 'power'}
    <!-- Lightning bolt / zap -->
    <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" fill="currentColor" stroke="none" />

  {:else if kind === 'nitrogen'}
    <!-- Hochdruckflasche N₂ — T-valve + cylinder -->
    <path d="M8.5 2.5h7" stroke-linecap="round" />
    <line x1="12" y1="2.5" x2="12" y2="5" />
    <rect x="10" y="5" width="4" height="2" rx="1" />
    <rect x="7" y="7" width="10" height="14" rx="2.5" />
    <!-- N label -->
    <line x1="10" y1="11" x2="10" y2="15" />
    <line x1="14" y1="11" x2="14" y2="15" />
    <line x1="10" y1="11" x2="14" y2="15" />

  {:else if kind === 'water'}
    <!-- Water droplet -->
    <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" />

  {:else if kind === 'coolwater'}
    <!-- Snowflake — Kühlwasser -->
    <line x1="12" y1="2" x2="12" y2="22" />
    <line x1="2" y1="12" x2="22" y2="12" />
    <line x1="4.93" y1="4.93" x2="19.07" y2="19.07" />
    <line x1="19.07" y1="4.93" x2="4.93" y2="19.07" />
    <path d="m9 3 3 2 3-2M9 21l3-2 3 2M3 9l2 3-2 3M21 9l-2 3 2 3" />

  {:else if kind === 'steam'}
    <!-- Steam: 3 S-curve wisps rising (quadratic bezier) -->
    <path d="M7 21Q5 18 7 15Q9 12 7 9Q5 6 7 3" stroke-linecap="round" />
    <path d="M12 21Q14 18 12 15Q10 12 12 9Q14 6 12 3" stroke-linecap="round" />
    <path d="M17 21Q15 18 17 15Q19 12 17 9Q15 6 17 3" stroke-linecap="round" />

  {:else if kind === 'hydraulic'}
    <!-- Hydraulic cylinder with rod -->
    <rect x="4" y="9" width="16" height="6" rx="1.5" />
    <path d="M12 2v7" />
    <path d="M12 15v7" />
    <path d="M2 12h2M20 12h2" />

  {:else if kind === 'vacuum'}
    <!-- Vakuum: pressure gauge at zero / needle on empty -->
    <circle cx="12" cy="12" r="9" />
    <path d="M7.5 16.5a7 7 0 0 1 9-9" stroke-linecap="round" />
    <path d="M12 12l-3.5-4" stroke-linecap="round" />
    <circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none" />

  {:else if kind === 'oxygen'}
    <!-- Hochdruckflasche O₂ — T-valve + cylinder + O ring -->
    <path d="M8.5 2.5h7" stroke-linecap="round" />
    <line x1="12" y1="2.5" x2="12" y2="5" />
    <rect x="10" y="5" width="4" height="2" rx="1" />
    <rect x="7" y="7" width="10" height="14" rx="2.5" />
    <!-- O label -->
    <circle cx="12" cy="13" r="2.5" />

  {:else if kind === 'hotwater'}
    <!-- Heißwasser: drop + heat wisps (all within viewbox) -->
    <path d="M12 4.5l4.5 4.5a6.5 6.5 0 1 1-9 0l4.5-4.5z" />
    <path d="M18 6c.8-1.2.8-2.5 0-3.5" stroke-linecap="round" />
    <path d="M20.5 7.5c.8-1.2.8-2.5 0-3.5" stroke-linecap="round" />

  {:else}
    <!-- Wrench — generic utility -->
    <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" />
  {/if}
</svg>
