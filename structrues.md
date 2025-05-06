# 项目结构说明

## 主要目录
- lib/main.dart：应用入口，初始化 Provider、EasyLocalization、Hive
- lib/app.dart：全局主题、配色、国际化、引导
- lib/pages/：页面（如 home_page.dart, favorites_page.dart 等）
- lib/providers/：状态管理（如 favorites_provider.dart, theme_provider.dart 等）
- assets/lang/：多语言 json 文件

## 主要状态
- favoritesProvider：金句收藏，最新在顶部
- themeProvider/colorSchemeProvider：主题与配色
- languageProvider：多语言

## 已移除
- 历史相关 provider、页面、model

## 顶层结构
```
backend/         # 后端API与管理后台
  app/           # FastAPI主服务
  admin/         # Streamlit管理后台
  audio/         # 白噪音音频文件
  uploads/       # 上传文件目录
  logs/          # 日志目录
  venv/          # Python虚拟环境
frontend/        # Flutter前端
  assets/        # 资源文件
    lang/        # 多语言包（zh.json, en.json, ja.json）
    fonts/       # 字体文件
  lib/           # 源代码（pages, providers, services, models, widgets, utils）
    pages/       # 页面（home, favorites, history, theme, settings等）
    providers/   # Riverpod 状态管理（含音量、语言、历史等）
    models/      # 数据模型
    services/    # 本地存储、通知、分享等服务
    utils/       # 工具类
  logs/          # 前端日志
  pubspec.yaml   # 依赖与资源声明
readme.md        # 项目说明
structrues.md    # 结构说明
apis.md          # API接口文档
database.md      # 数据库结构
design.md        # 设计说明
todos.md         # 任务清单
bugs.md          # 已知问题

## backend 结构
- app/：FastAPI主服务，包含主入口、API接口、数据库模型、业务逻辑
- admin/：Streamlit管理后台，支持金句和白噪音的增删改查、文件上传、日志查看
- audio/：白噪音音频文件目录
- uploads/：上传文件目录
- logs/：日志目录
- venv/：Python虚拟环境

## frontend 结构
- assets/
  - lang/：多语言包（zh.json, en.json, ja.json）
  - fonts/：字体文件
- lib/
  - pages/：各页面（首页、收藏、历史、主题、设置等）
  - providers/：Riverpod状态管理（如affirmation、whitenoise、volume等）
  - models/：数据模型
  - services/：本地存储、通知、分享等服务
  - widgets/：通用组件
  - utils/：工具函数
- logs/：前端日志
- pubspec.yaml：依赖与资源声明

## 主要模块说明
- 金句管理：批量加载、分页、TTS、收藏、历史、本地缓存、每日定时通知
- 白噪音管理：上传、播放、分类、本地缓存、循环播放
- 用户体验：动画、主题、响应式布局、UI修复
- 管理后台：Streamlit实现，支持内容管理、文件上传、日志
- 日志系统：backend/logs/、frontend/logs/
- 静态文件服务：backend/admin/static/
- 主题/引导：lib/providers/theme_provider.dart、lib/pages/guide_page.dart

## 结构说明
- 设备标识系统：所有端均以UUID为唯一标识，无用户系统
- 音频缓存/预加载：前端lib/services/audio_cache_service.dart（预留）
- 推荐系统：后端api/models/recommend.py（预留）
- 收藏/历史/偏好：前端lib/models/、lib/services/，后端数据库favorites/histories
- 日志系统：backend/logs/、frontend/logs/
- 静态文件服务：backend/admin/static/
- 主题/引导：lib/providers/theme_provider.dart、lib/pages/guide_page.dart

## 开发规范
- 详见 readme.md、design.md 

- 所有页面和弹窗均已国际化，支持多语言切换
- 状态管理采用 Riverpod，音量调节、历史等均为 Provider 管理
- 本地存储用 Hive
- 日志目录 logs/ 便于调试和问题追踪 

- services/notification_service.dart：本地推送服务，初始化时区，支持所有平台定时推送（macOS 需 flutter_timezone） 

## 组件结构补充

- AffirmationCard
  - 新增 fontSize 参数（double?）
  - 由 home_page.dart 读取 fontSizeProvider 并传递
  - 字号映射 small=28, medium=36, large=44 

- 已无 SharedPreferences 相关内容，所有本地设置均走 Hive。 