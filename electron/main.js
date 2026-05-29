const { app, BrowserWindow, Menu, protocol, net, shell } = require('electron');
const path = require('path');
const url = require('url');

const isMac = process.platform === 'darwin';

// 半自动更新:启动时拉这个 URL,JSON 格式 { latest, url, notes }。
// latest 比当前版本新 → App 顶部弹横幅引导用户去 url 下载新 dmg(手动覆盖安装)。
// 留空字符串则关闭更新检查。具体怎么发布更新,见项目根目录 CHANGELOG.md / 部署说明。
const UPDATE_MANIFEST_URL = 'https://gist.githubusercontent.com/Frank-oll/1152e135c53e5dc2ad6e7bce798ac887/raw/telesales-latest.json';

// 把 app:// 注册成"安全的"自定义协议,允许 Service Worker 注册并缓存 CDN 资源,
// 这样首次联网启动后,Tailwind / xlsx / html2canvas 等会被 sw.js 缓存,后续离线可用。
// file:// 不能用 Service Worker,所以必须自定义协议。
protocol.registerSchemesAsPrivileged([
  {
    scheme: 'app',
    privileges: {
      standard: true,
      secure: true,
      supportFetchAPI: true,
      allowServiceWorkers: true,
      corsEnabled: true,
      stream: true,
    },
  },
]);

function createWindow() {
  const win = new BrowserWindow({
    width: 1200,
    height: 680,
    minWidth: 720,
    minHeight: 520,
    title: 'Telesales',
    backgroundColor: '#f5f5f7',
    titleBarStyle: isMac ? 'hiddenInset' : 'default',
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  win.loadURL('app://local/prototype.html');

  // titleBarStyle: 'hiddenInset' 隐藏了原生标题栏,需要自己在页面顶部留一条拖拽区域,
  // 否则用户无法通过顶部拖动窗口。这里在每次页面加载完成后注入,刷新/导航后仍生效。
  // 同时把更新横幅的 CSS / JS 一并注入,后续 checkForUpdates 会调用 window.__showUpdateBanner。
  win.webContents.on('did-finish-load', () => {
    win.webContents.insertCSS(`
      .__electron-drag-bar {
        position: fixed;
        top: 0; left: 0; right: 0;
        height: 32px;
        z-index: 99999;
        -webkit-app-region: drag;
      }
      button, a, input, select, textarea,
      [role="button"], [contenteditable="true"] {
        -webkit-app-region: no-drag;
      }
      .__electron-update-banner {
        position: fixed; top: 44px; left: 50%;
        transform: translateX(-50%) translateY(-12px) scale(0.96);
        z-index: 99998;
        display: flex; align-items: center; gap: 10px;
        padding: 6px 6px 6px 16px;
        background: rgba(0, 113, 227, 0.95);
        color: #fff;
        border-radius: 999px;
        font-size: 13px; font-weight: 500;
        box-shadow: 0 8px 24px -8px rgba(0,0,0,0.35);
        backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px);
        opacity: 0;
        transition: opacity .22s ease, transform .22s cubic-bezier(.2,.8,.2,1);
        max-width: 92vw;
      }
      .__electron-update-banner.__upd-show {
        opacity: 1;
        transform: translateX(-50%) translateY(0) scale(1);
      }
      .__electron-update-banner .__upd-text {
        white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
        max-width: 56vw;
      }
      .__electron-update-banner .__upd-btn {
        background: #fff; color: #0071e3;
        border: none; font-weight: 600; font-size: 13px;
        padding: 6px 14px; border-radius: 999px;
        cursor: pointer;
      }
      .__electron-update-banner .__upd-close {
        background: rgba(255,255,255,0.18); color: #fff;
        border: none; width: 26px; height: 26px;
        border-radius: 999px;
        font-size: 16px; line-height: 1; cursor: pointer;
      }
      .__electron-update-toast {
        position: fixed; top: 44px; left: 50%;
        transform: translateX(-50%) translateY(-12px) scale(0.96);
        z-index: 99998;
        padding: 8px 18px;
        background: rgba(29, 29, 31, 0.92);
        color: #fff; border-radius: 999px;
        font-size: 13px; font-weight: 500;
        backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px);
        opacity: 0;
        transition: opacity .22s ease, transform .22s cubic-bezier(.2,.8,.2,1);
      }
      .__electron-update-toast.__upd-show {
        opacity: 1;
        transform: translateX(-50%) translateY(0) scale(1);
      }
    `).catch(() => {});
    win.webContents.executeJavaScript(`
      (() => {
        if (!document.querySelector('.__electron-drag-bar')) {
          const bar = document.createElement('div');
          bar.className = '__electron-drag-bar';
          document.body.appendChild(bar);
        }
        window.__showUpdateBanner = function (info) {
          if (!info || !info.url) return;
          const old = document.querySelector('.__electron-update-banner');
          if (old) old.remove();
          const banner = document.createElement('div');
          banner.className = '__electron-update-banner';
          const text = document.createElement('span');
          text.className = '__upd-text';
          text.textContent = '新版本 ' + info.latest + ' 可用' + (info.notes ? ' · ' + info.notes : '');
          const dl = document.createElement('button');
          dl.className = '__upd-btn';
          dl.textContent = '下载';
          const close = document.createElement('button');
          close.className = '__upd-close';
          close.setAttribute('aria-label', '关闭');
          close.textContent = '×';
          banner.append(text, dl, close);
          document.body.appendChild(banner);
          requestAnimationFrame(() => banner.classList.add('__upd-show'));
          dl.addEventListener('click', () => {
            window.open(info.url, '_blank');
            banner.classList.remove('__upd-show');
            setTimeout(() => banner.remove(), 260);
          });
          close.addEventListener('click', () => {
            banner.classList.remove('__upd-show');
            setTimeout(() => banner.remove(), 260);
          });
        };
        window.__showUpdateToast = function (msg) {
          const old = document.querySelector('.__electron-update-toast');
          if (old) old.remove();
          const t = document.createElement('div');
          t.className = '__electron-update-toast';
          t.textContent = msg;
          document.body.appendChild(t);
          requestAnimationFrame(() => t.classList.add('__upd-show'));
          setTimeout(() => {
            t.classList.remove('__upd-show');
            setTimeout(() => t.remove(), 260);
          }, 2200);
        };
      })();
    `).catch(() => {});

    // 启动后延迟 2 秒自动检查一次,避免拖慢启动 + 等 service worker 注册完
    setTimeout(() => checkForUpdates(win), 2000);
  });

  // 外链(CDN 文档之类)用系统浏览器打开,不在 app 里跳走
  win.webContents.setWindowOpenHandler(({ url: target }) => {
    if (target.startsWith('http://') || target.startsWith('https://')) {
      shell.openExternal(target);
      return { action: 'deny' };
    }
    return { action: 'allow' };
  });

  return win;
}

// 简易 SemVer 比较:只看数字段,够日常版本号 (1.0.2 vs 1.1.0) 用
function isNewerVersion(remote, local) {
  const parse = (v) => String(v || '').split('.').map((n) => parseInt(n, 10) || 0);
  const r = parse(remote);
  const l = parse(local);
  const len = Math.max(r.length, l.length);
  for (let i = 0; i < len; i++) {
    const a = r[i] || 0;
    const b = l[i] || 0;
    if (a > b) return true;
    if (a < b) return false;
  }
  return false;
}

async function checkForUpdates(win, opts = {}) {
  const { manual = false } = opts;
  const showToast = (msg) => {
    if (!manual || !win || win.isDestroyed()) return;
    win.webContents.executeJavaScript(
      `window.__showUpdateToast && window.__showUpdateToast(${JSON.stringify(msg)})`
    ).catch(() => {});
  };

  if (!UPDATE_MANIFEST_URL) {
    showToast('未配置更新源');
    return;
  }
  try {
    const resp = await net.fetch(UPDATE_MANIFEST_URL, { cache: 'no-cache' });
    if (!resp.ok) {
      showToast('检查失败:HTTP ' + resp.status);
      return;
    }
    const manifest = await resp.json();
    const current = app.getVersion();
    if (!manifest || !isNewerVersion(manifest.latest, current)) {
      showToast('当前已是最新版本 ' + current);
      return;
    }
    const payload = JSON.stringify({
      latest: String(manifest.latest || ''),
      url: String(manifest.url || ''),
      notes: String(manifest.notes || ''),
    });
    if (win && !win.isDestroyed()) {
      await win.webContents.executeJavaScript(
        `window.__showUpdateBanner && window.__showUpdateBanner(${payload})`
      );
    }
  } catch (err) {
    showToast('检查失败:网络错误');
  }
}

function registerAppProtocol() {
  const appDir = path.join(__dirname, 'app');
  protocol.handle('app', async (request) => {
    try {
      const requestUrl = new URL(request.url);
      // app://local/prototype.html → pathname = "/prototype.html"
      let pathname = decodeURIComponent(requestUrl.pathname);
      while (pathname.startsWith('/')) pathname = pathname.slice(1);
      if (!pathname) pathname = 'prototype.html';

      // 阻止跨目录访问
      const target = path.normalize(path.join(appDir, pathname));
      if (!target.startsWith(appDir + path.sep) && target !== appDir) {
        return new Response('Forbidden', { status: 403 });
      }

      return await net.fetch(url.pathToFileURL(target).toString());
    } catch (err) {
      return new Response(`Internal error: ${err.message}`, { status: 500 });
    }
  });
}

function buildMenu() {
  const template = [
    ...(isMac ? [{
      label: app.name,
      submenu: [
        { role: 'about' },
        { type: 'separator' },
        {
          label: '检查更新...',
          click: () => {
            const focused = BrowserWindow.getFocusedWindow() || BrowserWindow.getAllWindows()[0];
            if (focused) checkForUpdates(focused, { manual: true });
          },
        },
        { type: 'separator' },
        { role: 'hide' },
        { role: 'hideOthers' },
        { role: 'unhide' },
        { type: 'separator' },
        { role: 'quit' },
      ],
    }] : []),
    {
      label: '编辑',
      submenu: [
        { role: 'undo', label: '撤销' },
        { role: 'redo', label: '重做' },
        { type: 'separator' },
        { role: 'cut', label: '剪切' },
        { role: 'copy', label: '复制' },
        { role: 'paste', label: '粘贴' },
        { role: 'selectAll', label: '全选' },
      ],
    },
    {
      label: '视图',
      submenu: [
        { role: 'reload', label: '重新加载' },
        { role: 'forceReload', label: '强制重新加载' },
        { role: 'toggleDevTools', label: '开发者工具' },
        { type: 'separator' },
        { role: 'resetZoom', label: '实际大小' },
        { role: 'zoomIn', label: '放大' },
        { role: 'zoomOut', label: '缩小' },
        { type: 'separator' },
        { role: 'togglefullscreen', label: '进入全屏' },
      ],
    },
    {
      label: '窗口',
      submenu: [
        { role: 'minimize', label: '最小化' },
        { role: 'close', label: '关闭' },
      ],
    },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

app.whenReady().then(() => {
  registerAppProtocol();
  buildMenu();
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (!isMac) app.quit();
});
