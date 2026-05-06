import { invoke } from '@tauri-apps/api/core';
import { writable } from 'svelte/store';

export interface MediumItem {
  de: string;
  en: string;
  active: boolean;
}

export interface Safety {
  emergencyStop: 'OK' | 'Teilweise' | 'Ausgeloest';
}

export type Phase = 'Installation' | 'Commissioning' | 'Test run' | 'FAT';

export interface Machine {
  id: string;
  number: string;
  phase: Phase;
  media: MediumItem[];
  safety: Safety;
  note: string;
  workPermit: boolean;
  workPermitDays: number;
  workPermitDate: string;
  responsible: string;
  lastChanged: string;
}

export const machines = writable<Machine[]>([]);

export async function loadMachines(): Promise<void> {
  const data = await invoke<Machine[]>('get_machines');
  machines.set(data);
}

export async function saveMachine(machine: Machine): Promise<void> {
  await invoke('save_machine', { machine: { ...machine, lastChanged: new Date().toISOString() } });
  await loadMachines();
}

export async function deleteMachine(id: string): Promise<void> {
  await invoke('delete_machine', { id });
  await loadMachines();
}

export function createEmptyMachine(): Machine {
  return {
    id: crypto.randomUUID(),
    number: '',
    phase: 'Installation',
    media: [
      { de: 'Druckluft', en: 'Compressed Air', active: false },
      { de: 'Spannung',  en: 'Power',           active: false },
      { de: 'Stickstoff', en: 'Nitrogen',        active: false },
    ],
    safety: { emergencyStop: 'OK' },
    note: '',
    workPermit: false,
    workPermitDays: 3,
    workPermitDate: '',
    responsible: '',
    lastChanged: '',
  };
}
