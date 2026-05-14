import { invoke } from '@tauri-apps/api/core';
import { writable } from 'svelte/store';

export interface LibraryMedium {
  id: string;
  de: string;
  en: string;
}

export const mediaLibrary = writable<LibraryMedium[]>([]);

export const DEFAULT_LIBRARY: LibraryMedium[] = [
  { id: 'druckluft',  de: 'Druckluft',  en: 'Compressed Air' },
  { id: 'spannung',   de: 'Spannung',   en: 'Power'           },
  { id: 'stickstoff', de: 'Stickstoff', en: 'Nitrogen'        },
  { id: 'wasser',     de: 'Wasser',     en: 'Water'           },
  { id: 'dampf',      de: 'Dampf',      en: 'Steam'           },
  { id: 'kuehlwasser',de: 'Kühlwasser', en: 'Cooling Water'   },
  { id: 'hydraulik',  de: 'Hydraulik',  en: 'Hydraulics'      },
  { id: 'vakuum',      de: 'Vakuum',      en: 'Vacuum'    },
  { id: 'sauerstoff',  de: 'Sauerstoff',  en: 'Oxygen'    },
  { id: 'ozon',        de: 'Ozon',        en: 'Ozone'     },
  { id: 'heisswasser', de: 'Heißwasser',  en: 'Hot Water' },
];

export async function loadMediaLibrary(): Promise<void> {
  let data = await invoke<LibraryMedium[]>('get_media_library');
  const missing = DEFAULT_LIBRARY.filter((def) => !data.some((item) => item.id === def.id));
  if (missing.length > 0) {
    data = [...data, ...missing];
    await invoke('save_media_library', { library: data });
  }
  mediaLibrary.set(data);
}

export async function saveMediaLibrary(library: LibraryMedium[]): Promise<void> {
  await invoke('save_media_library', { library });
  mediaLibrary.set(library);
}
