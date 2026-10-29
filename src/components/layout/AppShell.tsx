import { useEffect, useRef } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { BottomNav } from '../navigation/BottomNav';
import { Toast } from '../ui';

/**
 * Mobile-proportioned application shell.
 * Desktop: centred 440px column on a quiet backdrop. Mobile: full width.
 * The scrollable region is <main>; the bottom navigation stays pinned below it on every screen.
 */
export function AppShell() {
  const mainRef = useRef<HTMLElement>(null);
  const { pathname } = useLocation();

  useEffect(() => {
    mainRef.current?.scrollTo({ top: 0 });
  }, [pathname]);

  return (
    <div className="app-backdrop">
      <div className="app-frame">
        <main ref={mainRef} className="app-main" id="main">
          <Outlet />
        </main>
        <BottomNav />
        <Toast />
      </div>
    </div>
  );
}
