<script>
  import { toasts } from '$lib/toast.svelte.js';
</script>

{#if toasts.length > 0}
  <div class="fixed top-4 right-4 z-[100] w-80 space-y-2">
    {#each toasts as t (t.id)}
      <div
        class="flex items-start gap-3 rounded-lg shadow-lg border bg-white px-4 py-3
          {t.type === 'error'
            ? 'border-red-200'
            : t.type === 'warning'
              ? 'border-amber-200'
              : 'border-emerald-200'}"
      >
        <div class="shrink-0">
          {#if t.type === 'error'}
            <svg class="w-5 h-5 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
            </svg>
          {:else if t.type === 'warning'}
            <svg class="w-5 h-5 text-amber-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
            </svg>
          {:else}
            <svg class="w-5 h-5 text-emerald-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
            </svg>
          {/if}
        </div>
        <p class="text-sm font-medium text-gray-800 leading-snug">{t.message}</p>
      </div>
    {/each}
  </div>
{/if}
