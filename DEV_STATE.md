# Course Schedule App — Development State

**当前版本**: v2.0.2+27（见文末发布记录）

## Current Status
- **Core UI**: Fully implemented (Home, Schedule, Edit Course, Import, Settings, Custom)
- **Data layer**: SharedPreferences-based storage, CSV course import working
- **Schedule grid**: Three-state course cells (active/inactive/other-week), selection border, horizontal swipe week navigation, in-class pulse effect gated to the current week
- **File parsing**: CSV parser works with LibreOffice/Excel converted files
- **Custom background**: Presets with circle editor (drag-to-position, color picker) and image backgrounds (viewport-style editor)
- **Background auto-load**: DiffuseBackground self-loads on first render (no manual trigger needed)
- **Notifications**: single always-on Foreground Service status notification (native ID 9000) showing next class (time + location) / in-class / remaining-count / end-of-day text; Dart computes the whole string, native only renders it. Polling every 30s, pushed only when the text changes (~10×/day). Reminder and in-class banner retired, along with packed notification IDs and the slot-sharing invariant
- **Test suite**: 85 tests green (`flutter test`), covering CSV/GBK import, edu extractor, credentials, foreground status text (week gate, session boundaries, fallbacks) and push de-duplication, schedule pulse gating, time slots

## Done
- ✅ Home screen: today's courses, week number display, greeting
- ✅ Schedule grid: 7-day × 5-slot grid with time labels, PageView-based horizontal swipe (weeks 1-20), arrow buttons + swipe gesture
- ✅ Course cells: active (solid), inactive/other-week (dimmed + strikethrough), selected (bold border), pulse animation for ongoing course
- ✅ Edit course: full form (name, teacher, location, day, periods, weeks, week-mode, color)
- ✅ CSV import: LibreOffice-converted .csv files from 教务系统 (XLS→CSV only, no binary XLS parsing)
- ✅ Bottom tab bar removed
- ✅ Notification center removed from routes
- ✅ Semester first-day picker
- ✅ Course cards on home screen: no tap action (prevent accidental navigation)
- ✅ Course card name: maxLines=1, overflow ellipsis
- ✅ Import flow: data conflict dialog → semester-first-day check
- ✅ Clear all data: resets courses + semester together
- ✅ Custom background: preset management (create/activate/delete), real-preview thumbnails
- ✅ Diffuse background: auto-loads active preset on first render, supports circles + images
- ✅ Circle editor: live fullscreen preview, drag-to-position, color picker, size +/- buttons; bottom bar always shows "add circle" + count (no need to tap away to add more)
- ✅ Image editor: viewport-style phone-ratio preview frame, pinch-to-zoom (0.3x–4x), drag-to-pan, original-size initial scale, pick/replace/remove/reset
- ✅ Default presets: "默认" (3 circles) + "纯白" (empty) seeded on first launch
- ✅ Presets stored independently — not affected by course data clearing
- ✅ Preset card thumbnails: real mini-render of preset appearance
- ✅ Image model: imageOriginalW/H fields for aspect ratio calculation
- ✅ Notification init: permission request, channel creation "课程提醒", boot recovery
- ✅ Notification polling: Timer every 30s, Foreground Service anchor, fireImmediate via MethodChannel
- ✅ Debug button: "调试：5秒后发通知" in settings
- ✅ Android manifest: POST_NOTIFICATIONS, FOREGROUND_SERVICE, FOREGROUND_SERVICE_SPECIAL_USE, VIBRATE
- ✅ Foreground Service anchor with "流转" persistent notification ("上课常驻" channel)
- ✅ MainActivity MethodChannel for notification tap → bringToForeground
- ✅ Dead code removed: notification_center_screen, push_notification_screen, status_bar, app_card
- ✅ Unused dependencies removed: sqflite
- ✅ AlarmManager legacy code removed: AlarmReceiver.kt, BootReceiver.kt, scheduleAlarm/cancelAlarm handlers
- ✅ debugFireNow debug button removed (v1.2 dead-code cleanup, confirmed by grep)
- ✅ Notification copy cleaned: no emoji, simple ` · ` separators (纯文本"课程提醒"/"正在上课"/"即将上课")
- ✅ Test suite green: 24/24 — fixed 2 legacy-broken CSV parser tests (test data didn't match real 8-column CSV layout; rewritten with quoted multiline cells + time label in col 0)
- ✅ CSV import encoding fallback: UTF-8 strict → GBK (charset package), 教务原始导出无需转码; real-file e2e 15 courses verified
- ✅ CSV column mapping: day-of-week columns detected from header row (self-adaptive)
- ✅ 教务在线导入: EduWebViewScreen (webview_flutter) — desktop UA + wide viewport + pinch zoom; 直通入口 xk.csust.edu.cn; INTERNET permission + cleartext whitelist (csust.edu.cn)
- ✅ 课表提取: edu_extractor.dart — injection JS (iframe-aware kbtable extraction, innerHTML <br> handling) + Dart parser (multi-course split, odd/even weeks, 姓名(职称) format); Chrome headless verified on real DOM, 15/15 courses match CSV result
- ✅ 导入流程复用: ImportScreen parameterized (initialCourses), 设置页导课入口弹菜单 (CSV/在线导入), 旧课表处理弹窗先于方式选择
- ✅ 账密本地存储: flutter_secure_storage (Keystore 加密) + 记住账密开关 (实时 input 捕获 → 跳离登录页落盘) + 登录页自动填充 (验证码手输) + 设置页「已保存的教务账号」管理 (查看/清除)
- ✅ 登录页调研: form#loginForm / #userAccount / #userPassword / #RANDOMCODE(图片验证码); login() 提交前清空输入框 → 捕获必须实时
- ✅ 多账密交互(v1.5.2): 账密列表存储(同账号覆盖置顶) + 选中持久化 + 「账密：0135」按钮(后缀显示所选后四位,点击展开列表选择/删除,删空自动收起) + 手动「填充」按钮 + 右上角「保存」开关(持久化,默认关)控制登录时保存; 移除设置页账号条目
- ✅ 账密捕获兜底(v1.5.4): input 事件 + 登录按钮点击 + 回车 + submit 三路兜底(覆盖浏览器自动填充无 input 事件的场景)
- ✅ 导入页提示弹窗(v1.5.3~1.5.5): 浅色卡片式(白底深字圆角描边) + 0.75s + 上移(底部 84px)不遮挡三按钮 + 左右边距 32px
- ✅ 网页后退按钮(v1.5.6): 顶部栏 ↶ 后退(无历史置灰); 调研结论: 强智 iframe 逐级后退会触发会话失效整窗跳登录页(服务端机制),故后退=主 frame goBack 回登录页
- ✅ 快捷导入同步(v1.5.9): 课程表页入口与设置页同流程(旧课处理 → 导入方式菜单 → 学期检查)
- ✅ 主界面空状态(v1.5.10~1.5.14): 移除「去添加课程」按钮(保留 header 日历入口); 折纸鹤插图 OrigamiCrane(CustomPaint 重绘 cranes.svg 7 色块,鲜艳暖色系 80% 透明度); 文字纯黑
- ✅ 「今天没有课程」流动效果(v1.5.16~1.5.23): 六课程色渐变 ShaderMask 沿文字平移(TileMode.repeated 平铺无缝 + 末尾补回首色消除边界硬切),渐变带 4 宽每色段 2/3 文字宽,6.4s 周期
- ✅ 彩蛋(v1.5.11): 空状态文案表情晚 7 点后 ☀️→🌙

## Known Issues / Next Candidates

- ⬜ 常驻通知的后台更新**尚未真机验证**：文案刷新依赖 Dart isolate 存活，
  而前台服务只保证进程不被杀，不保证 FlutterActivity/engine 不被回收；
  最坏情况是文案冻结在最后一次计算结果（不会变错，只会变旧）。
  已把刷新点放在 `_checkSchedule` 早退之前，但**进程被回收这一路径没有运行时证据**。
- ⬜ 常驻通知不设 `setVisibility`，锁屏可能不显示内容（有意取舍）。
  若希望锁屏可见下节课，加一行 `setVisibility(VISIBILITY_PUBLIC)` 即可。
- ⬜ 折叠态/锁屏下的文案截断表现未实测，且**无法用代码完全控制**；
  现有文案已把课程名放在前段以降低截断损失。
- ⬜ `database_service.dart` 的 `Course.fromMap` 无 try/catch，`course.dart` 里 `map['id'] as String`
  遇脏数据会抛异常并冒泡到 `loadCourses()` → 课程列表整体为空、首页空白，且每次启动复现。建议逐条容错跳过。
- ⬜ 通知更新依赖国产 ROM 省电策略：代码已做定时器对齐 :00/:30 + 前台服务锚定，
  但真实准点率受系统管控影响，见 README 保活设置。
- ⬜ 节假日识别（未实现，已讨论）：`lunar` 包（纯 Dart、无原生依赖、含法定节假日与调休数据、2026 年数据已收录）
  是较优数据源；「读手机日历」方案因 `CalendarProvider` 不含中国法定节假日、依赖 ROM/用户订阅、
  且依赖字符串匹配容易被用户自建日程误判，未采用。降级原则：数据缺失时**按上课处理**（漏提醒的代价远大于多提醒）。

## v2.0.2 — 常驻通知改为课程状态显示，退役课前提醒与「提醒提前量」设置

一句话：常驻通知不再写「流转」，改为显示下节课与今日剩余节数。

### 1. 常驻通知承载课程状态（`foreground_status.dart` / `CourseForegroundService.kt`）

- ✅ **文案全部在 Dart 侧算好**再整串交给原生：`buildForegroundStatus()` 纯函数、可注入时间。
  原生保持"哑"的，只 `setContentText`，不在 Kotlin 里重实现课程逻辑或中文时间格式。
- ✅ **五种状态**：课间 `下节课 10:10 高等数学 · 综合楼A301 · 今日还剩 3 节`／课前窗口
  `高等数学 10:10 上课 · 综合楼A301 · 今日还剩 3 节`／课中 `正在上 高等数学 · 今日还剩 2 节`／
  `今日课程已结束( ノ^ω^)ノ゚`／`今日无课• ᴗ •̥`；学期未设置或课程表为空时回退 `流转`。
- ✅ **剩余节数含正在上的那节**（还没上完），所以课中从 3 变 2 发生在该节**结束**时刻。
- ✅ 地点为空时整段省略；课中态不重复地点与时间（课前已给过）。
- ✅ **课前窗口文案结构明显不同**（课程名前置 + 「上课」），不是只改几个字 ——
  提醒退役后它是课前唯一会变的可见物。
- ✅ 新增 `PendingIntent`：点通知打开 app（此前点击无反应）。

### 2. 退役「正在上课」横幅与课前提醒

- ✅ **课程提醒通知与上课横幅全部删除**。常驻通知已承载同样的信息，两者重复。
- ✅ 随之删除：位编码通知 ID（`_packId` / `_kindReminder` / `_kindOngoing` / `_kindDismiss`）、
  「提醒与正在上课共用同一槽位」的不变量、`NativeAlarmService` 与 `alarm` 通道、
  `flutter_local_notifications` 依赖（连带 `pubspec.lock` 少 7 个包）。
- ✅ `ic_stat_course` 纯白剪影小图标保留，常驻通知继续使用。
- 有意的取舍：**常驻通知不设 `setVisibility`**（保持默认，锁屏不显示内容）；
  不改振动、不改提示音 —— 全程无声无振动、不可划掉。

### 3. 刷新时机（`notification_service.dart`）

- ✅ 复用已有的 30 秒轮询（对齐 :00/:30），文案边界过后最多 30 秒更新。
- ✅ **仅在文案变化时下发**（字符串相等即跳过）→ 一天约 10 次原生调用，
  既避免反复触碰通知栏，也远离同一通知 ID 的更新频率限制。
- ✅ **刷新调用点移到早退分支之前**：原 `if (_firstDay == null || _courses.isEmpty) return;`
  会让课程表为空的用户通知永远冻结在旧文案上。

### 4. 退役「提醒提前量」设置

- ✅ 该设置**名存实亡**：它原本用来决定课前提醒通知何时发出，而那个通知已经退役；
  剩下的唯一作用是选课前文案何时切换措辞，不值得留一个旋钮。
- ✅ 课前窗口改为常量 `kPreClassWindow = Duration(minutes: 15)`（沿用原默认值），
  课前文案行为完全不变。
- ✅ 删除：设置页整行 + 选择弹窗、`StorageService.getAdvanceMinutes` /
  `setAdvanceMinutes`、`NotificationService._advanceMinutes` 及
  `buildForegroundStatus` 的 `advanceMinutes` 参数。
- ⚠️ 已存在的 `notification_advance_minutes` 键**留在 SharedPreferences 里不再读取**
  （无代码再写该键，清理它会白白增加启动开销），无副作用。

### 5. 补回通知权限申请（回归修复）

- 🔴 **本次改造过程中自己引入的回归**：`flutter_local_notifications` 的
  `requestNotificationsPermission()` 是 app 唯一的通知权限申请入口，退役提醒时把插件
  一起删掉，导致 **Android 13+ 上首次安装可能完全不显示常驻通知**。
  单测与编译都覆盖不到运行时权限，所以此前"验证通过"的判断是错的。
- ✅ 修复：`MainActivity.onCreate()` 里原生申请 `POST_NOTIFICATIONS`（API ≥ 33），
  已授权则完全静默。放在 Activity 而非 Service：Activity 此时已 resume，系统才会真正弹窗。
- 教训：**删依赖时要核查它顺带承担的职责**，而不是只看它显式导出的 API。

### 验证

- ✅ `flutter test` 全量 **85/85 通过**（新增 30 个：状态文案 25 + 下发去重 5）
- ✅ `flutter analyze` **164 项**，低于改动前基线 166（净减 2：删掉
  选择弹窗里一处 `unnecessary_brace_in_string_interps` + 一处 unused import），
  **无新增，0 error**；剩余 11 条 warning 全在未改动的 `csv_parser` / `diffuse_background`
- ✅ `flutter build apk --release --split-per-abi` 通过，产出 `qianzhike-v2.0.2-*.apk` 三个
- ✅ 全仓 `flutter_local_notifications` / `NativeAlarmService` / `_packId` /
  `advanceMinutes` 零残留（仅注释里提到"已退役"）
- ⚠️ **真机未验证**（待用户实测，按优先级）：
  1. 通知栏是否出现常驻通知（验证权限弹窗生效）
  2. 后台更新是否跟随时间变化
  3. 锁屏与折叠态截断效果

## v2.0.1 — 通知链路与课程表特效修复

一轮以「修缺陷」为主的版本，无新增功能。三处修复：通知投递可靠性、通知图标规范、课程表上课特效残留。

### 1. 通知投递可靠性（`notification_service.dart` / `native_alarm_service.dart` / `MainActivity.kt`）

- ✅ **通知 ID 由哈希改为位编码**：原方案 `'$courseId-reminder-$week'.hashCode.abs()` 是 32 位哈希，
  20 门课 × 20 周 × 2 类 ≈ 800 个 ID 按生日悖论有碰撞风险，两条通知会抢同一槽位互相覆盖；
  且 Dart 字符串 hashCode 每进程播种，同一份代码不同次启动碰撞结果不同，表现为随机漏提醒。
  改为**位编码**（无碰撞是结构性保证）：`bits0-2`=类型, `bits3-14`=课程序号(0..4095),
  `bits15-19`=周次(1..20)，基数 `0x20000000`，全部 ID ≤ `0x20FFE001`，稳在 int32 内且远离前台服务的固定 ID 9000。
- ✅ **`type` 参数链路打通**：`MainActivity.kt` 原本就读 `type`，但 Dart 侧从未传过，恒取默认 `"ongoing"`，
  导致 `setOngoing(true)` 对**每条**通知生效（含「课程提醒」）。
  现为 `reminder`（可划掉 + 有提示音）/ `ongoing`（常驻）/ `dismiss`（静默），未知值降级为 `ongoing`（常驻优先）。
- ✅ **提醒不再提前一周误触发**：`_checkSchedule` 原先对 `[startWeek, endWeek]` 每周都比对 `now`，
  未来周的 `reminderDt` 全部落在过去 → 提前一周弹提醒。现在**只判定当前周次的当天**那一次。

### 2. 通知图标（`ic_stat_course.xml` / `MainActivity.kt` / `CourseForegroundService.kt`）

- ✅ small icon 原用彩色 `@mipmap/ic_launcher`。Android 5.0+ 对 small icon **只取 alpha 通道整体着色**，
  彩色位图会渲染成白色方块（部分 ROM）。新增纯白剪影 `drawable/ic_stat_course.xml`（闹钟），两处均已替换。

### 3. 课程表「正在上课」特效残留（`course.dart` / `schedule_screen.dart`）

**现象**：正在上课时课程卡片有环绕特效；点顶部箭头切到另一周后，同一格子位置的特效依然亮着。

**根因**：`_isOngoing` 只判断「星期几对 + 该节次有定义 + 当前时刻落在时段内」，
**三个条件全部与"哪一周"无关**；而 `_CourseCell` 是 `StatelessWidget`，字段里没有周次信息。
`displayWeek` 已作为参数传进 `_buildScheduleGrid`，只是没往下传。

**修法**（不只是补一个 if）：
- ✅ 提取纯函数 `Course.shouldPulseInGrid({displayedWeek, currentWeek, now})`，三条件显式化：
  显示周==当前周、课程在该周确实有课（覆盖单/双/自定义周）、时钟落在节次内。
  `Course.isOngoingAt(now)` 退化为只回答「时钟是否在节次内」。
- ✅ **消除时段重复定义**：删掉 `_isOngoing` 内联的 `slotTimes` 字典，改用 `TimeSlot`（`course.dart`）
  —— `notification_service` 本来就用 `TimeSlot`，此前同一份时段数据存在两处定义。
- ✅ **收紧语义**：特效只从 `activeCourses` 取（`_primary` 原本按 active→inactive→other 回退，
  会让当前周已过期/未开始的课也亮）。
- ✅ **周次只解析一次**：在 `Consumer2` builder 内取 `sp.currentWeek`，避免 `PageView.builder`
  预构建相邻页时各自调用 `DateTime.now()` 造成帧内不一致。

**开发过程留痕（两次教训）**:
1. `isOngoingAt` 第一版用 `endPeriod` 去查 `TimeSlot.forPeriod`，导致**所有课都判定为非进行中** ——
   `TimeSlot.slots` 只定义 1/3/5/7/9（每个大节的起始节），真实课程存的是 `startPeriod:1 / endPeriod:2`，
   `forPeriod(2)` 返回 null。20 个新测试里 13 个立刻失败才暴露。正确做法：从 `startPeriod` 所在 slot 取开始与结束时间。
2. 改动提醒分支时曾把 `notifyId` 从 `oId` 误改为提醒自己的 `rId`，**破坏了"提醒与「正在上课」共用同一通知槽位"的设计**
   （提醒占用 `oId` → 开课原地替换 → 下课 `cancelNotification(oId)` 移除），
   导致提醒永久驻留通知栏，且被误诊为"提醒天然无生命周期"而加了 `setTimeoutAfter`。
   经用户实测反馈后完全回退。**教训：用户报告行为回归时，先 `git show HEAD:<file>` 对比原始代码，
   而不是基于被自己改过的代码推测设计意图。**

### 验证

- ✅ `flutter test` 全量 **77/77 通过**
- ✅ `flutter analyze` 与改动前基线一致（166 项，全部为既有 info，无新增）
- ✅ 全仓 `timeout` / `setTimeoutAfter` / `reminderLifetime` **零残留**（回退彻底）
- ✅ 新增 23 个测试：通知 ID 8000 组合全量查重 + 位域往返 + 跨进程确定性；通知槽位共享不变量；
  特效周次闸门（`displayedWeek` 取 1/3/5/6/19/20 全部必须 false）+ 节次边界 + 单双周/自定义周

### 真机回归结论

- ✅ 课程表特效：切周次后消失、切回恢复（用户实测通过）
- ✅ 通知图标、可划动行为、提醒自动消失（用户实测通过）





## Project Files
```
lib/
├── main.dart                          # Entry + AppFonts + MultiProvider init + NotificationService.init
├── app.dart                           # MaterialApp + fade routes
├── theme/
│   ├── app_colors.dart                # Color constants (6 course + diffuse + lock screen)
│   ├── app_typography.dart            # Outfit/Inter font styles
│   ├── app_spacing.dart               # Spacing/size constants
│   ├── app_shadows.dart               # Shadow definitions
│   └── app_theme.dart                 # ThemeData composition
├── models/
│   ├── course.dart                    # Course model + WeekMode enum + TimeSlot
│   └── background_preset.dart         # BackgroundPreset + CircleConfig
├── providers/
│   ├── course_provider.dart           # Course CRUD + day/week filtering + notification sync
│   ├── semester_provider.dart         # Semester first day + current week calc
│   └── background_provider.dart       # Preset management
├── services/
│   ├── database_service.dart          # SharedPreferences storage + CSV parse entry + GBK fallback
│   ├── csv_parser.dart                # CSV parser (8-col grid, multi-course cell splitting, header-adaptive columns)
│   ├── preset_storage_service.dart    # Independent preset storage
│   ├── foreground_status.dart         # 常驻通知文案纯函数（周次闸门唯一入口 + 五种状态）
│   ├── notification_service.dart      # 30s 轮询 → 算文案 → 仅变化时推送前台服务
│   ├── foreground_service_manager.dart # Android Foreground Service start/stop/updateStatus
│   ├── edu_extractor.dart             # 教务在线导入: injection JS + Dart parser (kbtable DOM)
│   ├── edu_login_scripts.dart         # 登录页检测/自动填充/输入捕获 JS
│   └── credential_storage_service.dart # 教务账密 Keystore 加密存储
├── widgets/
│   ├── diffuse_background.dart        # Background renderer (auto-loads preset on first build)
│   ├── course_card.dart               # Course card widget
│   ├── course_detail_sheet.dart       # Bottom sheet detail view
│   ├── edit_course_screen_wire.dart   # Add/edit course form wrapper
│   ├── edge_aware_physics.dart        # Inner week PageView physics: at week 1/20 passes swipe outward to parent
│   ├── origami_crane.dart             # 折纸鹤 CustomPaint（cranes.svg 色块重绘，空状态插图）
│   └── settings_row.dart              # Settings row + card widget
└── screens/
    ├── main_screen.dart                # Root scaffold: fade-transition content switcher (home/schedule)
    ├── home_screen.dart               # Today's courses (home)
    ├── schedule_screen.dart           # Schedule grid (PageView, weeks 1-20)
    ├── settings_screen.dart           # Settings (debug notification button removed in v1.2)
    ├── import_screen.dart             # CSV import with preview (also reused by online import)
    ├── edu_webview_screen.dart        # 教务在线导入 WebView (桌面 UA/缩放/记住账密)
    ├── edit_course_screen.dart        # Edit course form
    ├── custom_screen.dart             # Preset management
    ├── circle_edit_screen.dart        # Circle editor
    └── image_edit_screen.dart         # Image editor (viewport preview)
```

## Key Design Decisions
- Storage: SharedPreferences (JSON-serialized), not SQLite
- State: Provider (ChangeNotifier pattern, 3 providers)
- Fonts: google_fonts runtime loading (Outfit + Inter)
- Image params: scale=image width/frame width, offset=fraction of frame
- Week navigation: PageView (1-20), initial page = current week from semester first day
- Background auto-init: DiffuseBackground.load() on first build
- Notifications: single Foreground Service status notification (ID 9000), text computed in Dart, pushed only on change
- Android native: MainActivity (2 MethodChannels: launch/service), CourseForegroundService (specialUse)
