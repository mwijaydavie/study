import { useEffect, useRef, useState } from 'react';

const supported = import.meta.env.PROD && window.isSecureContext && 'serviceWorker' in navigator;
const statusTimeout = 4000;
const updateInterval = 60_000;

// A controlling worker by itself doesn't prove the browser still has the files.
function verifyOfflineCopy(worker) {
  return new Promise((resolve) => {
    const channel = new MessageChannel();
    const finish = (ready) => {
      clearTimeout(timer);
      channel.port1.close();
      resolve(ready);
    };
    const timer = window.setTimeout(() => finish(false), statusTimeout);
    channel.port1.onmessage = ({ data }) => finish(data?.ready === true);
    try {
      worker.postMessage({ type: 'STUDYDESK_OFFLINE_STATUS' }, [channel.port2]);
    } catch {
      channel.port2.close();
      finish(false);
    }
  });
}

export function useOffline() {
  const [status, setStatus] = useState(supported ? 'preparing' : 'unavailable');
  const [waiting, setWaiting] = useState(null);
  const [updateState, setUpdateState] = useState('idle');
  const applying = useRef(null);

  useEffect(() => {
    if (!supported) return;
    const container = navigator.serviceWorker;
    let mounted = true;
    let registration;
    let registering = false;
    let worker;
    let setupFailed = false;
    let lastUpdateCheck = -Infinity;
    let statusCheck = 0;

    function refreshStatus() {
      if (!mounted) return;
      const controller = container.controller;
      const check = ++statusCheck;
      setWaiting(controller ? registration?.waiting ?? null : null);
      if (!controller) {
        setStatus(setupFailed ? 'not-ready' : 'preparing');
        return;
      }
      verifyOfflineCopy(controller).then((ready) => {
        if (mounted && check === statusCheck) setStatus(ready ? 'ready' : 'not-ready');
      });
    }

    function onWorkerState() {
      if (worker?.state === 'redundant' && !container.controller) setupFailed = true;
      refreshStatus();
    }

    function watchInstalling() {
      worker?.removeEventListener('statechange', onWorkerState);
      worker = registration?.installing;
      worker?.addEventListener('statechange', onWorkerState);
      refreshStatus();
    }

    async function register() {
      if (registering) return;
      registering = true;
      setupFailed = false;
      refreshStatus();
      try {
        const result = await container.register('/sw.js', { updateViaCache: 'none' });
        if (!mounted) return;
        registration = result;
        registration.addEventListener('updatefound', watchInstalling);
        watchInstalling();
        if (container.controller) checkForUpdate(true);
      } catch {
        setupFailed = true;
        refreshStatus();
      } finally {
        registering = false;
      }
    }

    function checkForUpdate(force = false) {
      if (!navigator.onLine) return;
      if (!registration) { void register(); return; }
      if (!force && Date.now() - lastUpdateCheck < updateInterval) return;
      lastUpdateCheck = Date.now();
      // A captive portal or weak connection shouldn't block the saved timetable.
      registration.update().catch(() => {}).finally(refreshStatus);
    }

    function onControllerChange() {
      if (applying.current !== null) {
        clearTimeout(applying.current);
        applying.current = null;
        window.location.reload();
        return;
      }
      refreshStatus();
    }

    function onOnline() {
      refreshStatus();
      checkForUpdate(true);
    }

    function onForeground() {
      if (document.visibilityState !== 'visible') return;
      refreshStatus();
      checkForUpdate();
    }

    container.addEventListener('controllerchange', onControllerChange);
    window.addEventListener('online', onOnline);
    window.addEventListener('focus', onForeground);
    document.addEventListener('visibilitychange', onForeground);
    void register();
    return () => {
      mounted = false;
      clearTimeout(applying.current);
      applying.current = null;
      container.removeEventListener('controllerchange', onControllerChange);
      window.removeEventListener('online', onOnline);
      window.removeEventListener('focus', onForeground);
      document.removeEventListener('visibilitychange', onForeground);
      worker?.removeEventListener('statechange', onWorkerState);
      registration?.removeEventListener('updatefound', watchInstalling);
    };
  }, []);

  function applyUpdate() {
    if (!waiting || applying.current !== null) return;
    setUpdateState('applying');
    const onFailure = () => {
      clearTimeout(applying.current);
      applying.current = null;
      setUpdateState('retry');
    };
    applying.current = window.setTimeout(onFailure, 10_000);
    try { waiting.postMessage({ type: 'STUDYDESK_ACTIVATE_UPDATE' }); }
    catch { onFailure(); }
  }

  return { status, updateReady: Boolean(waiting), updateState, applyUpdate };
}
