import { writable } from 'svelte/store';

export interface OskState {
  visible: boolean;
  value: string;
  label: string;
  mode: 'text' | 'numeric';
  callback: ((val: string) => void) | null;
}

const initial: OskState = { visible: false, value: '', label: '', mode: 'text', callback: null };

export const oskState = writable<OskState>(initial);

export function showOSK(value: string, label: string, callback: (val: string) => void): void {
  oskState.set({ visible: true, value, label, mode: 'text', callback });
}

export function showNumericOSK(value: string, label: string, callback: (val: string) => void): void {
  oskState.set({ visible: true, value, label, mode: 'numeric', callback });
}

function blurActive(): void {
  if (typeof document !== 'undefined') {
    (document.activeElement as HTMLElement | null)?.blur();
  }
}

export function hideOSK(): void {
  oskState.update((s) => ({ ...s, visible: false, callback: null }));
  blurActive();
}

/** Close OSK — value already live via per-key callbacks */
export function commitOSK(): void {
  oskState.update((s) => ({ ...s, visible: false, callback: null }));
  blurActive();
}

/** Sync value from external source (e.g. physical keyboard input) */
export function syncOSKValue(val: string): void {
  oskState.update((s) => (s.visible ? { ...s, value: val } : s));
}
