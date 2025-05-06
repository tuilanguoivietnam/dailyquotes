import asyncio
from motor.motor_asyncio import AsyncIOMotorClient

async def clear_affirmations():
    client = AsyncIOMotorClient('mongodb://localhost:27017')
    result = await client.dailymind.affirmations.delete_many({})
    print(f"已删除 {result.deleted_count} 条金句记录")
    await client.close()

if __name__ == "__main__":
    asyncio.run(clear_affirmations()) 