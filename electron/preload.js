// Preload:在隔离世界里向页面安全暴露少量主进程能力。
// 页面用 window.electronAPI 调用;非 Electron 环境(浏览器/PWA)下 window.electronAPI 不存在,页面已做兜底。
const { contextBridge, ipcRenderer } = require('electron');

// 同步取版本号,确保页面脚本(含 What's New 判断)在最早期就能读到 window.__APP_VERSION
let version = '';
try { version = ipcRenderer.sendSync('telesales:get-version-sync') || ''; } catch (e) { /* ignore */ }

contextBridge.exposeInMainWorld('__APP_VERSION', version);
contextBridge.exposeInMainWorld('electronAPI', {
  // 手动检查更新:复用主进程 checkForUpdates(manual),会自己弹横幅 / Toast
  checkForUpdates: () => ipcRenderer.invoke('telesales:check-updates'),
  getVersion: () => ipcRenderer.invoke('telesales:get-version'),
});
