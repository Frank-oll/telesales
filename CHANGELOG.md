# 版更日志

本项目遵循 [SemVer](https://semver.org/lang/zh-CN/) 语义化版本。

## [1.2.0] - 2026-05-28

### 变更

- **删除主工作台"已打 N 个电话"角标**:与右侧黑卡"本次累计拨打"重复,移除 `#totalCountInline` 及 `renderWorkspace()` 中对应刷新,标题行更干净。
- **主工作台两栏 + 左列上下叠放**:保持两栏(`md:grid-cols-3`),左列内部上下切分——上部「本通电话结果」四个按钮 `flex-1` 平分填满(约 2/3 高度,消除留白),下部「近期标记」(约 1/3 高度);左列与右栏统计 `items-stretch` 等高,左右两栏视觉找平,中部按钮不再因卡片过高而大片留白。
- **默认窗口压扁**:主窗口默认尺寸由 1200 × 820 调整为 **1200 × 680**(`minHeight` 560 → 520),观感更宽矮、减少底部留白。
- **右栏统计重排 + 工作台一屏自适应**:黑色「累计拨打」与绿色「意向客户 / 转化率」改为**并排各占一半宽、等高**(`grid grid-cols-2`),数字字号 56→40px、内边距收敛;下方「本次明细 + 营销质量」卡 `flex-1` 填满剩余高度、两段 `justify-evenly` 均匀撑高(行字号 13→14)。工作台容器改为 `md:h-screen` + 内层 `flex flex-col` + 网格 `flex-1`,**初次打开全部要素一屏可见、无需下滑**。

### 新增

- **「近期标记」实时列表 + 展开悬浮窗**:左列下部实时记录每次标记,新记录从顶部插入(类型彩点 + 类型名,意向类附客户姓名 + 相对时间),缩略展示能放下的几条、超出滚轮查看,相对时间随每秒心跳刷新且不打断滚动位置(`renderRecentMarks(false)` 仅更新时间)。点击「展开」打开悬浮窗 `#marksModal` 查看**全部标记**,并支持**删除**(任意标记;意向类同步移除对应客户)与**编辑**(意向类复用 `editCustomer` 改客户信息,非意向类仅可删除)。
- **历史会话多选合并 + 合并导出**:历史页右上"多选 / 删除"开关,会话卡可勾选;选中 ≥2 个出现"合并查看"。合并为只读临时视图(不落库),汇总标题"合并电销汇总报告"、副标题为会话数与日期区间,胶囊统计合并后总拨打 / 接通 / 意向。合并视图可导出 PNG(`电销合并汇总_起_止.png`)与意向客户 Excel(`电销合并意向客户_起_止.xlsx`,新增「来源会话日期」列区分跨会话客户)。
- **历史会话删除**:每张会话卡右侧新增删除按钮(`event.stopPropagation()` 不误触进入详情),二次确认后删除单条;多选态操作条新增「删除选中」(选中 ≥1 可用)批量删除。删除即 `saveState()` 落库并刷新历史列表与跟进任务,不可恢复。

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
