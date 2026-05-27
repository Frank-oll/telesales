# 客户电销记录(Telesales)

iOS 风格的电销外呼实时记录与汇总工具,数据全部本地存储,离线可用。Mac 桌面端基于 Electron 打包,浏览器端是渐进式 PWA。

## 安装(macOS)

### 下载

去 [Releases 页面](https://github.com/Frank-oll/telesales/releases/latest) 下载:

- `Telesales-x.x.x-arm64.dmg` —— Apple 芯片 Mac(M1/M2/M3/M4)
- `Telesales-x.x.x.dmg`(或带 `-x64` 后缀) —— Intel 芯片 Mac(如有发布)
- `Telesales-Unlock-Helper.zip` —— 首次安装解锁助手(见下文)

怎么看自己 Mac 是不是 Apple 芯片:左上角苹果菜单 → 关于本机 → "芯片"那一行,写 Apple M1/M2/M3/M4 开头就是 Apple 芯片;写 Intel 就是 Intel 芯片。

### 安装步骤

1. 双击下载好的 `.dmg`,把 Telesales 图标拖到右边的 Applications 文件夹
2. 关闭 dmg 窗口
3. 第一次打开 App 时,macOS 会弹"**无法验证开发者,可能含恶意软件**"
   - 这是因为本 App 没有用 Apple 开发者证书签名(99 美元/年),不是 bug
   - 别点【移到废纸篓】,点【完成】或【取消】即可
4. 按下面"解除 Gatekeeper 限制"任选一种方法解锁

---

## 解除 Gatekeeper 限制(首次安装必做)

### 方法 1:终端命令(推荐,所有 macOS 版本都稳)

1. `Cmd + 空格` 打开 Spotlight → 输入 `终端` → 回车,打开终端窗口
2. 把下面这一行**整行复制**粘贴到终端,回车:

   ```
   sudo xattr -dr com.apple.quarantine /Applications/Telesales.app
   ```

3. 终端提示 `Password:` → 输入你的**开机密码**
   - 注意:输密码时屏幕**不会显示任何字符**,这是正常的,直接打完按回车
4. 没报错就成功了,现在去 Applications 双击 Telesales 就能打开

### 方法 2:解锁助手脚本(不会用终端推荐这个)

适合不熟悉终端的用户。下载 [Releases](https://github.com/Frank-oll/telesales/releases/latest) 里的 `Telesales-Unlock-Helper.zip`:

1. 双击 zip 解压,得到 `unlock-telesales.command`
2. **用两指在文件上点一下**(等于"右键"),菜单里选【打开】
   - ⚠ 必须右键打开,直接双击会被 Gatekeeper 拦
3. 弹窗确认【打开】→ 自动跳出黑色终端窗口
4. 按提示按回车 → 自动解锁并启动 Telesales

脚本源码见 [tools/unlock-telesales.command](tools/unlock-telesales.command)。

### 方法 3:右键打开 App(macOS 14 及更早)

1. 在【应用程序】里找到 Telesales 图标
2. 两指点击(右键)→ 选【打开】
3. 弹出的对话框里点【打开】按钮

macOS 15(Sequoia)及以上,此方法很多时候被禁用,失败请用方法 1 / 方法 2。

---

## 功能

- **一键记录每通电话结果**:暂无磁铁需求 / 未接 / 已有供应商 / 待报价
- **意向客户登记表单**:姓名、电话、公司、需求点、下次跟进点
- **实时统计**:本次累计拨打、明细分布、接通率、接通转化、转化率
- **跟进任务清单**:支持导出图片
- **历史会话归档与搜索**
- **数据全部本地存储**(localStorage / IndexedDB),不上云、断网可用
- **自动检查更新**:启动后会查询远端 Gist 清单,有新版本时顶部弹横幅提示

---

## 开发

需要 Node 18+。

```bash
cd electron
npm install
npm start              # 本地启动 App
npm run dist           # 打包 macOS arm64 dmg(Apple 芯片)
npm run dist:intel     # 打包 macOS x64 dmg(Intel 芯片)
npm run dist:both      # 同时出 arm64 + x64
```

打包产物在 `electron/dist/`。

源 HTML 在项目根目录的 `prototype.html`(同时也是 PWA 入口),`npm run sync` 会把它和 `manifest.json` / `icon.svg` / `sw.js` 拷贝到 `electron/app/`,`npm start` / `npm run dist` 都会先自动跑一次 sync。

---

## 发版流程

1. 改代码 → 改 `electron/package.json` 的 `version` → 在 [CHANGELOG.md](CHANGELOG.md) 顶部加新版本条目
2. `cd electron && npm run dist`(或 `dist:both` 出双架构)
3. 在 [Releases](https://github.com/Frank-oll/telesales/releases) 新建 tag(`vX.Y.Z`),把新的 `.dmg` 上传到 Assets
4. `Telesales-Unlock-Helper.zip` 可以一起拖进去(不变的话也可以复用上一个 release 的链接)
5. 编辑用于自动更新的 Gist 清单 `telesales-latest.json`:
   - `latest` 改成新版本号
   - `url` 改成新 dmg 的直链
   - `notes` 填一句更新说明
6. 老用户下次打开 App,启动 2 秒后顶部会自动弹蓝色横幅提示更新

自动更新机制详见 [electron/main.js](electron/main.js) 顶部 `UPDATE_MANIFEST_URL` 常量。

---

## 许可

`UNLICENSED`(见 [electron/package.json](electron/package.json))。源代码公开,但未授予第三方使用、修改、再分发的权利。仅供作者发布给粉丝个人使用。

## 更新日志

见 [CHANGELOG.md](CHANGELOG.md)。
