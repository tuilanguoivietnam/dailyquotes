import os
from typing import Dict, Any

class SubscriptionConfig:
    """订阅轮询配置"""
    
    # 轮询间隔（秒）
    POLL_INTERVAL = int(os.getenv("SUBSCRIPTION_POLL_INTERVAL", "86400"))  # 默认24小时
    
    # 重试间隔（秒）
    RETRY_INTERVAL = int(os.getenv("SUBSCRIPTION_RETRY_INTERVAL", "60"))  # 默认1分钟
    
    # 最大重试次数
    MAX_RETRIES = int(os.getenv("SUBSCRIPTION_MAX_RETRIES", "3"))
    
    # Apple App Store配置
    APPLE_SHARED_SECRET = os.getenv("APPLE_SHARED_SECRET")
    APPLE_VERIFY_URL = "https://buy.itunes.apple.com/verifyReceipt"
    APPLE_SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt"
    
    # Google Play配置
    GOOGLE_SERVICE_ACCOUNT_FILE = os.getenv("GOOGLE_SERVICE_ACCOUNT_FILE")
    ANDROID_PACKAGE_NAME = os.getenv("ANDROID_PACKAGE_NAME")
    
    # 数据库配置
    MONGO_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
    DATABASE_NAME = os.getenv("DATABASE_NAME", "dailymind")
    
    # 日志配置
    LOG_LEVEL = os.getenv("SUBSCRIPTION_LOG_LEVEL", "INFO")
    
    @classmethod
    def get_apple_config(cls) -> Dict[str, Any]:
        """获取Apple配置"""
        return {
            "shared_secret": cls.APPLE_SHARED_SECRET,
            "verify_url": cls.APPLE_VERIFY_URL,
            "sandbox_url": cls.APPLE_SANDBOX_URL
        }
    
    @classmethod
    def get_google_config(cls) -> Dict[str, Any]:
        """获取Google配置"""
        return {
            "service_account_file": cls.GOOGLE_SERVICE_ACCOUNT_FILE,
            "package_name": cls.ANDROID_PACKAGE_NAME
        }
    
    @classmethod
    def is_google_enabled(cls) -> bool:
        """检查Google服务是否启用"""
        return bool(cls.GOOGLE_SERVICE_ACCOUNT_FILE and cls.ANDROID_PACKAGE_NAME)
    
    @classmethod
    def is_apple_enabled(cls) -> bool:
        """检查Apple服务是否启用"""
        return bool(cls.APPLE_SHARED_SECRET) 