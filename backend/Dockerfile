# 使用 Python 3.11 镜像
FROM python:3.11

# 设置工作目录
WORKDIR /app

# 创建必要的目录
RUN mkdir uploads audio

COPY requirements.txt .

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    supervisor \
    ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir -r requirements.txt

COPY . .
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 8000
EXPOSE 8501

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]