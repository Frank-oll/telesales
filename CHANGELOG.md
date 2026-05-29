# 版更日志

本项目遵循 [SemVer](https://semver.org/lang/zh-CN/) 语义化版本。

## [1.2.0] - 2026-05-28

### 变更

- **删除主工作台"已打 N 个电话"角标**:与右侧黑卡"本次累计拨打"重复,移除 `#totalCountInline` 及 `renderWorkspace()` 中对应刷新,标题行更干净。
- **四个标签按钮收敛 + 居中**:按钮由 `flex-1` 撑满改为 `min-h-[58px]` 收敛,容器 `justify-center` 整体垂直居中,三列等高更均衡。

### 新增

- **左栏「近期标记」实时滚动模块**:工作台改为「左·近期标记 + 中·本通电话结果 + 右·实时统计」三列布局(`md:grid-cols-4`,1:2:1)。每次点击标签 / 提交意向客户,新记录从顶部插入(类型彩点 + 类型名,意向类附客户姓名 + 相对时间);采用**紧凑面板**(`self-start` 左上对齐、固定行高约 50px、列表 `max-height ≈ 4 行`),**默认最多显示 4 条**、超出向下隐藏并可滚轮查阅;相对时间随每秒心跳刷新且不打断滚动位置(`renderRecentMarks(false)` 仅更新时间)。该面板不参与三列等高拉伸,避免记录变多时把中/右两栏撑高。
- **默认窗口压扁**:主窗口默认尺寸由 1200 × 820 调整为 **1200 × 680**(`minHeight` 560 → 520),观感更宽矮、减少底部留白。
- **历史会话多选合并 + 合并导出**:历史页右上"多选合并"开关,会话卡可勾选;选中 ≥2 个出现"合并查看"。合并为只读临时视图(不落库),汇总标题"合并电销汇总报告"、副标题为会话数与日期区间,胶囊统计合并后总拨打 / 接通 / 意向。合并视图可导出 PNG(`电销合并汇总_起_止.png`)与意向客户 Excel(`电销合并意向客户_起_止.xlsx`,新增「来源会话日期」列区分跨会话客户)。

## [1.1.0] - 2026-05-27

### 新增

- **半自动更新提示**:App 启动 2 秒后会去 `UPDATE_MANIFEST_URL`(`electron/main.js` 顶部常量)拉取 JSON 清单 `{ latest, url, notes }`,如果 `latest` 比当前版本新,顶部弹出一条 iOS 风蓝色胶囊横幅"新版本 X.Y.Z 可用 · notes",带【下载】【×】两个按钮:【下载】用系统浏览器打开 `url` 让用户手动覆盖安装,【×】本次会话关闭横幅。网络异常 / 离线 / `UPDATE_MANIFEST_URL` 为空时静默,不打扰用户。
- **菜单【Telesales → 检查更新...】**:可手动触发一次检查。无新版本时弹"当前已是最新版本",有错误时弹"检查失败"。
- 不依赖 Apple Developer 签名,不依赖 electron-updater,JSON 清单可以放在任意能 HTTPS 访问的静态地址(GitHub Gist / Pages / OSS 等)。
- **主工作台"本通电话结果"标题右侧新增"已打 N 个电话"实时计数**,数据源复用 `state.calls.length`(与右上角"本次累计拨打"黑卡同源),在 `renderWorkspace()` 里通过 `setText('totalCountInline', c.total)` 统一刷新。
- **新增非技术用户解锁脚本** [tools/unlock-telesales.command](tools/unlock-telesales.command):打包成 `Telesales-Unlock-Helper.zip` 随 Release 一起分发。粉丝双击运行 → 自动 `xattr -dr com.apple.quarantine /Applications/Telesales.app` → 自动 `open` 拉起 App。优先无密码尝试,失败回退 `sudo`,全中文友好提示。解决 macOS Sequoia 之后"隐私与安全性"页面找不到"仍要打开"按钮的兜底问题。

## [1.0.1] - 2026-05-27

### 修复

- **窗口无法通过顶部拖动**:macOS 桌面 App 使用 `titleBarStyle: 'hiddenInset'` 隐藏了原生标题栏(保留左上角红绿灯按钮),但页面未提供拖拽区域,导致整个窗口无法被拖动。修复方式是在 `electron/main.js` 的 `did-finish-load` 钩子里注入一条 32 px 高度的透明拖拽条 `.__electron-drag-bar`(`-webkit-app-region: drag`),覆盖窗口顶部 32 px;同时将所有 `button / a / input / select / textarea / [role="button"] / [contenteditable="true"]` 标记为 `-webkit-app-region: no-drag`,保证按钮、输入框等交互元素照常响应点击。页面顶部内边距为 `sm:py-10`(40 px),拖拽条不会遮挡任何业务内容。

## [1.0.0] - 2026-05-26

### 新增

- 首个发布版本。基于 Electron 32 打包出 macOS arm64 DMG 安装包,内含原 PWA 页面 `prototype.html` 与离线缓存 Service Worker (`sw.js`)。
- 自定义 `app://` 协议加载本地资源,绕开 `file://` 不支持 Service Worker 的限制,首次联网后 Tailwind / xlsx / html2canvas 等 CDN 资源会被缓存,后续可完全离线运行。
- 中文菜单(编辑 / 视图 / 窗口),外链统一交由系统浏览器打开。
