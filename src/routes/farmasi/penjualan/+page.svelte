<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { formatCurrency, formatDate, generateId } from '$lib/utils/helpers.js';
  import { DRUG_CATEGORIES } from '$lib/utils/constants.js';

  let loading = $state(true);
  let saving = $state(false);
  let activeView = $state('new');

  let drugs = $state([]);
  let sales = $state([]);

  let buyerName = $state('');
  let buyerPhone = $state('');
  let paymentMethod = $state('cash');
  let cart = $state([]);
  let drugSearch = $state('');
  let drugResults = $state([]);
  let categoryFilter = $state('');
  let notes = $state('');

  const cartTotal = $derived(
    cart.reduce((sum, item) => sum + (item.sell_price * item.qty), 0)
  );

  const filteredDrugs = $derived.by(() => {
    let result = drugs.filter(d => d.stock > 0);
    if (categoryFilter) {
      result = result.filter(d => d.category === categoryFilter);
    }
    if (drugSearch.trim()) {
      const q = drugSearch.toLowerCase();
      result = result.filter(d =>
        d.name.toLowerCase().includes(q) ||
        d.code.toLowerCase().includes(q)
      );
    }
    return result;
  });

  function addToCart(drug) {
    const existing = cart.find(c => c.drug_id === drug.drug_id);
    if (existing) {
      if (existing.qty < drug.stock) {
        cart = cart.map(c =>
          c.drug_id === drug.drug_id ? { ...c, qty: c.qty + 1 } : c
        );
      }
    } else {
      cart = [...cart, {
        drug_id: drug.drug_id,
        name: drug.name,
        code: drug.code,
        unit: drug.unit,
        sell_price: drug.sell_price,
        qty: 1,
        max_stock: drug.stock
      }];
    }
    drugSearch = '';
    drugResults = [];
  }

  function updateCartQty(drugId, qty) {
    const newQty = Math.max(1, Number(qty));
    cart = cart.map(c =>
      c.drug_id === drugId ? { ...c, qty: Math.min(newQty, c.max_stock) } : c
    );
  }

  function removeFromCart(drugId) {
    cart = cart.filter(c => c.drug_id !== drugId);
  }

  async function searchDrugs() {
    if (drugSearch.length < 2) { drugResults = []; return; }
    try {
      const { data, error } = await supabase
        .from('drugs')
        .select('drug_id, code, name, unit, category, sell_price, stock')
        .ilike('name', `%${drugSearch}%`)
        .eq('is_active', true)
        .gt('stock', 0)
        .limit(10);

      if (error) throw error;
      drugResults = data || [];
    } catch (err) {
      console.error('Search drugs error:', err);
    }
  }

  async function fetchDrugs() {
    try {
      const { data, error } = await supabase
        .from('drugs')
        .select('*')
        .eq('is_active', true)
        .order('name');
      if (error) throw error;
      drugs = data || [];
    } catch (err) {
      console.error('Fetch drugs error:', err);
    }
  }

  async function fetchSales() {
    try {
      const { data, error } = await supabase
        .from('free_drug_sales')
        .select('*')
        .order('sale_date', { ascending: false })
        .limit(50);
      if (error) throw error;
      sales = (data || []).map(s => ({
        ...s,
        sale_id: 'FS-' + String(s.id),
        created_at: s.sale_date,
        total: s.net_amount
      }));
    } catch (err) {
      console.error('Fetch sales error:', err);
    }
  }

  async function processSale() {
    if (cart.length === 0 || !buyerName.trim() || saving) return;
    saving = true;

    try {
      const { data: saleData, error: saleError } = await supabase
        .from('free_drug_sales')
        .insert({
          buyer_name: buyerName,
          buyer_phone: buyerPhone,
          payment_method: paymentMethod,
          total_amount: cartTotal,
          net_amount: cartTotal
        })
        .select()
        .single();

      if (saleError) throw saleError;

      for (const item of cart) {
        const { error: itemError } = await supabase
          .from('free_drug_sale_items')
          .insert({
            sale_id: saleData.id,
            drug_id: item.drug_id,
            quantity: item.qty,
            unit_price: item.sell_price,
            total_price: item.sell_price * item.qty
          });
        if (itemError) throw itemError;

        const drug = drugs.find(d => d.drug_id === item.drug_id);
        if (drug) {
          const newStock = drug.stock - item.qty;

          const { error: stockError } = await supabase
            .from('drugs')
            .update({ stock: Math.max(0, newStock) })
            .eq('drug_id', item.drug_id);

          if (stockError) throw stockError;

          await supabase
            .from('drug_stock_logs')
            .insert({
              drug_id: item.drug_id,
              change_type: 'sale',
              quantity: -item.qty,
              previous_stock: drug.stock,
              new_stock: Math.max(0, newStock),
              notes: `Penjualan FS-${saleData.id} - ${buyerName}`
            });
        }
      }

      cart = [];
      buyerName = '';
      buyerPhone = '';
      paymentMethod = 'cash';
      notes = '';
      activeView = 'history';
      await Promise.all([fetchDrugs(), fetchSales()]);
    } catch (err) {
      console.error('Process sale error:', err);
      alert('Gagal memproses penjualan. Silakan coba lagi.');
    } finally {
      saving = false;
    }
  }

  function printReceipt() {
    window.print();
  }

  onMount(async () => {
    loading = true;
    await Promise.all([fetchDrugs(), fetchSales()]);
    loading = false;
  });
</script>

<svelte:head>
  <title>Penjualan Obat Bebas - Farmasi</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Penjualan Obat Bebas</h1>
      <p class="text-sm text-gray-500 mt-1">Transaksi penjualan obat tanpa resep</p>
    </div>
    <button class="btn-secondary btn-sm" onclick={() => goto('/farmasi')}>
      <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
      </svg>
      Kembali
    </button>
  </div>

  <div class="grid grid-cols-1 xl:grid-cols-3 gap-6">
    <div class="xl:col-span-2 space-y-6">
      <div class="card p-0">
        <div class="flex overflow-x-auto border-b border-gray-200 scrollbar-thin">
          <button
            class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
              {activeView === 'new'
                ? 'border-primary-600 text-primary-700 bg-primary-50'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
            onclick={() => activeView = 'new'}
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
            </svg>
            Penjualan Baru
          </button>
          <button
            class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
              {activeView === 'history'
                ? 'border-primary-600 text-primary-700 bg-primary-50'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
            onclick={() => activeView = 'history'}
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
            </svg>
            Riwayat Penjualan
          </button>
        </div>

        <div class="p-6">
          {#if activeView === 'new'}
            <div class="space-y-6">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-1">
                  <label class="label">Nama Pembeli <span class="text-red-500">*</span></label>
                  <input type="text" class="input-field" bind:value={buyerName} placeholder="Nama pembeli..." />
                </div>
                <div class="space-y-1">
                  <label class="label">No. Telepon</label>
                  <input type="tel" class="input-field" bind:value={buyerPhone} placeholder="08xxx..." />
                </div>
              </div>

              <div class="space-y-2">
                <label class="label">Cari Obat</label>
                <div class="flex gap-2">
                  <div class="relative flex-1">
                    <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
                    </svg>
                    <input
                      type="text"
                      class="input-field pl-10"
                      placeholder="Cari nama atau kode obat..."
                      bind:value={drugSearch}
                      oninput={searchDrugs}
                    />
                  </div>
                  <select class="select-field w-auto" bind:value={categoryFilter}>
                    <option value="">Semua Kategori</option>
                    {#each DRUG_CATEGORIES as cat}
                      <option value={cat}>{cat}</option>
                    {/each}
                  </select>
                </div>
                {#if drugResults.length > 0}
                  <div class="border border-gray-200 rounded-lg divide-y divide-gray-100 max-h-60 overflow-y-auto">
                    {#each drugResults as drug}
                      <button
                        class="flex items-center justify-between w-full px-4 py-3 hover:bg-gray-50 text-left transition-colors"
                        onclick={() => addToCart(drug)}
                      >
                        <div class="flex-1">
                          <div class="flex items-center gap-2">
                            <span class="text-sm font-medium text-gray-900">{drug.name}</span>
                            <span class="badge badge-gray text-xs">{drug.category}</span>
                          </div>
                          <div class="flex items-center gap-3 mt-0.5 text-xs text-gray-500">
                            <span class="font-mono">{drug.code}</span>
                            <span>Stok: {drug.stock} {drug.unit}</span>
                            <span class="font-semibold text-primary-600">{formatCurrency(drug.sell_price)}</span>
                          </div>
                        </div>
                        <svg class="w-5 h-5 text-gray-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                        </svg>
                      </button>
                    {/each}
                  </div>
                {/if}
              </div>

              {#if filteredDrugs.length > 0 && drugSearch.length === 0}
                <div class="space-y-2">
                  <p class="text-xs text-gray-500 font-medium uppercase tracking-wide">Daftar Obat Tersedia ({filteredDrugs.length})</p>
                  <div class="border border-gray-200 rounded-lg divide-y divide-gray-100 max-h-72 overflow-y-auto">
                    {#each filteredDrugs.slice(0, 20) as drug}
                      <button
                        class="flex items-center justify-between w-full px-4 py-3 hover:bg-gray-50 text-left transition-colors"
                        onclick={() => addToCart(drug)}
                      >
                        <div class="flex-1">
                          <div class="flex items-center gap-2">
                            <span class="text-sm font-medium text-gray-900">{drug.name}</span>
                            <span class="badge badge-gray text-xs">{drug.category}</span>
                          </div>
                          <div class="flex items-center gap-3 mt-0.5 text-xs text-gray-500">
                            <span class="font-mono">{drug.code}</span>
                            <span>Stok: {drug.stock} {drug.unit}</span>
                            <span class="font-semibold text-primary-600">{formatCurrency(drug.sell_price)}</span>
                          </div>
                        </div>
                        <svg class="w-5 h-5 text-gray-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                        </svg>
                      </button>
                    {/each}
                  </div>
                </div>
              {/if}

              {#if cart.length > 0}
                <div class="space-y-3">
                  <h4 class="text-sm font-semibold text-gray-700 uppercase tracking-wide">Keranjang</h4>
                  <div class="border border-gray-200 rounded-lg overflow-hidden">
                    <table class="w-full">
                      <thead>
                        <tr class="table-header">
                          <th class="px-4 py-2 text-xs font-semibold text-gray-500 uppercase">Obat</th>
                          <th class="px-4 py-2 text-xs font-semibold text-gray-500 uppercase text-center">Qty</th>
                          <th class="px-4 py-2 text-xs font-semibold text-gray-500 uppercase text-right">Harga</th>
                          <th class="px-4 py-2 text-xs font-semibold text-gray-500 uppercase text-right">Subtotal</th>
                          <th class="px-4 py-2 w-10"></th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-gray-100">
                        {#each cart as item}
                          <tr class="hover:bg-gray-50">
                            <td class="px-4 py-3">
                              <p class="font-medium text-gray-900 text-sm">{item.name}</p>
                              <p class="text-xs text-gray-400 font-mono">{item.code}</p>
                            </td>
                            <td class="px-4 py-3 text-center">
                              <div class="inline-flex items-center gap-1">
                                <button
                                  class="w-6 h-6 rounded bg-gray-100 hover:bg-gray-200 flex items-center justify-center text-gray-600 text-sm font-bold"
                                  onclick={() => updateCartQty(item.drug_id, item.qty - 1)}
                                >
                                  -
                                </button>
                                <input
                                  type="number"
                                  class="w-14 text-center text-sm font-semibold border border-gray-300 rounded px-1 py-1 focus:outline-none focus:ring-1 focus:ring-primary-500"
                                  value={item.qty}
                                  oninput={(e) => updateCartQty(item.drug_id, e.target.value)}
                                  min="1"
                                  max={item.max_stock}
                                />
                                <button
                                  class="w-6 h-6 rounded bg-gray-100 hover:bg-gray-200 flex items-center justify-center text-gray-600 text-sm font-bold"
                                  onclick={() => updateCartQty(item.drug_id, item.qty + 1)}
                                >
                                  +
                                </button>
                              </div>
                              <p class="text-xs text-gray-400 mt-0.5">/ {item.unit}</p>
                            </td>
                            <td class="px-4 py-3 text-right text-sm text-gray-600">{formatCurrency(item.sell_price)}</td>
                            <td class="px-4 py-3 text-right text-sm font-semibold text-gray-900">{formatCurrency(item.sell_price * item.qty)}</td>
                            <td class="px-4 py-3 text-center">
                              <button class="text-gray-400 hover:text-red-500 transition-colors" onclick={() => removeFromCart(item.drug_id)}>
                                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
                                </svg>
                              </button>
                            </td>
                          </tr>
                        {/each}
                      </tbody>
                      <tfoot>
                        <tr class="border-t-2 border-gray-300 bg-gray-50">
                          <td colspan="3" class="px-4 py-3 text-sm font-bold text-gray-900 text-right">Total</td>
                          <td class="px-4 py-3 text-sm font-bold text-primary-700 text-right">{formatCurrency(cartTotal)}</td>
                          <td class="px-4 py-3"></td>
                        </tr>
                      </tfoot>
                    </table>
                  </div>
                </div>
              {/if}
            </div>

          {:else if activeView === 'history'}
            <div class="space-y-4">
              <h3 class="text-lg font-semibold text-gray-900">Riwayat Penjualan</h3>
              {#if loading}
                <div class="flex items-center justify-center py-16">
                  <div class="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
                </div>
              {:else if sales.length === 0}
                <div class="text-center py-16 text-gray-400">
                  <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 0 0-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 0 1-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 0 0 3 15h-.75M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm3 0h.008v.008H18V10.5Zm-12 0h.008v.008H6V10.5Z" />
                  </svg>
                  <p class="text-lg font-medium">Belum ada riwayat penjualan</p>
                </div>
              {:else}
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead>
                      <tr class="table-header">
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase w-10">#</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">No. Nota</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase">Pembeli</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Tanggal</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Metode</th>
                        <th class="px-4 py-3 text-xs font-semibold text-gray-500 uppercase text-right">Total</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100">
                      {#each sales as sale, i}
                        <tr class="hover:bg-gray-50 transition-colors">
                          <td class="table-cell text-gray-400 font-mono text-xs">{i + 1}</td>
                          <td class="table-cell">
                            <span class="font-mono text-sm font-semibold text-primary-700 bg-primary-50 px-2 py-0.5 rounded">
                              {sale.sale_id || '-'}
                            </span>
                          </td>
                          <td class="table-cell font-medium text-gray-900">{sale.buyer_name || '-'}</td>
                          <td class="table-cell text-gray-500 hidden md:table-cell text-xs">{formatDate(sale.created_at)}</td>
                          <td class="table-cell hidden lg:table-cell">
                            <span class="badge badge-gray">{sale.payment_method || '-'}</span>
                          </td>
                          <td class="table-cell text-right font-semibold text-gray-900">{formatCurrency(sale.total)}</td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              {/if}
            </div>
          {/if}
        </div>
      </div>
    </div>

    <div class="xl:col-span-1">
      <div class="card sticky top-24 space-y-5">
        <div class="flex items-center gap-2">
          <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 0 0-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 0 1-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 0 0 3 15h-.75M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm3 0h.008v.008H18V10.5Zm-12 0h.008v.008H6V10.5Z" />
          </svg>
          <h2 class="text-lg font-semibold text-gray-900">Ringkasan</h2>
        </div>

        <div class="space-y-3">
          <div class="space-y-1">
            <label class="label">Metode Pembayaran</label>
            <div class="grid grid-cols-3 gap-2">
              <button
                class="px-3 py-2 rounded-lg border text-sm font-medium transition-colors
                  {paymentMethod === 'cash'
                    ? 'bg-emerald-100 border-emerald-400 text-emerald-700'
                    : 'bg-white border-gray-300 text-gray-600 hover:bg-gray-50'}"
                onclick={() => paymentMethod = 'cash'}
              >
                <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 0 0-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 0 1-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 0 0 3 15h-.75M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm3 0h.008v.008H18V10.5Zm-12 0h.008v.008H6V10.5Z" />
                </svg>
                Cash
              </button>
              <button
                class="px-3 py-2 rounded-lg border text-sm font-medium transition-colors
                  {paymentMethod === 'transfer'
                    ? 'bg-blue-100 border-blue-400 text-blue-700'
                    : 'bg-white border-gray-300 text-gray-600 hover:bg-gray-50'}"
                onclick={() => paymentMethod = 'transfer'}
              >
                <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0 0 12 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75Z" />
                </svg>
                Transfer
              </button>
              <button
                class="px-3 py-2 rounded-lg border text-sm font-medium transition-colors
                  {paymentMethod === 'card'
                    ? 'bg-purple-100 border-purple-400 text-purple-700'
                    : 'bg-white border-gray-300 text-gray-600 hover:bg-gray-50'}"
                onclick={() => paymentMethod = 'card'}
              >
                <svg class="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 0 0 2.25-2.25V6.75A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25v10.5A2.25 2.25 0 0 0 4.5 19.5Z" />
                </svg>
                Card
              </button>
            </div>
          </div>

          <div class="space-y-1">
            <label class="label">Catatan (opsional)</label>
            <textarea class="input-field h-16 resize-none text-sm" bind:value={notes} placeholder="Catatan transaksi..."></textarea>
          </div>

          {#if cart.length > 0}
            <div class="bg-gray-50 rounded-lg p-4 space-y-2">
              <div class="flex justify-between text-sm">
                <span class="text-gray-500">Jumlah Item</span>
                <span class="font-medium text-gray-900">{cart.length} obat</span>
              </div>
              <div class="flex justify-between text-sm">
                <span class="text-gray-500">Total Qty</span>
                <span class="font-medium text-gray-900">{cart.reduce((s, c) => s + c.qty, 0)} unit</span>
              </div>
              <div class="border-t border-gray-200 pt-2 mt-2">
                <div class="flex justify-between">
                  <span class="font-bold text-gray-900">Total Bayar</span>
                  <span class="font-bold text-lg text-primary-700">{formatCurrency(cartTotal)}</span>
                </div>
              </div>
            </div>

            <button
              class="w-full btn-success"
              onclick={processSale}
              disabled={saving || !buyerName.trim() || cart.length === 0}
            >
              {#if saving}
                <span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>
              {/if}
              <svg class="w-5 h-5 inline-block mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 0 0-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 0 1-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 0 0 3 15h-.75M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm3 0h.008v.008H18V10.5Zm-12 0h.008v.008H6V10.5Z" />
              </svg>
              Bayar & Cetak
            </button>
          {:else}
            <div class="text-center py-6 text-gray-400">
              <svg class="w-12 h-12 mx-auto mb-2 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 3h1.386c.51 0 .955.343 1.087.835l.383 1.437M7.5 14.25a3 3 0 0 0-3 3h15.75m-12.75-3h11.218c1.121-2.3 2.1-4.684 2.924-7.138a60.114 60.114 0 0 0-16.536-1.84M7.5 14.25 5.106 5.272M6 20.25a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0Zm12.75 0a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0Z" />
              </svg>
              <p class="text-sm">Keranjang kosong</p>
              <p class="text-xs mt-1">Pilih obat untuk ditambahkan</p>
            </div>
          {/if}
        </div>
      </div>
    </div>
  </div>
</div>
