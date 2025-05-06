import base64
import logging
import os
import re
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from contextlib import asynccontextmanager
import asyncio

import requests
from fastapi import FastAPI, UploadFile, File, Form, Body, HTTPException, Response, Query, Request
from fastapi.responses import FileResponse, JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
from bson import ObjectId
from dotenv import load_dotenv
from datetime import datetime, timedelta, timezone
import time
from openai import OpenAI
import uuid
import shutil
from pydantic import BaseModel, Field
from tenacity import retry, stop_after_attempt, wait_exponential
from typing import List, Optional
import uvicorn

# Google API 客户端库
from google.oauth2 import service_account
from googleapiclient.discovery import build
from google.auth.transport.requests import Request as GoogleRequest

DOUBAO_APPID = os.getenv("DOUBAO_APPID")
DOUBAO_TOKEN = os.getenv("DOUBAO_TOKEN")
DOUBAO_URL = "https://openspeech.bytedance.com/api/v1/tts"
DOUBAO_LONG_URL = "https://openspeech.bytedance.com/api/v1/tts_async/submit"
DOUBAO_QUERY_SPEECH = "https://openspeech.bytedance.com/api/v1/tts_async/query"
DOUBAO_CLUSTER = "volcano_tts"  # 一般固定
DOUBAO_API_KEY = os.getenv("DOUBAO_API_KEY")

# 创建日志目录
LOG_DIR = "logs"
os.makedirs(LOG_DIR, exist_ok=True)

# 配置日志记录器
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(LOG_DIR, 'app.log')),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 加载环境变量
load_dotenv()


# 初始化FastAPI应用
# Define the lifespan function
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize the database on startup."""
    await init_db()
    yield


# Initialize FastAPI application with lifespan
app = FastAPI(title="DailyMind API", lifespan=lifespan)

# 添加CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 创建存储目录
UPLOAD_DIR = "uploads"
AUDIO_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "audio")
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(AUDIO_DIR, exist_ok=True)

# 挂载静态文件目录
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")
app.mount("/audio", StaticFiles(directory=AUDIO_DIR), name="audio")

# 连接MongoDB
MONGO_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
client = AsyncIOMotorClient(MONGO_URL)
db = client.dailymind

# 数据库集合
affirmations = db.affirmations
white_noises = db.white_noises
categories = db.categories
modules = db.modules  # 新增模块集合

# 初始化OpenAI
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"), timeout=60.0)


class Affirmation(BaseModel):
    id: Optional[str] = None
    message: str
    category: str
    module_id: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    is_active: bool = True


class WhiteNoise(BaseModel):
    id: Optional[str] = None
    name: str
    category: str
    file_path: str
    module_id: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    is_active: bool = True


class GenerateRequest(BaseModel):
    category: str


class TTSRequest(BaseModel):
    text: str
    lang: Optional[str] = ""


async def init_db():
    """初始化数据库，创建索引"""
    # 为金句集合创建索引
    await affirmations.create_index("category")
    await affirmations.create_index("created_at")
    await affirmations.create_index("module_id")
    await affirmations.create_index([("message", "text")])  # 全文索引

    # 为白噪音集合创建索引
    await white_noises.create_index("name")
    await white_noises.create_index("category")
    await white_noises.create_index("module_id")
    await white_noises.create_index("created_at")

    # 为分类集合创建索引
    await categories.create_index("name")
    await categories.create_index("module_id")
    await categories.create_index("created_at")

    # 为模块集合创建索引
    await modules.create_index("name")
    await modules.create_index("created_at")


@app.get("/")
async def read_root():
    logger.info("访问根路径")
    return {"message": "Welcome to DailyMind API"}


@app.get("/api/health")
async def health_check():
    logger.info("健康检查")
    return {"status": "healthy"}


@app.post("/api/upload")
async def upload_whitenoise(file: UploadFile = File(...), name: str = Form(...), category: str = Form(None),
                            module_name: str = Form(None)):
    logger.info(f"上传白噪音文件：{name}")
    try:
        # 生成唯一文件名
        file_extension = os.path.splitext(file.filename)[1]
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        file_path = os.path.join(AUDIO_DIR, unique_filename)

        # 确保目录存在
        os.makedirs(os.path.dirname(file_path), exist_ok=True)

        # 保存文件
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # 验证文件是否成功保存
        if not os.path.exists(file_path) or os.path.getsize(file_path) == 0:
            logger.error(f"文件保存失败或为空: {file_path}")
            raise HTTPException(status_code=500, detail="文件上传失败")

        logger.info(f"文件成功保存到: {file_path}")

        # 查找模块ID
        module_id = None
        if module_name:
            module = await db.modules.find_one({"name": module_name})
            if module:
                module_id = module["_id"]

        # 文件保存成功后，存储到MongoDB
        whitenoise = {
            "name": name,
            "category": category,
            "file_path": file_path,
            "module_id": str(module_id) if module_id else None,
            "created_at": datetime.now(),
            "is_active": True
        }

        result = await white_noises.insert_one(whitenoise)
        logger.info(f"白噪音记录成功添加到数据库，ID: {result.inserted_id}")

        return {"id": str(whitenoise["_id"]), "name": name}
    except Exception as e:
        logger.error(f"上传白噪音文件失败：{str(e)}")
        # 如果文件已保存但数据库操作失败，删除文件
        if 'file_path' in locals() and os.path.exists(file_path):
            try:
                os.remove(file_path)
                logger.info(f"已删除文件: {file_path}，因为数据库操作失败")
            except:
                pass
        raise


@app.get("/api/whitenoises")
async def get_whitenoises(module_name: Optional[str] = Query(None, description="模块名称"), ):
    logger.info("获取白噪音列表")
    try:
        query = {"is_active": True}
        if module_name:
            module_id = await db.modules.find_one({"name": module_name})
            query["module_id"] = str(module_id["_id"])
        whitenoises = await white_noises.find(query).sort("created_at", -1).to_list(length=None)
        response = []
        for wn in whitenoises:
            response.append({
                "id": str(wn["_id"]),
                "name": wn["name"],
                "file_path": wn["file_path"],
                "created_at": wn["created_at"].isoformat()
            })
        return JSONResponse(
            content=response,
            headers={"Content-Type": "application/json; charset=utf-8"}
        )
    except Exception as e:
        logger.error(f"获取白噪音列表失败：{str(e)}")
        raise


@app.get("/api/whitenoises/{whitenoise_id}/audio")
async def get_whitenoise_audio(whitenoise_id: str):
    logger.info(f"获取白噪音音频：{whitenoise_id}")
    try:
        # 从MongoDB获取白噪音信息
        whitenoise = await white_noises.find_one({"_id": ObjectId(whitenoise_id)})
        if not whitenoise:
            raise HTTPException(status_code=404, detail="白噪音不存在")

        # 检查文件是否存在
        file_path = whitenoise["file_path"]
        if not os.path.exists(file_path):
            logger.error(f"音频文件不存在：{file_path}")
            # 尝试从文件名获取
            file_name = os.path.basename(file_path)
            new_path = os.path.join(AUDIO_DIR, file_name)
            if os.path.exists(new_path):
                file_path = new_path
            else:
                raise HTTPException(status_code=404, detail="音频文件不存在")

        # 返回音频文件
        return FileResponse(
            file_path,
            media_type="audio/mpeg",
            filename=os.path.basename(file_path)
        )
    except Exception as e:
        logger.error(f"获取白噪音音频失败：{str(e)}")
        raise


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=10))
async def generate_speech(text: str, lang: str):
    try:
        # 先从数据库中查询缓存
        cached_tts = await db.tts_cache.find_one({"text": text})
        if cached_tts and os.path.exists(cached_tts["file_path"]):
            logger.info(f"使用缓存的语音文件：{cached_tts['file_path']}")
            return FileResponse(
                cached_tts["file_path"],
                media_type="audio/mpeg",
                headers={"Content-Disposition": f'attachment; filename="{os.path.basename(cached_tts["file_path"])}"'}
            )

        # 如果没有缓存或缓存文件不存在，生成新的音频文件
        file_name = f"{uuid.uuid4()}.mp3"
        audio_file_path = os.path.join(AUDIO_DIR, file_name)

        # 确保音频目录存在
        os.makedirs(AUDIO_DIR, exist_ok=True)

        # 生成语音文件
        result = text_to_speech_gen_base_length(text, audio_file_path, "BV701_streaming", lang)

        # 验证音频文件是否成功生成
        if not os.path.exists(audio_file_path) or os.path.getsize(audio_file_path) == 0:
            raise Exception(f"音频文件生成失败或为空: {audio_file_path}")

        logger.info(f"音频文件成功生成: {audio_file_path}")

        # 音频文件生成成功后，再在数据库中记录 TTS 缓存
        await db.tts_cache.insert_one({
            "text": text,
            "file_path": audio_file_path,
            "created_at": datetime.now()
        })
        logger.info(f"TTS缓存记录已插入数据库")

        return FileResponse(
            audio_file_path,
            media_type="audio/mpeg",
            headers={"Content-Disposition": f'attachment; filename="{file_name}"'}
        )
    except Exception as e:
        logger.error(f"生成语音失败：{str(e)}")
        raise


@app.post("/api/tts")
async def text_to_speech(request: TTSRequest):
    logger.info(f"文本转语音请求：{request.text}")
    try:
        response = await generate_speech(request.text, request.lang)
        return response
    except Exception as e:
        logger.error(f"文本转语音失败：{str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/tts/stream")
async def stream_tts(text: str, lang: str = ""):
    logger.info(f"流式文本转语音：{text}")
    try:
        return await generate_speech(text, lang)
    except Exception as e:
        logger.error(f"流式TTS生成失败: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/affirmations")
async def get_affirmations(
        lang: str = Query("zh", enum=["zh", "en", "ja"]),
        category: Optional[str] = Query(None, description="金句分类"),
        module_name: Optional[str] = Query(None, description="模块名称"),
        limit: int = Query(20, ge=1, le=100, description="返回条数")
):
    query = {"is_active": True, "lang": lang}
    if category:
        category_id = await db.categories.find_one({f"name.{lang}": category})
        if category_id:
            query["category"] = category

    if module_name:
        module = await db.modules.find_one({"name": module_name})
        if module:
            query["module_id"] = str(module["_id"])
    else:
        query["$or"] = [
            {"module_id": None},
            {"module_id": {"$exists": False}}
        ]

    docs = await affirmations.aggregate([
        {"$match": query},
        {"$sample": {"size": limit}}
    ]).to_list(length=limit)
    return [doc["message"] for doc in docs if doc.get("message")]


@app.get("/api/affirmations/daily", response_model=List[Affirmation])
async def get_daily_affirmations(module_name: Optional[str] = None):
    """获取今日金句"""
    try:
        today = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        tomorrow = today + timedelta(days=1)

        query = {
            "is_active": True,
            "created_at": {"$gte": today, "$lt": tomorrow}
        }

        if module_name:
            module = await db.modules.find_one({"name": module_name})
            if module:
                query["module_id"] = str(module["_id"])
        else:
            query["$or"] = [
                {"module_id": None},
                {"module_id": {"$exists": False}}
            ]

        cursor = affirmations.find(query)
        return await cursor.to_list(length=None)
    except Exception as e:
        logger.error(f"获取今日金句失败: {str(e)}")
        raise HTTPException(status_code=500, detail="获取今日金句失败")


@app.get("/api/affirmations/{affirmation_id}", response_model=Affirmation)
async def get_affirmation(affirmation_id: str, lang: str = Query("zh", enum=["zh", "en", "ja"])):
    """获取单个金句（多语言）"""
    try:
        result = await affirmations.find_one({"_id": ObjectId(affirmation_id)})
        if result is None:
            raise HTTPException(status_code=404, detail="金句不存在")
        cat = result.get("category", {})
        msg = result.get("message", {})
        if isinstance(cat, dict):
            cat_val = cat.get(lang, cat.get("zh", ""))
        else:
            cat_val = cat
        if isinstance(msg, dict):
            msg_val = msg.get(lang, msg.get("zh", msg))
        else:
            msg_val = msg
        return {
            "id": str(result.get("_id")),
            "category": cat_val,
            "message": msg_val,
            "created_at": result.get("created_at").isoformat() if result.get("created_at") else None
        }
    except Exception as e:
        logger.error(f"获取金句失败: {str(e)}")
        raise HTTPException(status_code=500, detail="获取金句失败")


@app.get("/api/white-noises", response_model=List[WhiteNoise])
async def get_white_noises(
        category: Optional[str] = None,
        limit: int = Query(10, ge=1, le=100),
        skip: int = Query(0, ge=0)
):
    """获取白噪音列表"""
    try:
        query = {"is_active": True}
        if category:
            query["category"] = category

        cursor = white_noises.find(query).sort("created_at", -1).skip(skip).limit(limit)
        return await cursor.to_list(length=None)
    except Exception as e:
        logger.error(f"获取白噪音列表失败: {str(e)}")
        raise HTTPException(status_code=500, detail="获取白噪音列表失败")


@app.get("/api/white-noises/{white_noise_id}", response_model=WhiteNoise)
async def get_white_noise(white_noise_id: str):
    """获取单个白噪音"""
    try:
        result = await white_noises.find_one({"_id": ObjectId(white_noise_id)})
        if result is None:
            raise HTTPException(status_code=404, detail="白噪音不存在")
        return result
    except Exception as e:
        logger.error(f"获取白噪音失败: {str(e)}")
        raise HTTPException(status_code=500, detail="获取白噪音失败")


@app.get("/api/categories/affirmations")
async def get_affirmation_categories(lang: str = Query("zh", enum=["zh", "en", "ja"])):
    """获取所有金句类别（多语言）"""
    try:
        # 假设有 categories 集合
        if "categories" in db.list_collection_names():
            categories = await db.categories.find().to_list(length=None)
            return {
                "categories": [
                    c.get("name", {}).get(lang, c.get("name", {}).get("zh", ""))
                    for c in categories
                ]
            }
        else:
            # 兼容无 categories 集合的情况，从 affirmations 里 distinct
            cats = await affirmations.distinct(f"category.{lang}")
            return {"categories": cats}
    except Exception as e:
        logger.error(f"获取金句类别失败: {str(e)}")
        raise HTTPException(status_code=500, detail="获取金句类别失败")


@app.get("/api/categories/white-noises")
async def get_white_noise_categories():
    """获取所有白噪音类别"""
    try:
        categories = await white_noises.distinct("category")
        return {"categories": categories}
    except Exception as e:
        logger.error(f"获取白噪音类别失败: {str(e)}")
        raise HTTPException(status_code=500, detail="获取白噪音类别失败")


@app.get("/api/categories")
async def get_categories(lang: str = Query("zh", enum=["zh", "en", "ja"]), module_name: Optional[str] = None):
    """获取所有分类（多语言）"""
    try:
        query = {"is_active": True}
        if module_name:
            module = await db.modules.find_one({"name": module_name})
            if module:
                query["module_id"] = str(module["_id"])
        else:
            query["$or"] = [
                {"module_id": None},
                {"module_id": {"$exists": False}}
            ]

        cursor = categories.find(query).sort("created_at", 1)
        all_categories = await cursor.to_list(length=None)

        # 添加"全部"选项
        response = []

        # 添加其他分类
        for cat in all_categories:
            response.append({
                "id": str(cat["_id"]),
                "name": cat["name"]
            })

        return response
    except Exception as e:
        logger.error(f"获取分类列表失败: {str(e)}")
        raise HTTPException(status_code=500, detail="获取分类列表失败")


@app.post("/api/categories")
async def create_category(category: dict):
    """创建新分类"""
    try:
        doc = {
            "name": category["name"],
            "module_id": category.get("module_id"),
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
            "is_active": True
        }
        result = await categories.insert_one(doc)
        return {"id": str(result.inserted_id)}
    except Exception as e:
        logger.error(f"创建分类失败: {str(e)}")
        raise HTTPException(status_code=500, detail="创建分类失败")


@app.put("/api/categories/{category_id}")
async def update_category(category_id: str, category: dict):
    """更新分类"""
    try:
        update = {
            "name": category["name"],
            "updated_at": datetime.now(timezone.utc)
        }

        # 如果提供了模块ID，则更新
        if "module_id" in category:
            update["module_id"] = category["module_id"]

        result = await categories.update_one(
            {"_id": ObjectId(category_id)},
            {"$set": update}
        )
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="分类不存在")
        return {"status": "success"}
    except Exception as e:
        logger.error(f"更新分类失败: {str(e)}")
        raise HTTPException(status_code=500, detail="更新分类失败")


@app.delete("/api/categories/{category_id}")
async def delete_category(category_id: str):
    """删除分类"""
    try:
        result = await categories.delete_one({"_id": ObjectId(category_id)})
        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="分类不存在")
        return {"status": "success"}
    except Exception as e:
        logger.error(f"删除分类失败: {str(e)}")
        raise HTTPException(status_code=500, detail="删除分类失败")


# 模块管理API
@app.get("/api/modules")
async def get_modules():
    """获取所有模块"""
    try:
        cursor = modules.find({"is_active": True}).sort("created_at", -1)
        all_modules = await cursor.to_list(length=None)
        response = []
        for module in all_modules:
            response.append({
                "id": str(module["_id"]),
                "name": module["name"],
                "created_at": module["created_at"].isoformat() if "created_at" in module else None
            })
        return response
    except Exception as e:
        logger.error(f"获取模块列表失败: {str(e)}")
        raise HTTPException(status_code=500, detail="获取模块列表失败")


@app.post("/api/modules")
async def create_module(module: dict):
    """创建新模块"""
    try:
        doc = {
            "name": module["name"],
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
            "is_active": True
        }
        result = await modules.insert_one(doc)
        return {"id": str(result.inserted_id)}
    except Exception as e:
        logger.error(f"创建模块失败: {str(e)}")
        raise HTTPException(status_code=500, detail="创建模块失败")


@app.put("/api/modules/{module_id}")
async def update_module(module_id: str, module: dict):
    """更新模块"""
    try:
        update = {
            "name": module["name"],
            "updated_at": datetime.now(timezone.utc)
        }
        result = await modules.update_one(
            {"_id": ObjectId(module_id)},
            {"$set": update}
        )
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="模块不存在")
        return {"status": "success"}
    except Exception as e:
        logger.error(f"更新模块失败: {str(e)}")
        raise HTTPException(status_code=500, detail="更新模块失败")


@app.delete("/api/modules/{module_id}")
async def delete_module(module_id: str):
    """删除模块"""
    try:
        # 检查是否有关联数据
        aff_count = await affirmations.count_documents({"module_id": module_id})
        cat_count = await categories.count_documents({"module_id": module_id})
        wn_count = await white_noises.count_documents({"module_id": module_id})

        if aff_count > 0 or cat_count > 0 or wn_count > 0:
            raise HTTPException(
                status_code=400,
                detail=f"该模块下有关联数据，无法删除：金句({aff_count})、分类({cat_count})、白噪音({wn_count})"
            )

        result = await modules.delete_one({"_id": ObjectId(module_id)})
        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="模块不存在")
        return {"status": "success"}
    except HTTPException as e:
        # 直接抛出已经格式化的HTTP异常
        raise
    except Exception as e:
        logger.error(f"删除模块失败: {str(e)}")
        raise HTTPException(status_code=500, detail="删除模块失败")


@app.post("/api/verify-google-receipt")
async def verify_google_receipt(
        receipt_data: str = Body(...),
        product_id: str = Body(...),
        purchase_token: Optional[str] = Body(None),
        is_restore: bool = Body(False)
):
    """验证Google Play收据并返回订阅信息"""
    logger.info(f"验证Google收据: 产品ID {product_id}, 购买令牌: {purchase_token}")
    # os.environ["http_proxy"] = "http://127.0.0.1:10809"
    # os.environ["https_proxy"] = "http://127.0.0.1:10809"
    # os.environ["all_proxy"] = "socks5://127.0.0.1:10809"
    try:
        # 使用Google API客户端库验证购买令牌
        # 从环境变量获取服务账号配置
        project_id = os.getenv("GOOGLE_SERVICE_ACCOUNT_PROJECT_ID")
        private_key_id = os.getenv("GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY_ID")
        private_key = os.getenv("GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY")
        client_email = os.getenv("GOOGLE_SERVICE_ACCOUNT_CLIENT_EMAIL")
        client_id = os.getenv("GOOGLE_SERVICE_ACCOUNT_CLIENT_ID")
        package_name = os.getenv("ANDROID_PACKAGE_NAME")

        if not all([project_id, private_key, client_email, package_name]):
            logger.warning("Google服务账号环境变量配置不完整，使用模拟验证")
            # 如果没有配置服务账号，使用模拟验证
            is_valid = True
        else:
            # 从环境变量创建服务账号信息
            service_account_info = {
                "type": "service_account",
                "project_id": project_id,
                "private_key_id": private_key_id,
                "private_key": private_key,
                "client_email": client_email,
                "client_id": client_id,
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
                "client_x509_cert_url": f"https://www.googleapis.com/robot/v1/metadata/x509/{client_email}",
                "universe_domain": "googleapis.com"
            }

            # 创建凭证
            credentials = service_account.Credentials.from_service_account_info(
                service_account_info,
                scopes=['https://www.googleapis.com/auth/androidpublisher']
            )

            # 构建Android Publisher API客户端
            android_publisher = build('androidpublisher', 'v3', credentials=credentials)

            # 使用实际的purchase_token进行验证
            token = purchase_token or receipt_data

            try:
                # 验证订阅购买
                purchase_response = android_publisher.purchases().subscriptionsv2().get(
                    packageName=package_name,
                    token=token
                ).execute()

                logger.info(f"Google Play API响应: {purchase_response}")

                # 检查订阅状态
                # 0: 已付款，1: 已取消，2: 待定，3: 已过期
                payment_state = purchase_response.get('subscriptionState', "SUBSCRIPTION_STATE_ACTIVE")
                is_valid = payment_state == 'SUBSCRIPTION_STATE_ACTIVE'

                line_items = purchase_response.get('lineItems', [])
                for line_item in line_items:
                    if line_item.get('productId') == product_id:
                        expires_date = datetime.strptime(line_item.get("expiryTime"), '%Y-%m-%dT%H:%M:%S.%fZ').replace(tzinfo=timezone.utc)
                        auto_renew_status = line_item.get('autoRenewingPlan').get('autoRenewEnabled', False)
                        latest_successful_order_id = line_item.get('latestSuccessfulOrderId')

            except Exception as api_error:
                logger.error(f"调用Google Play API时出错: {str(api_error)}")
                is_valid = False

        if not is_valid:
            logger.error("Google收据验证失败")
            return {"valid": False, "error": "验证失败"}

        # 解析订阅信息
        if 'expires_date' in locals():
            # 如果有API响应，使用API返回的数据
            expires_date = expires_date
            auto_renew_status = auto_renew_status
        else:
            # 模拟数据（仅用于测试或未配置服务账号时）
            expires_date = datetime.now(timezone.utc) + timedelta(days=30)
            auto_renew_status = True

        # 检查过期时间
        now = datetime.now(timezone.utc)
        is_active = expires_date > now

        # 存储订阅信息
        subscription_id = latest_successful_order_id or f"google_{int(datetime.now().timestamp())}"

        await db.subscriptions.update_one(
            {"subscription_id": subscription_id},
            {
                "$set": {
                    "product_id": product_id,
                    "purchase_token": purchase_token,
                    "expires_date": expires_date,
                    "is_active": is_active,
                    "auto_renew_status": auto_renew_status,
                    "platform": "google",
                    "updated_at": datetime.now(timezone.utc)
                }
            },
            upsert=True
        )

        return {
            "valid": True,
            "subscription_id": subscription_id,
            "product_id": product_id,
            "expires_date": expires_date.isoformat(),
            "is_active": is_active,
            "auto_renew_status": auto_renew_status
        }

    except Exception as e:
        logger.error(f"验证Google收据时出错: {str(e)}")
        raise HTTPException(status_code=500, detail=f"验证Google收据失败: {str(e)}")


@app.post("/api/verify-receipt")
async def verify_ios_receipt(
        receipt_data: str = Body(...),
        product_id: str = Body(...),
        transaction_id: Optional[str] = Body(None)
):
    """验证iOS收据并返回订阅信息"""
    logger.info(f"验证iOS收据: 产品ID {product_id}")

    try:
        # 先尝试在正式环境验证
        verify_url = "https://buy.itunes.apple.com/verifyReceipt"
        response = await verify_receipt_with_apple(verify_url, receipt_data)

        # 如果是沙盒收据，切换到沙盒环境验证
        if response.get("status") == 21007:
            verify_url = "https://sandbox.itunes.apple.com/verifyReceipt"
            response = await verify_receipt_with_apple(verify_url, receipt_data)

        # 检查验证状态
        if response.get("status") != 0:
            logger.error(f"收据验证失败: {response.get('status')}")
            return {"valid": False, "error": f"验证失败: {response.get('status')}"}

        # 获取最新的订阅信息
        latest_receipt_info = get_subscription_expiry_info(response, product_id)
        print(f"latest_receipt_info: {latest_receipt_info}")

        if not latest_receipt_info:
            return {"valid": False, "error": "未找到有效的订阅信息"}

        # 解析到期时间
        expires_date_ms = int(latest_receipt_info.get("expires_date_ms", "0"))
        expires_date = datetime.fromtimestamp(expires_date_ms / 1000, timezone.utc)

        # 检查是否已取消订阅
        auto_renew_status = latest_receipt_info.get("auto_renew_status") == "1"

        # 检查过期时间
        now = datetime.now(timezone.utc)
        is_active = expires_date > now

        # 存储订阅信息
        subscription_id = latest_receipt_info.get(
            "original_transaction_id") or transaction_id or f"apple_{int(datetime.now().timestamp())}"

        await db.subscriptions.update_one(
            {"subscription_id": subscription_id},
            {
                "$set": {
                    "product_id": product_id,
                    "receipt_data": receipt_data,
                    "expires_date": expires_date,
                    "is_active": is_active,
                    "auto_renew_status": auto_renew_status,
                    "updated_at": datetime.now(timezone.utc)
                }
            },
            upsert=True
        )

        return {
            "valid": True,
            "subscription_id": subscription_id,
            "product_id": product_id,
            "expires_date": expires_date.isoformat(),
            "is_active": is_active,
            "auto_renew_status": auto_renew_status
        }

    except Exception as e:
        logger.error(f"验证收据时出错: {str(e)}")
        raise HTTPException(status_code=500, detail=f"验证收据失败: {str(e)}")


async def verify_receipt_with_apple(verify_url: str, receipt_data: str):
    """向Apple发送验证请求"""
    shared_secret = os.getenv("APPLE_SHARED_SECRET")
    if not shared_secret:
        logger.error("Missing APPLE_SHARED_SECRET environment variable")
        raise HTTPException(status_code=500, detail="Server configuration error")

    # 构建请求体
    request_body = {
        "receipt-data": receipt_data,
        "password": shared_secret,  # 只有在服务端才安全
        "exclude-old-transactions": False  # 获取所有交易记录
    }

    # 发送请求到Apple
    response = requests.post(verify_url, json=request_body, timeout=30)
    return response.json()


def get_subscription_expiry_info(response: dict, product_id: str):
    """从验证响应中获取最新的到期信息"""
    matching_transactions = []

    # 从latest_receipt_info获取
    if "latest_receipt_info" in response:
        latest_matching = [
            trans for trans in response["latest_receipt_info"]
            if trans.get("product_id") == product_id
        ]
        matching_transactions.extend(latest_matching)

    # 从in_app字段寻找（不使用elif，确保两个来源都被检查）
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
            logger.error(f"排序订阅交易时出错: {str(e)}")
            # 如果排序失败，至少返回第一个匹配的交易
            return matching_transactions[0] if matching_transactions else None

    return None


# 添加订阅状态检查端点
@app.get("/api/check-subscription/{subscription_id}")
async def check_subscription(subscription_id: str):
    """检查订阅状态"""
    try:
        subscription = await db.subscriptions.find_one({"subscription_id": subscription_id})

        if not subscription:
            return {"is_active": False, "error": "订阅不存在"}

        # 检查当前时间是否超过到期时间
        now = datetime.now(timezone.utc)
        expires_date = subscription.get("expires_date")

        # 确保 expires_date 是 timezone-aware
        if expires_date and expires_date.tzinfo is None:
            expires_date = expires_date.replace(tzinfo=timezone.utc)

        is_active = expires_date > now if expires_date else False

        # 如果已过期，更新状态
        if not is_active and subscription.get("is_active", False):
            await db.subscriptions.update_one(
                {"subscription_id": subscription_id},
                {"$set": {"is_active": False}}
            )

        return {
            "is_active": is_active,
            "expires_date": expires_date.isoformat() if expires_date else None,
            "auto_renew_status": subscription.get("auto_renew_status", False)
        }

    except Exception as e:
        logger.error(f"检查订阅状态失败: {str(e)}")
        raise HTTPException(status_code=500, detail="检查订阅状态失败")


def text_to_speech_gen_base_length(text: str, output_file: str, tone: str, lang: str) -> any:
    try:
        if len(text.encode('utf-8')) > 1024:
            logger.warning(f"文本长度超过限制，将进行分割处理。当前长度：{len(text.encode('utf-8'))}")

            # 分割文本
            def split_text_for_tts(text, max_bytes=1024):
                segments = []
                current_segment = ""

                # 按句子分割
                sentences = re.split('([。！？.!?])', text)
                for i in range(0, len(sentences), 2):
                    sentence = sentences[i] + (sentences[i + 1] if i + 1 < len(sentences) else '')
                    test_segment = current_segment + sentence

                    if len(test_segment.encode('utf-8')) <= max_bytes:
                        current_segment = test_segment
                    else:
                        if current_segment:
                            segments.append(current_segment)
                        current_segment = sentence

                if current_segment:
                    segments.append(current_segment)
                return segments

            # 并行处理语音合成
            def process_segment(segment, idx):
                output_filename = f"output_temp_{str(uuid.uuid4())[:8]}_{idx}.mp3"
                output_path = os.path.join(audio_folder, output_filename)
                result = text_to_speech_gen(segment, output_path, tone, lang)
                if not result or result == "":
                    raise Exception(f"Failed to convert segment {idx} to speech")
                return {
                    "path": output_path,
                    "duration": result.get("duration")
                }

            base_dir = os.path.dirname(__file__)
            audio_folder = os.path.join(base_dir, 'audio')
            os.makedirs(audio_folder, exist_ok=True)

            # 分割文本并并行处理
            segments = split_text_for_tts(text)
            segment_results = [None] * len(segments)

            with ThreadPoolExecutor(max_workers=5) as executor:
                future_to_idx = {
                    executor.submit(process_segment, segment, idx): idx
                    for idx, segment in enumerate(segments)
                }

                for future in as_completed(future_to_idx):
                    idx = future_to_idx[future]
                    try:
                        result = future.result()
                        segment_results[idx] = result
                    except Exception as e:
                        logger.error(f"处理文本片段 {idx} 失败: {str(e)}")
                        raise Exception(f"Error processing segment {idx}: {str(e)}")

            # 合并音频文件
            from pydub import AudioSegment
            combined = AudioSegment.empty()
            total_duration = 0

            for result in segment_results:
                if result is None:
                    continue
                audio = AudioSegment.from_mp3(result["path"])
                combined += audio
                # 确保 duration 是数值类型
                duration = result.get("duration")
                if isinstance(duration, str):
                    try:
                        duration = float(duration)
                    except (ValueError, TypeError):
                        duration = 0
                total_duration += duration
                # 删除临时文件
                os.remove(result["path"])

            combined.export(output_file, format="mp3")

            # 验证合并后的音频文件
            if not os.path.exists(output_file) or os.path.getsize(output_file) == 0:
                raise Exception(f"Failed to generate combined audio file: {output_file}")

            logger.info(f"成功合成长文本音频: {output_file}")
            return {"path": output_file, "duration": total_duration}
        else:
            result = text_to_speech_gen(text, output_file, tone, lang)
            if not result:
                raise Exception(f"Failed to convert text to speech")
            return result
    except Exception as e:
        logger.error(f"文本转语音失败: {str(e)}")
        # 如果输出文件已经创建，但是处理失败，删除它
        if os.path.exists(output_file):
            try:
                os.remove(output_file)
                logger.info(f"已删除不完整的音频文件: {output_file}")
            except:
                pass
        raise


def text_to_speech_gen(chinese_text: str, output_file: str, tone: str, lang: str) -> any:
    """
    调用豆包大模型 TTS (HTTP接口) 把文本合成音频。
    返回生成的文件路径，如果失败则返回空字符串。
    """
    if not chinese_text:
        logger.warning("尝试转换空文本为语音")
        return ""

    try:
        # -- 1. 构建请求体
        # "voice_type"、"encoding"、"speed_ratio"可按需调整
        # "reqid" 需唯一，可用 uuid
        reqid = str(uuid.uuid4())

        # 这里示例使用 mp3; 如果想要 wav/pcm/ogg_opus，请改 "encoding"
        request_body = {
            "app": {
                "appid": DOUBAO_APPID,
                "token": DOUBAO_TOKEN,
                "cluster": DOUBAO_CLUSTER
            },
            "user": {
                "uid": "demo_uid"
            },
            "audio": {
                "voice_type": tone,  # 语气
                "encoding": "mp3",
                "speed_ratio": 0.9
            },
            "request": {
                "reqid": reqid,
                "text": chinese_text,
                "operation": "query"  # HTTP只能用query方式
            }
        }

        if lang and lang != "":
            request_body["audio"]["language"] = "cn" if lang == "zh" else lang
            request_body["audio"][
                "voice_type"] = "BV001_streaming" if lang == "zh" else "BV503_streaming" if lang == "en" else "BV522_streaming"

        if lang != "ja":
            request_body["audio"]["emotion"] = "comfort"

        # -- 2. 发起 HTTP POST 请求
        headers = {
            "Content-Type": "application/json",
            # 注意这里是 Bearer; 与 token 用分号分隔
            "Authorization": f"Bearer; {DOUBAO_TOKEN}"
        }

        logger.debug(f"正在请求TTS接口: {len(chinese_text)}字符")
        resp = requests.post(
            DOUBAO_URL,
            json=request_body,
            headers=headers,
            timeout=15
        )

        # -- 3. 检查返回结果
        if resp.status_code != 200:
            logger.error(f"TTS接口HTTP状态码非200: {resp.status_code}, body={resp.text}")
            return ""

        result = resp.json()

        # 豆包 TTS 成功时 code=3000, sequence=-1 并带有 data(音频的base64)
        code = result.get("code", -1)
        if code != 3000:
            logger.error(f"TTS接口返回错误码: {code}, message={result.get('message')}")
            return ""

        # 这里 sequence=-1 表示合成完毕(一次性返回全部)
        audio_b64 = result.get("data")
        if not audio_b64:
            logger.error("返回JSON中不包含data字段，或为空")
            return ""

        # -- 4. 把base64音频解码写入文件
        audio_data = base64.b64decode(audio_b64)
        with open(output_file, "wb") as f:
            f.write(audio_data)

        # 验证文件是否成功写入
        if not os.path.exists(output_file) or os.path.getsize(output_file) == 0:
            logger.error(f"音频文件写入失败或为空: {output_file}")
            return ""

        logger.debug(f"成功生成音频: {output_file}")
        return {
            "path": output_file,
            "duration": result.get("addition", {}).get("duration", 0)
        }
    except Exception as e:
        logger.error(f"TTS生成过程中出现异常: {str(e)}")
        # 清理可能生成的不完整文件
        if os.path.exists(output_file):
            try:
                os.remove(output_file)
                logger.debug(f"已删除不完整的音频文件: {output_file}")
            except:
                pass
        return ""


# 苹果App Store Server Notifications处理端点
@app.post("/api/apple-subscription-notifications")
async def handle_apple_subscription_notifications(request: Request):
    """处理来自Apple App Store的订阅状态通知"""
    try:
        # 获取原始请求体
        payload = await request.json()
        logger.info(f"收到Apple订阅通知: {payload}")
        
        # 验证通知的有效性
        # 在生产环境中，应该验证通知的签名
        
        # 解析通知类型
        notification_type = payload.get("notification_type")
        
        # 处理不同类型的通知
        if "unified_receipt" in payload:
            # 处理V2版本通知
            notification_data = payload.get("unified_receipt", {})
            latest_receipt_info = notification_data.get("latest_receipt_info", [])
            
            if latest_receipt_info and len(latest_receipt_info) > 0:
                # 获取最新的收据信息
                latest_info = latest_receipt_info[0]
                
                # 提取关键信息
                product_id = latest_info.get("product_id")
                original_transaction_id = latest_info.get("original_transaction_id")
                expires_date_ms = int(latest_info.get("expires_date_ms", "0"))
                expires_date = datetime.fromtimestamp(expires_date_ms / 1000, timezone.utc)
                auto_renew_status = latest_info.get("auto_renew_status") == "1"
                
                # 检查过期时间
                now = datetime.now(timezone.utc)
                is_active = expires_date > now
                
                # 更新数据库中的订阅信息
                await db.subscriptions.update_one(
                    {"subscription_id": original_transaction_id},
                    {
                        "$set": {
                            "product_id": product_id,
                            "expires_date": expires_date,
                            "is_active": is_active,
                            "auto_renew_status": auto_renew_status,
                            "platform": "apple",
                            "updated_at": datetime.now(timezone.utc),
                            "last_notification_type": notification_type
                        }
                    },
                    upsert=True
                )
                
                logger.info(f"已更新Apple订阅状态: {original_transaction_id}, 产品: {product_id}, 有效期至: {expires_date}, 自动续订: {auto_renew_status}")
        
        return {"status": "success"}
    
    except Exception as e:
        logger.error(f"处理Apple订阅通知时出错: {str(e)}")
        # 返回200状态码，避免Apple重复发送通知
        return {"status": "error", "message": str(e)}


# 谷歌Play实时开发者通知处理端点
@app.post("/api/google-subscription-notifications")
async def handle_google_subscription_notifications(request: Request):
    """处理来自Google Play的订阅状态通知"""
    try:
        # 获取原始请求体
        payload = await request.json()
        logger.info(f"收到Google订阅通知: {payload}")
        
        # 验证通知的有效性
        # 在生产环境中，应该验证通知的签名
        
        # 解析通知数据
        message_data = payload.get("message", {}).get("data", "")
        if not message_data:
            return {"status": "error", "message": "无效的通知数据"}
        
        # 解码Base64数据
        try:
            decoded_data = base64.b64decode(message_data).decode('utf-8')
            notification_data = json.loads(decoded_data)
        except Exception as e:
            logger.error(f"解析Google通知数据失败: {str(e)}")
            return {"status": "error", "message": f"解析通知数据失败: {str(e)}"}
        
        # 处理订阅通知
        if "subscriptionNotification" in notification_data:
            subscription_notification = notification_data.get("subscriptionNotification", {})
            notification_type = subscription_notification.get("notificationType")
            purchase_token = subscription_notification.get("purchaseToken")
            
            if not purchase_token:
                return {"status": "error", "message": "通知中没有购买令牌"}
            
            # 获取包名
            package_name = notification_data.get("packageName")
            
            # 根据通知类型处理
            # 1: 已恢复 2: 已续订 3: 已取消 4: 已购买
            is_active = notification_type in [1, 2, 4]
            auto_renew_status = notification_type in [1, 2, 4]
            
            # 使用Google Play Developer API获取订阅详情
            # 这里需要实现调用Google API的逻辑，获取订阅的详细信息
            # 包括产品ID、到期时间等
            
            # 临时解决方案：从数据库查询现有订阅信息
            existing_subscription = await db.subscriptions.find_one({"purchase_token": purchase_token})
            
            if existing_subscription:
                # 更新现有订阅
                await db.subscriptions.update_one(
                    {"purchase_token": purchase_token},
                    {
                        "$set": {
                            "is_active": is_active,
                            "auto_renew_status": auto_renew_status,
                            "updated_at": datetime.now(timezone.utc),
                            "last_notification_type": notification_type
                        }
                    }
                )
                logger.info(f"已更新Google订阅状态: {purchase_token}, 通知类型: {notification_type}")
            else:
                # 记录未知的购买令牌
                await db.unknown_tokens.insert_one({
                    "purchase_token": purchase_token,
                    "package_name": package_name,
                    "notification_type": notification_type,
                    "created_at": datetime.now(timezone.utc)
                })
                logger.warning(f"收到未知购买令牌的通知: {purchase_token}")
        
        return {"status": "success"}
    
    except Exception as e:
        logger.error(f"处理Google订阅通知时出错: {str(e)}")
        # 返回200状态码，避免Google重复发送通知
        return {"status": "error", "message": str(e)}


# 手动触发订阅轮询的API端点
@app.post("/api/admin/poll-subscriptions")
async def manual_poll_subscriptions():
    """手动触发订阅状态轮询"""
    try:
        from subscription_polling import poller
        await poller._poll_all_subscriptions()
        return {"status": "success", "message": "订阅轮询已完成"}
    except Exception as e:
        logger.error(f"手动轮询订阅失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"轮询失败: {str(e)}")


@app.get("/api/admin/subscription-stats")
async def get_subscription_stats():
    """获取订阅统计信息"""
    try:
        # 统计活跃订阅数量
        active_count = await db.subscriptions.count_documents({"is_active": True})
        
        # 统计各平台订阅数量
        apple_count = await db.subscriptions.count_documents({
            "is_active": True, 
            "platform": "apple"
        })
        google_count = await db.subscriptions.count_documents({
            "is_active": True, 
            "platform": "google"
        })
        
        # 统计最近24小时内的轮询次数
        yesterday = datetime.now(timezone.utc) - timedelta(days=1)
        recent_polls = await db.subscriptions.count_documents({
            "last_polled_at": {"$gte": yesterday}
        })
        
        return {
            "total_active": active_count,
            "apple_subscriptions": apple_count,
            "google_subscriptions": google_count,
            "recent_polls_24h": recent_polls
        }
    except Exception as e:
        logger.error(f"获取订阅统计失败: {str(e)}")
        raise HTTPException(status_code=500, detail="获取统计失败")


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
