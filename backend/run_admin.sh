#!/bin/bash

# 激活虚拟环境
source venv/bin/activate
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
# 设置Python路径（使用绝对路径）
export PYTHONPATH="/Users/edwinhao/dailymind/backend:$PYTHONPATH"
pip3 install --upgrade streamlit
# 运行Streamlit应用
cd /Users/edwinhao/dailymind/backend/admin
streamlit run app.py 