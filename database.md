# DailyMind 数据库设计

## 数据库类型
- MongoDB
- 数据库名：dailymind

## 主要集合
### 1. affirmations（金句）
- _id: ObjectId
- category: string 金句类别（如"综合"、"健康"等）
- message: string 金句内容
- created_at: datetime 创建时间
- updated_at: datetime
- is_active: bool
- device_uuid: str  # 关联设备
- 说明：前端自动本地缓存，支持每日定时本地通知推送

### 2. white_noises（白噪音）
- _id: ObjectId
- name: string 名称
- category: string 类别
- file_path: string 文件路径
- created_at: datetime 创建时间
- updated_at: datetime 更新时间
- is_active: bool 是否有效
- device_uuid: str  # 关联设备
- 说明：前端自动本地缓存，支持循环播放

### 3. favorites（收藏）
- _id: ObjectId
- device_uuid: str
- type: str  # affirmation/white_noise
- target_id: str
- created_at: datetime

## 索引
- category
- created_at
- is_active
- device_uuid

## 关系说明
- 所有数据均与 device_uuid 关联，无用户表
- 收藏/历史记录通过 device_uuid + target_id 唯一

## 维护策略
- 定期清理无效/过期数据
- 定期备份
- 索引优化

## 推荐系统（预留）
- 可基于 device_uuid 的行为数据做内容推荐
- 可扩展推荐表/日志表

## 其他说明
- 所有时间均为UTC，ISO格式
- affirmations/white_noises 支持本地缓存与定时推送
- 详细结构可参考models.py、前端models目录

# 数据库与本地存储结构

本项目前端主要使用 Hive 进行本地持久化。

## Hive Box 说明
- `favorites`：收藏的金句（FavoriteAffirmation）
- `affirmations`：全部金句（Affirmation）
- `history`：历史浏览记录（HistoryAffirmation，含国际化时间）
- `guide`：引导页状态（bool）
- `theme`：主题设置（String）
- `whitenoises`：白噪音（WhiteNoise）
- `language`：当前语言（String，'system'/'zh'/'en'/'ja'）
- `volume_settings`：音量设置（TTS/白噪音，double）
- `settings`：存储推送提醒开关与时间等设置

## 其它
- 设置、通知时间等通过 StorageService 以 key-value 方式本地存储
- 详见 lib/models/ 与 lib/services/ 

## Hive 本地表
- favorites: List<String>，存储收藏金句，最新在顶部
- affirmations: Affirmation，金句对象
- whitenoises: WhiteNoise，白噪音对象

## 已移除
- 历史相关表 