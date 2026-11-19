import { useEffect, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { ArrowDownToLine, ArrowUpRight, CalendarDays, Check, ChevronRight, FolderOpen, Globe2, GraduationCap, ListChecks, Share, Smartphone, WifiOff } from 'lucide-react';
import '@fontsource-variable/plus-jakarta-sans/wght.css';
import './styles.css';
import { courses, eatClock } from './schedule.js';
import { Modal } from './components/ui.jsx';
import Timetable from './components/Timetable.jsx';
import StudyPlan from './components/StudyPlan.jsx';
import Materials from './components/Materials.jsx';

const navigation = [
  { id: 'timetable', title: 'Timetable', icon: CalendarDays },
  { id: 'plan', title: 'Study plan', icon: ListChecks },
  { id: 'materials', title: 'Materials', icon: FolderOpen },
];
const standalone = () => matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
const insideFrame = window.top !== window.self;

function readRoute() {
  const [page, folder] = location.hash.slice(1).split('/');
  const current = navigation.find((item) => item.id === page) ?? navigation[0];
  const selected = current.id === 'materials' && [...Object.keys(courses), 'networking', 'tools'].includes(folder) ? folder : '';
  return { current, selected };
}

function Brand() {
  return <a className="brand" href="#timetable" aria-label="StudyDesk home">
    <img src="/icons/favicon.svg" width="40" height="40" alt="" />
    <span><strong>StudyDesk<span>.</span></strong><small>STUDENT WORKSPACE</small></span>
  </a>;
}

function Navigation({ active, mobile = false }) {
  return <nav aria-label={mobile ? 'Main navigation' : 'Workspace'} className={mobile ? 'mobile-nav' : 'side-nav'}>
    {navigation.map(({ id, title, icon: Icon }) => <a key={id} href={`#${id}`} aria-current={active === id ? 'page' : undefined}>
      <span className="nav-icon"><Icon size={19} /></span><span>{title}</span>{!mobile && active === id && <ChevronRight className="nav-chevron" size={16} />}
    </a>)}
  </nav>;
}

function Sidebar({ active }) {
  return <aside className="sidebar" aria-label="StudyDesk workspace">
    <Brand />
    <p className="side-label">WORKSPACE</p>
    <Navigation active={active} />
    <div className="sidebar-bottom">
      <div className="semester-tag"><span className="square-icon"><GraduationCap size={19} /></span><div><strong>BIT Year 2</strong><span>UAUT · Semester 1</span></div></div>
      <div className="profile"><span className="avatar">MD</span><div><strong>Mwijay Davie</strong><span>2026/27 academic year</span></div></div>
    </div>
  </aside>;
}

function InstallDialog({ installed, onClose }) {
  return <Modal title={installed ? 'StudyDesk is installed' : 'Add StudyDesk to your home screen'} label="Install app" onClose={onClose}>
    {installed ? <p className="guide-intro">You can open StudyDesk from your app icon without going through your browser.</p> : <>
      <p className="guide-intro">Open the timetable in one tap. There’s nothing to download from an app store.</p>
      {insideFrame && <a className="button primary open-direct" target="_blank" rel="noopener noreferrer" href={window.location.href}>Open StudyDesk in your browser <ArrowUpRight size={16} /></a>}
      <div className="install-steps">
        <div><span className="square-icon tone-violet"><Smartphone size={20} /></span><div><h3>Android · Chrome</h3><p>Open Chrome’s ⋮ menu, choose <strong>Install app</strong> or <strong>Add to Home screen</strong>, then confirm.</p></div></div>
        <div><span className="square-icon tone-blue"><Share size={20} /></span><div><h3>iPhone · Safari</h3><p>Tap <strong>Share</strong>, scroll to <strong>Add to Home Screen</strong>, then tap <strong>Add</strong>.</p></div></div>
      </div>
      <p className="fine-print">Open the app online once to prepare it for offline use. If you’re using the Arena preview, its URL may not be permanent.</p>
    </>}
  </Modal>;
}

function App() {
  const [{ current, selected }, setRoute] = useState(readRoute);
  const [clock, setClock] = useState(eatClock);
  const [online, setOnline] = useState(navigator.onLine);
  const [showInstall, setShowInstall] = useState(false);
  const [installed, setInstalled] = useState(standalone);
  const installPrompt = useRef(null);

  useEffect(() => {
    const onHashChange = () => setRoute(readRoute());
    window.addEventListener('hashchange', onHashChange);
    return () => window.removeEventListener('hashchange', onHashChange);
  }, []);
  useEffect(() => {
    document.title = `${current.title} · StudyDesk`;
    window.scrollTo(0, 0);
  }, [current.id, current.title]);
  useEffect(() => {
    const refresh = () => setClock(eatClock());
    const interval = window.setInterval(refresh, 15_000);
    window.addEventListener('focus', refresh);
    document.addEventListener('visibilitychange', refresh);
    return () => {
      clearInterval(interval);
      window.removeEventListener('focus', refresh);
      document.removeEventListener('visibilitychange', refresh);
    };
  }, []);
  useEffect(() => {
    const connection = () => setOnline(navigator.onLine);
    const onPrompt = (event) => { event.preventDefault(); installPrompt.current = event; };
    const onInstalled = () => { setInstalled(true); installPrompt.current = null; };
    window.addEventListener('online', connection);
    window.addEventListener('offline', connection);
    window.addEventListener('beforeinstallprompt', onPrompt);
    window.addEventListener('appinstalled', onInstalled);
    return () => {
      window.removeEventListener('online', connection);
      window.removeEventListener('offline', connection);
      window.removeEventListener('beforeinstallprompt', onPrompt);
      window.removeEventListener('appinstalled', onInstalled);
    };
  }, []);
  async function install() {
    const prompt = installPrompt.current;
    if (!prompt || installed || insideFrame) { setShowInstall(true); return; }
    installPrompt.current = null;
    try {
      await prompt.prompt();
      if ((await prompt.userChoice).outcome === 'accepted') setInstalled(true);
    } catch { setShowInstall(true); }
  }

  const page = current.id;
  return <div className="app-shell">
    <a href="#main-content" className="skip-link" onClick={(event) => { event.preventDefault(); document.getElementById('main-content').focus(); }}>Skip to main content</a>
    <Sidebar active={page} />
    <div className="app-workspace">
      <header className="topbar">
        <div className="topbar-inner">
          <div className="mobile-brand"><Brand /></div>
          <div className="breadcrumbs"><span>Workspace</span><ChevronRight size={15} /><strong>{current.title}</strong></div>
          <div className="topbar-actions">
            <span className="timezone-label" title="East Africa Time, UTC+3"><Globe2 size={16} /> Dar es Salaam <span className="inline-dot" /> EAT</span>
            <button className="button primary install-button" type="button" onClick={install}>
              {installed ? <Check size={17} /> : <ArrowDownToLine size={17} />}<span>{installed ? 'App installed' : 'Install app'}</span>
            </button>
          </div>
        </div>
      </header>
      <main className="workspace-content" id="main-content" tabIndex={-1}>
        {!online && <p className="offline-banner" role="status"><WifiOff size={17} /> You’re offline. Showing the saved semester information.</p>}
        {page === 'timetable' && <Timetable clock={clock} />}
        {page === 'plan' && <StudyPlan clock={clock} />}
        {page === 'materials' && <Materials selected={selected} />}
        <footer className="page-footer"><span>StudyDesk <span className="inline-dot" /> UAUT BIT Year 2</span><span>{clock.label} <span className="inline-dot" /> EAT (UTC+3)</span></footer>
      </main>
    </div>
    <Navigation active={page} mobile />
    {showInstall && <InstallDialog installed={installed} onClose={() => setShowInstall(false)} />}
  </div>;
}

createRoot(document.getElementById('root')).render(<App />);

if (import.meta.env.PROD && window.isSecureContext && 'serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js').catch((error) => console.warn('Offline setup did not complete:', error));
}
