# Telesales · 打包 .dmg 指南

把项目根目录的 `prototype.html` 等文件包成一个独立的 macOS 应用,
产物是 `electron/dist/Telesales-1.0.0-arm64.dmg`。

## 一次性环境准备

需要 Node.js(18+ 即可)和 npm。检查:

```bash
node --version
npm --version
```

如果没装,从 https://nodejs.org/ 下个 LTS 版本(或者 `brew install node`)。

## 打包流程(每次出新 dmg 跑这两步)

```bash
cd "/Users/winnielin/Documents/Frank AI/小工具/客户电销记录/electron"

# 1. 安装依赖(第一次,或 package.json 改了之后)
npm install

# 2. 打包,产出 dmg
npm run dist
```

跑完之后,dmg 在:

```
electron/dist/Telesales-1.0.0-arm64.dmg
```

双击就能装,装完在「应用程序」里看到 **Telesales**。

> 默认只出 Apple Silicon (M1/M2/M3...) 版本。
> 如果是老 Intel Mac,跑 `npm run dist:intel`;
> 想两种都出,跑 `npm run dist:both`(两个独立 dmg)。

## 调试 / 本地起界面(不出 dmg)

```bash
npm start
```

会用 Electron 直接打开窗口,改 prototype.html 后重新跑 `npm start` 即可看到新内容。

## 关于"离线"

App 内置了 `prototype.html` / `manifest.json` / `icon.svg` / `sw.js`,
但页面里的 Tailwind / xlsx / html2canvas 是从 CDN 加载的。

**所以**:
- **首次启动需要联网一次**,Service Worker 会把 CDN 脚本缓存下来
- **之后就完全离线**:断网也能用,数据全在 localStorage 里

主进程把 `app://` 注册成了"安全"协议(等价于 https / localhost),
否则 `file://` 协议下 Service Worker 不会注册,缓存机制失效。

如果想做到"完全 0 网络依赖"(首次启动也不联网),需要把三个 CDN JS
下载到 `app/` 里再改 prototype.html 的 `<script src>` 指向本地 ——
单独再开一轮活儿。

## 改了源文件后怎么办

`npm run dist` 会自动从项目根目录把最新的 `prototype.html` / `manifest.json` /
`icon.svg` / `sw.js` 拷到 `electron/app/`,所以**只需要重新跑 `npm run dist`**。

> 不要直接编辑 `electron/app/` 里的副本 —— 它会被 sync 覆盖。

## Gatekeeper 报"应用已损坏"怎么办

未签名的 dmg 在 Gatekeeper 严格模式下会被拒。**两种解法**:

**A. 装完后右键打开(每个 Mac 第一次装时)**

在「应用程序」里 **右键 → 打开**,会出现"未验证开发者"提示,点「打开」即可。
之后双击就能正常用。

**B. 命令行去掉隔离属性**

```bash
xattr -dr com.apple.quarantine /Applications/Telesales.app
```

> 想免去这步,需要 99 美元/年的 Apple Developer ID,打包时配上证书做代码签名。
> 现在脚本是 `identity: null`(不签名),适合自用 / 内部分发。

## 文件结构

```
electron/
├── package.json            # Electron + electron-builder 配置
├── main.js                 # 主进程,打开窗口加载 prototype.html
├── BUILD.md                # 这份文档
├── .gitignore
├── app/                    # ← npm run sync 时从根目录拷进来
│   ├── prototype.html
│   ├── manifest.json
│   ├── icon.svg
│   └── sw.js
├── build/
│   ├── make-icon.sh        # 把 ../icon.svg 转成 icon.icns
│   └── icon.icns           # ← npm run icon 生成
└── dist/                   # ← 打包产物,gitignore
    └── Telesales-1.0.0-arm64.dmg
```
