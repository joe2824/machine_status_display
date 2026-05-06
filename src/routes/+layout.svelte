<script lang="ts">
  import '../app.css';

  let { children } = $props();

  let updateAvailable = $state(false);
  let updateVersion = $state('');
  let installing = $state(false);
  let dismissed = $state(false);

  async function checkForUpdates() {
    try {
      const { check } = await import('@tauri-apps/plugin-updater');
      const update = await check();
      if (update?.available) {
        updateAvailable = true;
        updateVersion = update.version;
      }
    } catch {
    }
  }

  async function installUpdate() {
    installing = true;
    try {
      const { check } = await import('@tauri-apps/plugin-updater');
      const { relaunch } = await import('@tauri-apps/plugin-process');
      const update = await check();
      if (update?.available) {
        await update.downloadAndInstall();
        await relaunch();
      }
    } catch {
      installing = false;
    }
  }

  if (typeof window !== 'undefined') {
    setTimeout(checkForUpdates, 5000);
  }
</script>

{#if updateAvailable && !dismissed}
  <div class="fixed bottom-4 right-4 z-50 flex items-center gap-3 rounded-lg bg-blue-600 px-4 py-3 text-white shadow-lg">
    <span class="text-sm font-medium">Update {updateVersion} verfügbar</span>
    <button
      onclick={installUpdate}
      disabled={installing}
      class="rounded bg-white px-3 py-1 text-sm font-semibold text-blue-600 hover:bg-blue-50 disabled:opacity-60"
    >
      {installing ? 'Installiert...' : 'Installieren'}
    </button>
    <button
      onclick={() => (dismissed = true)}
      disabled={installing}
      class="text-blue-200 hover:text-white disabled:opacity-60"
      aria-label="Schließen"
    >
      ✕
    </button>
  </div>
{/if}

{@render children()}
