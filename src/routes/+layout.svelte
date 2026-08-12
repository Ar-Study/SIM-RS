<script>
  import { base } from '$app/paths';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { supabase } from '$lib/supabase';
  import { getCurrentUser, signOut } from '$lib/auth';
  import { onMount } from 'svelte';
  import Toast from '$lib/Toast.svelte';
  import '../app.css';

  let { children } = $props();

  let user = $state(null);
  let profile = $state(null);
  let loading = $state(true);
  let sidebarOpen = $state(false);
  let sidebarCollapsed = $state(false);
  let activeDropdown = $state(null);
  let expandedSections = $state({ frontOffice: true, specialized: false, backOffice: false, admin: false });

  const navSections = [
    {
      id: 'main',
      items: [
        { label: 'Dashboard', href: '/', icon: 'home' }
      ]
    },
    {
      id: 'frontOffice',
      title: 'Front Office',
      items: [
        { label: 'Registrasi Pasien', href: '/registrasi', icon: 'clipboard-plus' },
        { label: 'Rawat Jalan', href: '/rawat-jalan', icon: 'stethoscope' },
        { label: 'Rawat Inap', href: '/rawat-inap', icon: 'bed-double' },
        { label: 'IGD', href: '/igd', icon: 'siren' },
        { label: 'Rekam Medis', href: '/rekam-medis', icon: 'file-text' },
        { label: 'Laboratorium', href: '/laboratorium', icon: 'flask-conical' },
        { label: 'Radiologi', href: '/radiologi', icon: 'scan' },
        { label: 'Farmasi', href: '/farmasi', icon: 'pill' },
        { label: 'Kasir / Billing', href: '/kasir', icon: 'receipt' },
        { label: 'Operasi', href: '/operasi', icon: 'scissors' }
      ]
    },
    {
      id: 'specialized',
      title: 'Unit Khusus',
      items: [
        { label: 'ICU', href: '/icu', icon: 'heart-pulse' },
        { label: 'NICU', href: '/nicu', icon: 'baby' },
        { label: 'HD (Hemodialisa)', href: '/hd', icon: 'droplets' },
        { label: 'IBS', href: '/ibs', icon: 'building' },
        { label: 'OBS / GYN', href: '/obsygn', icon: 'heart-handshake' },
        { label: 'VK (Verlos Kamer)', href: '/vk', icon: 'egg' }
      ]
    },
    {
      id: 'backOffice',
      title: 'Back Office',
      items: [
        { label: 'Laporan', href: '/laporan', icon: 'bar-chart-3' },
        { label: 'Bridging BPJS', href: '/bridging/bpjs', icon: 'link' },
        { label: 'SatuSehat', href: '/bridging/satusehat', icon: 'cloud' }
      ]
    },
    {
      id: 'admin',
      title: 'Admin',
      items: [
        { label: 'Master Data', href: '/admin', icon: 'database' }
      ]
    }
  ];

  function withBasePath(path) {
    if (!path?.startsWith('/')) return path;
    if (!base || base === '/') return path;
    if (path === base || path.startsWith(`${base}/`)) return path;
    return `${base}${path}`;
  }

  function stripBasePath(pathname) {
    if (!base || base === '/') return pathname;
    if (!pathname.startsWith(base)) return pathname;
    const stripped = pathname.slice(base.length);
    return stripped || '/';
  }

  function isActive(href) {
    const current = stripBasePath(page.url.pathname);
    if (href === '/') return current === '/';
    return current === href || current.startsWith(`${href}/`);
  }

  function toggleSection(sectionId) {
    expandedSections[sectionId] = !expandedSections[sectionId];
  }

  async function handleLogout() {
    try {
      await signOut();
      goto(withBasePath('/login'));
    } catch (err) {
      console.error('Logout failed:', err);
    }
  }

  function closeSidebar() {
    sidebarOpen = false;
  }

  function handleBaseAwareLinkClick(event) {
    const anchor = event.target?.closest?.('a[href]');
    if (!anchor) return;

    const rawHref = anchor.getAttribute('href');
    if (!rawHref || !rawHref.startsWith('/') || rawHref.startsWith('//')) return;

    const fixedHref = withBasePath(rawHref);
    if (fixedHref === rawHref) return;

    anchor.setAttribute('href', fixedHref);

    const isPlainLeftClick = event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey;
    const target = anchor.getAttribute('target');
    const isSelfTarget = !target || target === '_self';

    if (isPlainLeftClick && isSelfTarget && !anchor.hasAttribute('download')) {
      event.preventDefault();
      goto(fixedHref);
    }
  }

  onMount(async () => {
    let unsubscribeAuth = () => {};

    document.addEventListener('click', handleBaseAwareLinkClick, true);

    try {
      const currentUser = await getCurrentUser();
      if (currentUser) {
        user = currentUser;
        profile = currentUser.profile;
      }
    } catch (err) {
      console.error('Auth check failed:', err);
    } finally {
      loading = false;
    }

    try {
      const { data } = supabase.auth.onAuthStateChange((event, session) => {
        if (event === 'SIGNED_OUT') {
          user = null;
          profile = null;
          goto(withBasePath('/login'));
        } else if (event === 'SIGNED_IN' && session) {
          getCurrentUser().then(u => {
            if (u) {
              user = u;
              profile = u.profile;
            }
          });
        }
      });
      if (data?.subscription) unsubscribeAuth = () => data.subscription.unsubscribe();
    } catch (e) {
      console.warn('Auth state listener failed:', e);
    }

    return () => {
      document.removeEventListener('click', handleBaseAwareLinkClick, true);
      unsubscribeAuth();
    };
  });

  const roleLabel = $derived(profile?.role ? profile.role.charAt(0).toUpperCase() + profile.role.slice(1).replace('_', ' ') : '');
  const userInitials = $derived(
    profile?.full_name
      ? profile.full_name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
      : profile?.email?.slice(0, 2).toUpperCase() || '??'
  );
  const currentPath = $derived(stripBasePath(page.url.pathname));
  const isLoginPage = $derived(currentPath.startsWith('/login'));
  const isAPMPage = $derived(currentPath.startsWith('/apm'));
  const isPublicPage = $derived(isLoginPage || isAPMPage);
</script>

{#if isPublicPage}
  {@render children()}
{:else if loading}
  <div class="flex items-center justify-center min-h-screen bg-gray-50">
    <div class="flex flex-col items-center gap-4">
      <div class="w-12 h-12 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
      <p class="text-sm text-gray-500 font-medium">Memuat...</p>
    </div>
  </div>
{:else if !user}
  {@render children()}
{:else}
  <div class="flex h-screen overflow-hidden bg-gray-50">

    {#if sidebarOpen}
      <button
        class="fixed inset-0 bg-black/50 z-40 lg:hidden transition-opacity duration-300"
        onclick={closeSidebar}
        aria-label="Tutup sidebar"
      ></button>
    {/if}

    <aside
      class="fixed inset-y-0 left-0 z-50 flex flex-col bg-white border-r border-gray-200 transition-all duration-300 ease-in-out
        {sidebarCollapsed ? 'w-[72px]' : 'w-64'}
        {sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}"
    >
      <div class="flex items-center h-16 px-4 border-b border-gray-200 {sidebarCollapsed ? 'justify-center' : 'gap-3'}">
        <div class="flex items-center justify-center w-9 h-9 rounded-lg bg-primary-600 text-white flex-shrink-0">
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M4.26 10.147a60.438 60.438 0 0 0-.491 6.347A48.62 48.62 0 0 1 12 20.904a48.62 48.62 0 0 1 8.232-4.41 60.46 60.46 0 0 0-.491-6.347m-15.482 0a50.636 50.636 0 0 0-2.658-.813A59.906 59.906 0 0 1 12 3.493a59.903 59.903 0 0 1 10.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.717 50.717 0 0 1 12 13.489a50.702 50.702 0 0 1 7.74-3.342" />
          </svg>
        </div>
        {#if !sidebarCollapsed}
          <div class="flex flex-col min-w-0">
            <span class="text-sm font-bold text-gray-900 truncate">SIMRS</span>
            <span class="text-[10px] text-gray-400 truncate">Sistem Informasi Manajemen</span>
          </div>
        {/if}
      </div>

      <nav class="flex-1 overflow-y-auto py-3 px-2 scrollbar-thin">
        {#each navSections as section}
          {#if section.title}
            {#if !sidebarCollapsed}
              <button
                class="flex items-center justify-between w-full px-3 py-1.5 mt-3 text-[11px] font-semibold uppercase tracking-wider text-gray-400 hover:text-gray-600 transition-colors"
                onclick={() => toggleSection(section.id)}
              >
                <span>{section.title}</span>
                <svg
                  class="w-3.5 h-3.5 transition-transform duration-200 {expandedSections[section.id] ? 'rotate-180' : ''}"
                  fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="m19.5 8.25-7.5 7.5-7.5-7.5" />
                </svg>
              </button>
            {:else}
              <div class="mt-3 mb-1 flex justify-center">
                <div class="w-5 h-px bg-gray-200"></div>
              </div>
            {/if}
          {/if}

          {#if !section.title || expandedSections[section.id] || sidebarCollapsed}
            <ul class="space-y-0.5 {section.title && !sidebarCollapsed ? 'mt-1' : (section.title ? 'mt-2' : 'mt-0')}">
              {#each section.items as item}
                <li>
                  <a
                    href={withBasePath(item.href)}
                    onclick={closeSidebar}
                    class="group flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-all duration-150
                      {isActive(item.href)
                        ? 'bg-primary-50 text-primary-700'
                        : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'}
                      {sidebarCollapsed ? 'justify-center px-2' : ''}"
                    title={sidebarCollapsed ? item.label : ''}
                  >
                    <span class="flex-shrink-0 {isActive(item.href) ? 'text-primary-600' : 'text-gray-400 group-hover:text-gray-600'}">
                      {#if item.icon === 'home'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="m2.25 12 8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25" /></svg>
                      {:else if item.icon === 'clipboard-plus'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 0 0 2.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 0 0-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 0 0 .75-.75 2.25 2.25 0 0 0-.1-.664m-5.8 0A2.251 2.251 0 0 1 13.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25ZM6.75 12h.008v.008H6.75V12Zm0 3h.008v.008H6.75V15Zm0 3h.008v.008H6.75V18Z" /></svg>
                      {:else if item.icon === 'stethoscope'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6Zm0 9.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6Zm0 9.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25a2.25 2.25 0 0 1-2.25-2.25v-2.25Z" /></svg>
                      {:else if item.icon === 'bed-double'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5m8.25 3v6.75m0 0l-3-3m3 3l3-3M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" /></svg>
                      {:else if item.icon === 'siren'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" /></svg>
                      {:else if item.icon === 'file-text'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" /></svg>
                      {:else if item.icon === 'flask-conical'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5m14.8.8 1.402 1.402c1.232 1.232.65 3.318-1.067 3.611A48.309 48.309 0 0 1 12 21c-2.773 0-5.491-.235-8.135-.687-1.718-.293-2.3-2.379-1.067-3.61L5 14.5" /></svg>
                      {:else if item.icon === 'scan'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0 1 3.75 9.375v-4.5ZM3.75 14.625c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 0 1-1.125-1.125v-4.5ZM13.5 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0 1 13.5 9.375v-4.5Z" /><path stroke-linecap="round" stroke-linejoin="round" d="M6.75 6.75h.75v.75h-.75v-.75ZM6.75 16.5h.75v.75h-.75v-.75ZM16.5 6.75h.75v.75h-.75v-.75ZM13.5 13.5h.75v.75h-.75v-.75ZM13.5 19.5h.75v.75h-.75v-.75ZM19.5 13.5h.75v.75h-.75v-.75ZM19.5 19.5h.75v.75h-.75v-.75ZM16.5 16.5h.75v.75h-.75v-.75Z" /></svg>
                      {:else if item.icon === 'pill'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5m14.8.8 1.402 1.402c1.232 1.232.65 3.318-1.067 3.611A48.309 48.309 0 0 1 12 21c-2.773 0-5.491-.235-8.135-.687-1.718-.293-2.3-2.379-1.067-3.61L5 14.5" /></svg>
                      {:else if item.icon === 'receipt'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" /></svg>
                      {:else if item.icon === 'scissors'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M7.848 8.25l1.536.887M7.848 8.25a3 3 0 1 1-5.196-3 3 3 0 0 1 5.196 3zm1.536.887a2.165 2.165 0 0 1 1.083 1.839c.005.351.054.695.14 1.024M9.384 9.137l2.077 1.199M7.848 15.75l1.536-.887m-1.536.887a3 3 0 0 1-5.196 3 3 3 0 0 1 5.196-3zm1.536-.887a2.165 2.165 0 0 0 1.083-1.838c.005-.352.054-.695.14-1.025m-1.223 2.863 2.077-1.199m0-3.328a4.323 4.323 0 0 1 2.068-1.379l5.325-1.628a4.5 4.5 0 0 1 2.48-.044l.803.215-7.794 7.794M12 12.75v-5.75" /></svg>
                      {:else if item.icon === 'heart-pulse'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" /></svg>
                      {:else if item.icon === 'baby'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M15.182 15.182a4.5 4.5 0 0 1-6.364 0M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0ZM9.75 9.75c0 .414-.168.75-.375.75S9 10.164 9 9.75 9.168 9 9.375 9s.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Zm5.625 0c0 .414-.168.75-.375.75s-.375-.336-.375-.75.168-.75.375-.75.375.336.375.75Zm-.375 0h.008v.015h-.008V9.75Z" /></svg>
                      {:else if item.icon === 'droplets'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M12 21a8.004 8.004 0 0 0 8-8c0-3.868-3.093-7-8-7a7.966 7.966 0 0 0-5.657 2.343L3 12" /><path stroke-linecap="round" stroke-linejoin="round" d="M12 21a8.004 8.004 0 0 1-8-8c0-3.868 3.093-7 8-7a7.966 7.966 0 0 1 5.657 2.343L21 12" /></svg>
                      {:else if item.icon === 'building'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21" /></svg>
                      {:else if item.icon === 'heart-handshake'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" /><path stroke-linecap="round" stroke-linejoin="round" d="M12 12.75h.008v.008H12v-.008Z" /></svg>
                      {:else if item.icon === 'egg'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M12 21a8.004 8.004 0 0 0 8-8c0-3.868-3.093-7-8-7a7.966 7.966 0 0 0-5.657 2.343L3 12" /></svg>
                      {:else if item.icon === 'bar-chart-3'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 0 1 3 19.875v-6.75ZM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V8.625ZM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V4.125Z" /></svg>
                      {:else if item.icon === 'link'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 0 1 1.242 7.244l-4.5 4.5a4.5 4.5 0 0 1-6.364-6.364l1.757-1.757m9.86-2.06a4.5 4.5 0 0 0-1.242-7.244l-4.5-4.5a4.5 4.5 0 0 0-6.364 6.364L4.34 8.374" /></svg>
                      {:else if item.icon === 'cloud'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15a4.5 4.5 0 0 0 4.5 4.5H18a3.75 3.75 0 0 0 1.332-7.257 3 3 0 0 0-3.758-3.848 5.25 5.25 0 0 0-10.233 2.33A4.502 4.502 0 0 0 2.25 15Z" /></svg>
                      {:else if item.icon === 'database'}
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75"><path stroke-linecap="round" stroke-linejoin="round" d="M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375m16.5 0v3.75m-16.5-3.75v3.75m16.5 0v3.75C20.25 16.153 16.556 18 12 18s-8.25-1.847-8.25-4.125v-3.75m16.5 0c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125" /></svg>
                      {/if}
                    </span>
                    {#if !sidebarCollapsed}
                      <span class="truncate">{item.label}</span>
                    {/if}
                    {#if isActive(item.href) && !sidebarCollapsed}
                      <span class="ml-auto w-1.5 h-1.5 rounded-full bg-primary-600 flex-shrink-0"></span>
                    {/if}
                  </a>
                </li>
              {/each}
            </ul>
          {/if}
        {/each}
      </nav>

      <div class="border-t border-gray-200 p-3 {sidebarCollapsed ? 'px-2' : ''}">
        {#if !sidebarCollapsed}
          <div class="flex items-center gap-3 px-2 py-2">
            <div class="flex items-center justify-center w-9 h-9 rounded-full bg-primary-100 text-primary-700 text-sm font-bold flex-shrink-0">
              {userInitials}
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-semibold text-gray-900 truncate">
                {profile?.full_name || user?.email || 'User'}
              </p>
              <p class="text-xs text-gray-400 truncate">{roleLabel}</p>
            </div>
          </div>
          <button
            class="flex items-center gap-2 w-full mt-2 px-3 py-2 text-sm font-medium text-gray-500 rounded-lg hover:bg-red-50 hover:text-red-600 transition-colors duration-150"
            onclick={handleLogout}
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 9V5.25A2.25 2.25 0 0 1 10.5 3h6a2.25 2.25 0 0 1 2.25 2.25v13.5A2.25 2.25 0 0 1 16.5 21h-6a2.25 2.25 0 0 1-2.25-2.25V15m-3 0-3-3m0 0 3-3m-3 3H15" />
            </svg>
            Keluar
          </button>
        {:else}
          <button
            class="flex items-center justify-center w-full p-2 text-gray-400 rounded-lg hover:bg-red-50 hover:text-red-600 transition-colors duration-150"
            onclick={handleLogout}
            title="Keluar"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 9V5.25A2.25 2.25 0 0 1 10.5 3h6a2.25 2.25 0 0 1 2.25 2.25v13.5A2.25 2.25 0 0 1 16.5 21h-6a2.25 2.25 0 0 1-2.25-2.25V15m-3 0-3-3m0 0 3-3m-3 3H15" />
            </svg>
          </button>
        {/if}
      </div>
    </aside>

    <div class="flex flex-col flex-1 {sidebarCollapsed ? 'lg:ml-[72px]' : 'lg:ml-64'} transition-all duration-300">
      <header class="sticky top-0 z-30 flex items-center h-16 px-4 bg-white/80 backdrop-blur-md border-b border-gray-200 gap-4">
        <button
          class="flex items-center justify-center w-10 h-10 rounded-lg text-gray-500 hover:bg-gray-100 hover:text-gray-700 transition-colors lg:hidden"
          onclick={() => sidebarOpen = !sidebarOpen}
          aria-label="Toggle menu"
        >
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
          </svg>
        </button>

        <button
          class="hidden lg:flex items-center justify-center w-10 h-10 rounded-lg text-gray-500 hover:bg-gray-100 hover:text-gray-700 transition-colors"
          onclick={() => sidebarCollapsed = !sidebarCollapsed}
          aria-label="Toggle sidebar"
        >
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            {#if sidebarCollapsed}
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
            {:else}
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" />
            {/if}
          </svg>
        </button>

        <div class="flex-1">
          <h1 class="text-lg font-semibold text-gray-900">SIMRS</h1>
        </div>

        <div class="flex items-center gap-2">
          <button
            class="relative flex items-center justify-center w-10 h-10 rounded-lg text-gray-500 hover:bg-gray-100 hover:text-gray-700 transition-colors"
            onclick={() => activeDropdown = activeDropdown === 'notifications' ? null : 'notifications'}
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
              <path stroke-linecap="round" stroke-linejoin="round" d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0" />
            </svg>
            <span class="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full"></span>
          </button>

          <div class="relative">
            <button
              class="flex items-center gap-2.5 pl-2 pr-3 py-1.5 rounded-lg hover:bg-gray-100 transition-colors"
              onclick={() => activeDropdown = activeDropdown === 'profile' ? null : 'profile'}
            >
              <div class="flex items-center justify-center w-8 h-8 rounded-full bg-primary-100 text-primary-700 text-xs font-bold">
                {userInitials}
              </div>
              <div class="hidden sm:flex flex-col items-start">
                <span class="text-sm font-semibold text-gray-700 leading-tight">
                  {profile?.full_name || user?.email || 'User'}
                </span>
                <span class="text-[11px] text-gray-400 leading-tight">{roleLabel}</span>
              </div>
              <svg class="w-4 h-4 text-gray-400 hidden sm:block" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="m19.5 8.25-7.5 7.5-7.5-7.5" />
              </svg>
            </button>

            {#if activeDropdown === 'profile'}
              <button
                class="fixed inset-0 z-40"
                onclick={() => activeDropdown = null}
              ></button>
              <div class="absolute right-0 top-full mt-2 w-56 bg-white rounded-xl shadow-lg border border-gray-200 py-2 z-50">
                <div class="px-4 py-2 border-b border-gray-100">
                  <p class="text-sm font-semibold text-gray-900">{profile?.full_name || 'User'}</p>
                  <p class="text-xs text-gray-400">{user?.email}</p>
                </div>
                <a
                  href={withBasePath('/profile')}
                  class="flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                  onclick={() => activeDropdown = null}
                >
                  <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
                  </svg>
                  Profil Saya
                </a>
                <hr class="my-1 border-gray-100" />
                <button
                  class="flex items-center gap-3 w-full px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-colors"
                  onclick={() => { activeDropdown = null; handleLogout(); }}
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 9V5.25A2.25 2.25 0 0 1 10.5 3h6a2.25 2.25 0 0 1 2.25 2.25v13.5A2.25 2.25 0 0 1 16.5 21h-6a2.25 2.25 0 0 1-2.25-2.25V15m-3 0-3-3m0 0 3-3m-3 3H15" />
                  </svg>
                  Keluar
                </button>
              </div>
            {/if}
          </div>
        </div>
      </header>

      <main class="flex-1 overflow-y-auto p-4 md:p-6">
        {@render children()}
      </main>
    </div>
  </div>
  <Toast />
{/if}
