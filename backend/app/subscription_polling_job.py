import asyncio
import logging
import os
import time
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any
import aiohttp
import json
import base64

from motor.motor_asyncio import AsyncIOMotorClient
from google.oauth2 import service_account
from googleapiclient.discovery import build
from google.auth.transport.requests import Request as GoogleRequest

from dotenv import load_dotenv
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

# 加载环境变量
load_dotenv()

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 数据库连接
MONGO_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
client = AsyncIOMotorClient(MONGO_URL)
db = client.dailymind

# Apple App Store配置
APPLE_SHARED_SECRET = os.getenv("APPLE_SHARED_SECRET", "e9e15a945e8849e8bb50fc7b76afcb8e")

# Google Play配置
GOOGLE_SERVICE_ACCOUNT_FILE = os.getenv("GOOGLE_SERVICE_ACCOUNT_FILE")
ANDROID_PACKAGE_NAME = os.getenv("ANDROID_PACKAGE_NAME")


class SubscriptionPollingJob:
    """订阅状态轮询任务"""

    def __init__(self):
        self.session = None
        self.google_service = None

    async def start(self):
        # 创建HTTP会话
        self.session = aiohttp.ClientSession()

        # 初始化Google服务
        await self._init_google_service()

        try:
            await self._poll_subscriptions()
        except Exception as e:
            logger.error(f"轮询任务出错: {str(e)}")
        finally:
            if self.session:
                await self.session.close()

    async def stop(self):
        """停止轮询任务"""
        logger.info("停止订阅状态轮询任务")

    async def _init_google_service(self):
        """初始化Google Play API服务"""
        try:
            if GOOGLE_SERVICE_ACCOUNT_FILE and os.path.exists(GOOGLE_SERVICE_ACCOUNT_FILE):
                credentials = service_account.Credentials.from_service_account_file(
                    GOOGLE_SERVICE_ACCOUNT_FILE,
                    scopes=['https://www.googleapis.com/auth/androidpublisher']
                )
                self.google_service = build('androidpublisher', 'v3', credentials=credentials)
                logger.info("Google Play API服务初始化成功")
            else:
                logger.warning("Google服务账号文件不存在，跳过Google订阅检查")
        except Exception as e:
            logger.error(f"初始化Google服务失败: {str(e)}")

    async def _poll_subscriptions(self):
        """轮询所有订阅状态"""
        try:
            logger.info("开始轮询订阅状态")

            # 获取所有活跃订阅
            subscriptions = await db.subscriptions.find({
                "is_active": True
            }).to_list(length=None)

            logger.info(f"找到 {len(subscriptions)} 个活跃订阅")

            for subscription in subscriptions:
                try:
                    await self._check_single_subscription(subscription)
                except Exception as e:
                    logger.error(f"检查订阅 {subscription.get('subscription_id')} 失败: {str(e)}")

            logger.info("订阅状态轮询完成")

        except Exception as e:
            logger.error(f"轮询订阅状态失败: {str(e)}")

    async def _check_single_subscription(self, subscription: Dict[str, Any]):
        """检查单个订阅状态"""
        subscription_id = subscription.get("subscription_id")
        platform = subscription.get("platform", "unknown")

        if platform == "apple":
            await self._check_apple_subscription(subscription)
        elif platform == "google":
            await self._check_google_subscription(subscription)
        else:
            logger.warning(f"未知平台订阅: {subscription_id}, 平台: {platform}")

    async def _check_apple_subscription(self, subscription: Dict[str, Any]):
        """检查Apple订阅状态"""
        subscription_id = subscription.get("subscription_id")
        product_id = subscription.get("product_id")

        if not subscription_id or not product_id:
            logger.warning(f"Apple订阅信息不完整: {subscription_id}")
            return

        try:
            # 这里需要从数据库获取收据数据
            receipt_data = await self._get_receipt_data(subscription_id)

            if not receipt_data:
                logger.warning(f"未找到Apple订阅收据数据: {subscription_id}")
                return

            # 验证收据
            verify_url = "https://buy.itunes.apple.com/verifyReceipt"
            response = await self._verify_apple_receipt(verify_url, receipt_data)

            # 如果是沙盒收据，切换到沙盒环境验证
            if response.get("status") == 21007:
                verify_url = "https://sandbox.itunes.apple.com/verifyReceipt"
                response = await self._verify_apple_receipt(verify_url, receipt_data)

            if response.get("status") != 0:
                logger.error(f"Apple收据验证失败: {response.get('status')}")
                await self._update_subscription_status(subscription_id, False)
                return

            # 获取最新的订阅信息
            latest_info = self._get_apple_subscription_info(response, product_id)

            if not latest_info:
                logger.warning(f"未找到Apple订阅信息: {subscription_id}")
                await self._update_subscription_status(subscription_id, False)
                return

            # 解析到期时间
            expires_date_ms = int(latest_info.get("expires_date_ms", "0"))
            expires_date = datetime.fromtimestamp(expires_date_ms / 1000, timezone.utc)

            # 检查是否已取消订阅
            auto_renew_status = latest_info.get("auto_renew_status") == "1"

            # 检查过期时间
            now = datetime.now(timezone.utc)
            is_active = expires_date > now

            # 更新订阅状态
            await self._update_subscription_status(
                subscription_id,
                is_active,
                expires_date,
                auto_renew_status
            )

            logger.info(f"Apple订阅状态已更新: {subscription_id}, 活跃: {is_active}")

        except Exception as e:
            logger.error(f"检查Apple订阅失败: {str(e)}")

    async def _check_google_subscription(self, subscription: Dict[str, Any]):
        """检查Google订阅状态"""
        subscription_id = subscription.get("subscription_id")
        purchase_token = subscription.get("purchase_token")

        if not self.google_service:
            logger.warning("Google服务未初始化，跳过Google订阅检查")
            return

        if not purchase_token:
            logger.warning(f"Google订阅缺少购买令牌: {subscription_id}")
            return

        try:
            # 使用Google Play API获取订阅详情
            purchase_response = self.google_service.purchases().subscriptionsv2().get(
                packageName=ANDROID_PACKAGE_NAME,
                token=purchase_token
            ).execute()

            # 检查订阅状态
            subscription_state = purchase_response.get('subscriptionState', "SUBSCRIPTION_STATE_ACTIVE")
            is_active = subscription_state == 'SUBSCRIPTION_STATE_ACTIVE'

            # 获取到期时间
            line_items = purchase_response.get('lineItems', [])
            expires_date = None
            auto_renew_status = False

            for line_item in line_items:
                if line_item.get('productId') == subscription.get('product_id'):
                    expires_date_str = line_item.get("expiryTime")
                    if expires_date_str:
                        expires_date = datetime.strptime(
                            expires_date_str,
                            '%Y-%m-%dT%H:%M:%S.%fZ'
                        ).replace(tzinfo=timezone.utc)

                    auto_renew_plan = line_item.get('autoRenewingPlan', {})
                    auto_renew_status = auto_renew_plan.get('autoRenewEnabled', False)
                    break

            # 更新订阅状态
            await self._update_subscription_status(
                subscription_id,
                is_active,
                expires_date,
                auto_renew_status
            )

            logger.info(f"Google订阅状态已更新: {subscription_id}, 活跃: {is_active}")

        except Exception as e:
            logger.error(f"检查Google订阅失败: {str(e)}")

    async def _verify_apple_receipt(self, verify_url: str, receipt_data: str) -> Dict[str, Any]:
        """向Apple发送验证请求"""
        request_body = {
            "receipt-data": receipt_data,
            "password": APPLE_SHARED_SECRET,
            "exclude-old-transactions": False
        }

        async with self.session.post(verify_url, json=request_body) as response:
            return await response.json()

    def _get_apple_subscription_info(self, response: Dict[str, Any], product_id: str) -> Dict[str, Any]:
        """从Apple验证响应中获取最新的订阅信息"""
        matching_transactions = []

        # 从latest_receipt_info获取
        if "latest_receipt_info" in response:
            latest_matching = [
                trans for trans in response["latest_receipt_info"]
                if trans.get("product_id") == product_id
            ]
            matching_transactions.extend(latest_matching)

        # 从in_app字段寻找
        if "receipt" in response and "in_app" in response["receipt"]:
            inapp_matching = [
                trans for trans in response["receipt"]["in_app"]
                if trans.get("product_id") == product_id
            ]
            matching_transactions.extend(inapp_matching)

        if matching_transactions:
            # 按照到期时间排序，获取最新的一条
            try:
                return sorted(
                    matching_transactions,
                    key=lambda x: int(x.get("expires_date_ms", "0")),
                    reverse=True
                )[0]
            except (ValueError, TypeError) as e:
                logger.error(f"排序Apple订阅交易时出错: {str(e)}")
                return matching_transactions[0] if matching_transactions else None

        return None

    async def _get_receipt_data(self, subscription_id: str) -> str:
        """从数据库获取收据数据"""
        # 这里应该从数据库获取保存的收据数据
        receipt_doc = await db.receipts.find_one({"subscription_id": subscription_id})
        return receipt_doc.get("receipt_data") if receipt_doc else None

    async def _update_subscription_status(
            self,
            subscription_id: str,
            is_active: bool,
            expires_date: datetime = None,
            auto_renew_status: bool = None
    ):
        """更新订阅状态"""
        update_data = {
            "is_active": is_active,
            "updated_at": datetime.now(timezone.utc),
            "last_polled_at": datetime.now(timezone.utc)
        }

        if expires_date:
            update_data["expires_date"] = expires_date

        if auto_renew_status is not None:
            update_data["auto_renew_status"] = auto_renew_status

        await db.subscriptions.update_one(
            {"subscription_id": subscription_id},
            {"$set": update_data}
        )

    async def manual_check_subscription(self, subscription_id: str):
        """手动检查指定订阅状态"""
        try:
            subscription = await db.subscriptions.find_one({"subscription_id": subscription_id})
            if not subscription:
                logger.error(f"订阅不存在: {subscription_id}")
                return False

            await self._check_single_subscription(subscription)
            return True

        except Exception as e:
            logger.error(f"手动检查订阅失败: {str(e)}")
            return False


# 创建全局轮询任务实例
polling_job = SubscriptionPollingJob()


async def start_polling_job():
    """启动轮询任务"""
    await polling_job.start()


async def stop_polling_job():
    """停止轮询任务"""
    await polling_job.stop()


async def manual_check_subscription(subscription_id: str):
    """手动检查订阅状态"""
    return await polling_job.manual_check_subscription(subscription_id)


# 如果直接运行此文件，启动轮询任务
# if __name__ == "__main__":
#     asyncio.run(start_polling_job())

if __name__ == "__main__":
    async def main():
        # 先立即执行一次
        await start_polling_job()
        # 启动定时任务
        scheduler = AsyncIOScheduler()
        scheduler.add_job(lambda: asyncio.create_task(start_polling_job()), CronTrigger(hour=0, minute=0))
        scheduler.start()
        print("订阅轮询定时任务已启动，每天00:00执行一次。")
        while True:
            await asyncio.sleep(3600)

    asyncio.run(main())
