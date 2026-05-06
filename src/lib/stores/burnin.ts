import { writable } from 'svelte/store';

export const pixelShift = writable({ x: 0, y: 0 });

const SHIFT_INTERVAL_MS = 5 * 60 * 1000; // every 5 min

let shiftTimer: ReturnType<typeof setInterval> | null = null;

function randomShift(range: number) {
  return Math.round((Math.random() - 0.5) * 2 * range);
}

export function startBurnInProtection() {
  shiftTimer = setInterval(() => {
    pixelShift.set({ x: randomShift(4), y: randomShift(4) });
  }, SHIFT_INTERVAL_MS);
}

export function stopBurnInProtection() {
  if (shiftTimer) clearInterval(shiftTimer);
}
