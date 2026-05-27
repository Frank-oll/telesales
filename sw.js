// 客户电销记录 · Service Worker
// 首次联网后缓存所有资源,之后即使断网也能打开 + 运行
// 升级时只需改 VERSION,旧缓存会自动清理

const VERSION = 'telesales-v1.0.0';

// 预缓存的本地核心文件(同源)
const PRECACHE = [
  './prototype.html',
  './manifest.json',
  './icon.svg',
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(VERSION)
      .then(cache => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  // 只拦截 GET,跳过 POST 等
  if (event.request.method !== 'GET') return;
  // 跳过 chrome-extension / 非 http(s) 请求
  if (!event.request.url.startsWith('http')) return;

  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      return fetch(event.request)
        .then(response => {
          // 联网成功:把响应顺手缓存起来(CDN 资源会在第一次访问后被记住)
          if (response && (response.status === 200 || response.type === 'opaque')) {
            const clone = response.clone();
            caches.open(VERSION).then(cache => cache.put(event.request, clone)).catch(() => {});
          }
          return response;
        })
        .catch(() => {
          // 离线 + 没缓存:对 HTML 请求兜底返回主页面
          if (event.request.destination === 'document') {
            return caches.match('./prototype.html');
          }
          return new Response('', { status: 503, statusText: 'Offline' });
        });
    })
  );
});
