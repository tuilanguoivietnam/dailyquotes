#!/bin/bash

# 停止之前的进程
echo "正在停止之前的进程..."
pkill -f "uvicorn app.main:app" || true
pkill -f "streamlit run admin/app.py" || true

# 等待进程完全停止
sleep 2

# 创建必要的目录
echo "创建必要的目录..."
mkdir -p logs
mkdir -p audio
mkdir -p admin/static

# 激活虚拟环境
source venv/bin/activate

# 设置代理
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890

# 启动API服务
echo "正在启动API服务..."
PYTHONPATH=$PYTHONPATH:$(pwd) uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &

# 等待API服务启动
sleep 2


echo "服务已启动："
echo "API服务: http://localhost:8000"
