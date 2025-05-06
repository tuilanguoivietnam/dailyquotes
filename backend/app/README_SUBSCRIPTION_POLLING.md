# 订阅状态轮询系统

## 概述

本系统提供了两种订阅状态监控方式：

1. **Webhook通知方式**（推荐）：Apple和Google主动推送订阅状态变化
2. **轮询方式**：定期检查所有订阅状态

## 费用分析

### Webhook通知方式
- **Apple App Store Server Notifications**: 免费
- **Google Play Real-time Developer Notifications**: 免费
- **优势**: 实时性好，无额外费用，减少服务器负载
- **劣势**: 需要配置HTTPS端点，可能因网络问题丢失通知

### 轮询方式
- **Apple App Store API**: 免费（但有速率限制）
- **Google Play Developer API**: 免费（但有配额限制）
- **优势**: 更可靠，可以主动检查状态
- **劣势**: 需要定期调用API，可能产生延迟

## 配置

### 环境变量

```bash
# 轮询配置
SUBSCRIPTION_POLL_INTERVAL=21600  # 轮询间隔（秒），默认6小时
SUBSCRIPTION_RETRY_INTERVAL=60    # 重试间隔（秒），默认1分钟
SUBSCRIPTION_MAX_RETRIES=3        # 最大重试次数
SUBSCRIPTION_LOG_LEVEL=INFO       # 日志级别

# Apple配置
APPLE_SHARED_SECRET=your_shared_secret

# Google配置
GOOGLE_SERVICE_ACCOUNT_FILE=/path/to/service-account.json
ANDROID_PACKAGE_NAME=com.your.app

# 数据库配置
MONGODB_URL=mongodb://localhost:27017
DATABASE_NAME=dailymind
```

## 使用方法

### 1. 自动轮询（推荐）

系统会在启动时自动开始轮询任务：

```python
# 在main.py的lifespan函数中已集成
@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    
    # 启动订阅轮询任务
    from subscription_polling import start_polling, stop_polling
    asyncio.create_task(start_polling())
    
    yield
    
    # 停止订阅轮询任务
    await stop_polling()
```

### 2. 手动触发轮询

```bash
# 手动触发轮询
curl -X POST http://localhost:8000/api/admin/poll-subscriptions

# 获取订阅统计
curl http://localhost:8000/api/admin/subscription-stats
```

### 3. 独立运行轮询任务

```bash
# 直接运行轮询任务
python subscription_polling.py
```

## API端点

### 手动轮询
- `POST /api/admin/poll-subscriptions`: 手动触发订阅状态轮询

### 统计信息
- `GET /api/admin/subscription-stats`: 获取订阅统计信息

返回格式：
```json
{
  "total_active": 10,
  "apple_subscriptions": 6,
  "google_subscriptions": 4,
  "recent_polls_24h": 15
}
```

## 数据库结构

### subscriptions集合
```javascript
{
  "_id": ObjectId,
  "subscription_id": "string",           // 订阅ID
  "product_id": "string",                // 产品ID
  "platform": "apple|google",            // 平台
  "expires_date": ISODate,               // 到期时间
  "is_active": boolean,                  // 是否活跃
  "auto_renew_status": boolean,          // 自动续订状态
  "purchase_token": "string",            // Google购买令牌
  "created_at": ISODate,                 // 创建时间
  "updated_at": ISODate,                 // 更新时间
  "last_polled_at": ISODate,            // 最后轮询时间
  "last_notification_type": "string"     // 最后通知类型
}
```

## 监控和日志

### 日志文件
- 轮询任务日志会记录到应用日志中
- 可以通过`SUBSCRIPTION_LOG_LEVEL`环境变量调整日志级别

### 监控指标
- 活跃订阅数量
- 各平台订阅分布
- 轮询频率和成功率
- 订阅状态变化趋势

## 最佳实践

### 1. 混合使用
- 主要依赖Webhook通知（实时性好）
- 轮询作为备用方案（可靠性高）
- 定期手动触发轮询检查

### 2. 配置优化
- 根据订阅数量调整轮询间隔
- 设置合理的重试策略
- 监控API调用频率，避免超出限制

### 3. 错误处理
- 网络错误时自动重试
- 记录详细的错误日志
- 设置告警机制

### 4. 性能优化
- 批量处理订阅检查
- 使用连接池
- 合理设置超时时间

## 故障排除

### 常见问题

1. **轮询任务未启动**
   - 检查环境变量配置
   - 查看应用启动日志

2. **API调用失败**
   - 检查网络连接
   - 验证API密钥配置
   - 查看错误日志

3. **数据库连接失败**
   - 检查MongoDB连接
   - 验证数据库权限

### 调试命令

```bash
# 检查轮询任务状态
curl http://localhost:8000/api/admin/subscription-stats

# 手动触发轮询
curl -X POST http://localhost:8000/api/admin/poll-subscriptions

# 查看应用日志
tail -f logs/app.log
``` 