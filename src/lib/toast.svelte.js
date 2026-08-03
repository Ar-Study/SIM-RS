export const toasts = $state([]);
let toastId = 0;

export function toast(message, type = 'success') {
  const id = ++toastId;
  toasts.push({ id, message, type });
  setTimeout(() => {
    const idx = toasts.findIndex((t) => t.id === id);
    if (idx !== -1) toasts.splice(idx, 1);
  }, 3500);
}
