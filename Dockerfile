FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Установка зависимостей
RUN apt update && apt install -y \
    curl \
    gnupg \
    ca-certificates \
    libgtk-3-0 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxcomposite1 \
    libasound2 \
    libxdamage1 \
    libxrandr2 \
    libpulse0 \
    libsecret-1-0 \
    libnotify4 \
    libnss3 \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Добавление репозитория MAX
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.max.ru/linux/deb/public.asc | gpg --dearmor -o /etc/apt/keyrings/max.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/max.gpg] https://download.max.ru/linux/deb stable main" > /etc/apt/sources.list.d/max.list

# Установка MAX
RUN apt update \
    && apt install -y max \
    && apt clean

# Создание пользователя
RUN useradd -m -u 1000 -s /bin/bash user

WORKDIR /home/user
USER user

CMD ["max"]
