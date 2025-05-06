# API接口文档（apis.md）

## 金句相关

### 获取金句列表（分页、随机、按类别）
- `GET /api/affirmations?category=综合&limit=15`
- 参数：
  - category：金句类别（必选）
  - limit：每次返回条数，默认15
- 返回：
```
{
  "total": 100,
  "items": [
    {"id": "...", "category": "...", "message": "...", "created_at": "..."}
  ]
}
```

### 生成一条金句（随机一条，主要用于"换一句"）
- `POST /api/generate`
- body: `{ "category": "综合" }`
- 返回：`{"message": "..."}`

### TTS语音合成
- `POST /api/tts`
- body: `{ "text": "..." }`
- 返回：音频二进制流（audio/mpeg）

## 白噪音相关

### 获取白噪音列表
- `GET /api/whitenoises`
- 返回：
```
[
  {"id": "...", "name": "...", "category": "...", "file_path": "...", ...}
]
```

### 获取白噪音音频
- `GET /api/whitenoises/{id}/audio`
- 返回：音频二进制流
- 说明：前端播放时自动循环（ReleaseMode.loop），支持本地缓存

### 上传白噪音
- `POST /api/upload`
- form-data: file, name, category
- 返回：`{"id": "...", "name": "..."}`

## 管理后台相关（Streamlit）
- 支持金句、白噪音的增删改查、文件上传、日志查看，详见admin端UI

## 认证与安全
- 当前API无登录鉴权，后续可扩展

## 其他
- 所有接口均返回标准JSON或二进制流，错误时返回HTTP错误码和错误信息

## 收藏/历史
### POST /api/favorites
- 添加收藏
- 参数：device_uuid, type, target_id

### GET /api/favorites
- 查询收藏列表
- 参数：device_uuid, type

### POST /api/histories
- 添加历史记录
- 参数：device_uuid, type, target_id

### GET /api/histories
- 查询历史记录
- 参数：device_uuid, type

## 推荐系统（预留）
### GET /api/recommendations
- 获取推荐内容
- 参数：device_uuid, type

## 错误处理
- 所有接口返回统一错误格式：
```
{
  "error": true,
  "message": "错误描述"
}
```
- 常见错误码：400, 401, 404, 500

## 状态码
- 200: 成功
- 201: 创建成功
- 400: 请求错误
- 401: 未授权
- 403: 禁止访问
- 404: 资源不存在
- 500: 服务器错误

## 注意事项
1. 所有时间字段使用UTC时间
2. 文件上传大小限制为10MB
3. 支持的音频格式：mp3, wav
4. 请求频率限制：每分钟100次
5. 所有删除操作均为软删除
6. 金句/白噪音均支持本地缓存，前端可离线访问
7. 支持每日定时本地通知推送

# APIs & Provider接口说明

本项目前端主要通过 Riverpod Provider 管理状态，未直接调用远程API。

## 主要 Provider
- `affirmationProvider`：当前金句TTS播放与状态，支持音量调节
- `affirmationListProvider`：金句分页与分类加载
- `whitenoiseProvider`：白噪音列表与播放状态，支持音量调节
- `favoritesProvider`：收藏夹管理
- `historyProvider`：历史记录管理，支持国际化时间显示
- `themeProvider`：主题切换
- `languageProvider`：多语言切换与持久化
- `volumeProvider`：音量设置（TTS/白噪音，实时生效）

## 本地服务
- `StorageService`：本地设置、通知时间等持久化
- `NotificationService`：本地通知推送
- `ShareService`：内容分享

## 说明
- 所有Provider均为Riverpod实现，详见 `lib/providers/`
- 本地服务详见 `lib/services/`
- 音量调节和历史时间显示均已国际化 

# APIs 说明

## Affirmation 金句
- GET /api/affirmations?lang=zh&category=xxx&limit=15
  - 获取金句列表，支持多语言和分类

## 收藏
- 本地 Hive box: 'favorites'
  - 通过 favoritesProvider 管理，最新收藏在顶部

## 白噪音
- GET /api/whitenoise
  - 获取白噪音列表

## 已移除
- 历史相关 API 

## 推送提醒
- 本地推送由 NotificationService 统一管理，支持 Android/iOS/macOS 定时推送
- macOS 需初始化时区（flutter_timezone） 

## 通知服务 (NotificationService)

### 初始化
```dart
Future<void> initialize()
```
- 初始化通知服务
- 设置时区
- 配置 iOS/macOS 和 Android 的通知设置

### 权限请求
```dart
Future<bool> requestPermission()
```
- 请求通知权限
- 返回是否获得权限

### 清除 Badge
```dart
Future<void> clearBadge()
```
- 清除应用图标上的通知计数
- 在应用启动和通知点击时调用

### 显示通知
```dart
Future<void> showNotification(String title, String body, {String? payload})
```
- 立即显示一条通知
- 参数：
  - title: 通知标题
  - body: 通知内容
  - payload: 可选的数据负载

### 设置定时通知
```dart
Future<void> scheduleMultipleNotifications(String startTime, {bool enabled = true})
```
- 设置每两小时一次的通知
- 参数：
  - startTime: 开始时间（格式：HH:mm）
  - enabled: 是否启用通知
- 特点：
  - 从指定时间开始，每两小时推送一次
  - 一天最多推送8次
  - 每次推送随机选择一条金句

### 通知点击处理
```dart
void _onNotificationTapped(NotificationResponse response)
```
- 处理通知点击事件
- 清除 badge 计数

## 分类管理

### CategoryProvider
```dart
final categoryProvider = StateNotifierProvider<CategoryNotifier, String>
```

#### 方法
1. `setCategory(String category)`
   - 设置新的分类
   - 自动保存到 Hive
   - 更新 Provider 状态

2. `currentCategory`
   - 获取当前选中的分类
   - 返回类型：String

#### 使用示例
```dart
// 监听分类变化
final category = ref.watch(categoryProvider);

// 切换分类
ref.read(categoryProvider.notifier).setCategory('新分类');
```

### 通知集成
- 通知内容会根据当前选择的分类自动更新
- 通知 payload 包含分类信息
- 点击通知时记录分类信息 

## 字体大小设置
- 无需后端API，全部本地存储
- 使用 Hive 存储字体大小设置
- 由 fontSizeProvider 统一管理 

- 无 SharedPreferences，所有本地设置均由 Hive 存储。 