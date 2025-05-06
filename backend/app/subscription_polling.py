import asyncio
import logging
import os
from datetime import datetime, timezone
from motor.motor_asyncio import AsyncIOMotorClient
import aiohttp
from subscription_config import SubscriptionConfig

logger = logging.getLogger(__name__)

# 数据库连接
client = AsyncIOMotorClient(SubscriptionConfig.MONGO_URL)
db = client[SubscriptionConfig.DATABASE_NAME]

class SubscriptionPoller:
    def __init__(self):
        self.is_running = False
        self.session = None
    
    async def start(self):
        """启动轮询任务"""
        self.is_running = True
        self.session = aiohttp.ClientSession()
        logger.info("订阅轮询任务已启动")
        
        while self.is_running:
            try:
                await self._poll_all_subscriptions()
                # 使用配置的轮询间隔
                await asyncio.sleep(SubscriptionConfig.POLL_INTERVAL)
            except Exception as e:
                logger.error(f"轮询任务出错: {e}")
                # 使用配置的重试间隔
                await asyncio.sleep(SubscriptionConfig.RETRY_INTERVAL)
    
    async def stop(self):
        """停止轮询任务"""
        self.is_running = False
        if self.session:
            await self.session.close()
        logger.info("订阅轮询任务已停止")
    
    async def _poll_all_subscriptions(self):
        """轮询所有活跃订阅"""
        try:
            # 获取所有活跃订阅
            subscriptions = await db.subscriptions.find({
                "is_active": True
            }).to_list(length=None)
            
            logger.info(f"检查 {len(subscriptions)} 个活跃订阅")
            
            for sub in subscriptions:
                await self._check_subscription(sub)
                
        except Exception as e:
            logger.error(f"轮询订阅失败: {e}")
    
    async def _check_subscription(self, subscription):
        """检查单个订阅状态"""
        try:
            subscription_id = subscription.get("subscription_id")
            platform = subscription.get("platform", "unknown")
            
            if platform == "apple" and SubscriptionConfig.is_apple_enabled():
                await self._check_apple_subscription(subscription)
            elif platform == "google" and SubscriptionConfig.is_google_enabled():
                await self._check_google_subscription(subscription)
            else:
                logger.warning(f"跳过未知平台或未启用的平台: {platform}")
                
        except Exception as e:
            logger.error(f"检查订阅 {subscription.get('subscription_id')} 失败: {e}")
    
    async def _check_apple_subscription(self, subscription):
        """检查Apple订阅状态"""
        subscription_id = subscription.get("subscription_id")
        logger.info(f"检查Apple订阅: {subscription_id}")
        
        # 更新最后检查时间
        await db.subscriptions.update_one(
            {"subscription_id": subscription_id},
            {"$set": {"last_polled_at": datetime.now(timezone.utc)}}
        )
    
    async def _check_google_subscription(self, subscription):
        """检查Google订阅状态"""
        subscription_id = subscription.get("subscription_id")
        logger.info(f"检查Google订阅: {subscription_id}")
        
        # 更新最后检查时间
        await db.subscriptions.update_one(
            {"subscription_id": subscription_id},
            {"$set": {"last_polled_at": datetime.now(timezone.utc)}}
        )

# 全局轮询器实例
poller = SubscriptionPoller()

async def start_polling():
    """启动轮询任务"""
    await poller.start()

async def stop_polling():
    """停止轮询任务"""
    await poller.stop()

if __name__ == "__main__":
    asyncio.run(start_polling()) 