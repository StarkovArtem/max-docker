#!/bin/bash

set -e

echo "========================================="
echo "Установка MAX Messenger в Docker"
echo "========================================="

# Функция для проверки и установки Docker
install_docker() {
    echo "Docker не найден. Начинаю установку Docker Engine и Docker Compose..."
    
    # Проверка ОС (скрипт оптимизирован для Ubuntu/Debian)
    if ! command -v apt-get &> /dev/null; then
        echo "✗ Ошибка: Скрипт поддерживает только Ubuntu/Debian системы"
        echo "Пожалуйста, установите Docker вручную: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # Удаление старых версий
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Установка зависимостей
    sudo apt-get update
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common
    
    # Добавление официального GPG ключа Docker
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Определение версии ОС для репозитория Docker
    source /etc/os-release
    if [[ "$ID" == "debian" ]]; then
        DOCKER_REPO_URL="https://download.docker.com/linux/debian"
        CODENAME="$VERSION_CODENAME"
    else
        DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu"
        CODENAME="$(lsb_release -cs)"
    fi
    
    # Добавление репозитория Docker
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $DOCKER_REPO_URL \
      $CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Установка Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Добавление текущего пользователя в группу docker
    sudo usermod -aG docker $USER
    
    echo "✓ Docker успешно установлен!"
    DOCKER_GROUP_ADDED=true
}

# Функция для проверки прав Docker
check_docker_permissions() {
    if ! docker ps &> /dev/null; then
        echo ""
        echo "⚠ Проблема: Нет прав доступа к Docker сокету"
        echo ""
        
        # Проверяем, существует ли группа docker
        if getent group docker &> /dev/null; then
            echo "Группа 'docker' существует. Добавляем пользователя $USER в группу..."
            sudo usermod -aG docker $USER
            DOCKER_GROUP_ADDED=true
            echo "✓ Пользователь добавлен в группу docker"
            echo ""
            echo "⚠ ВАЖНО: Изменения вступят в силу после перезагрузки сессии."
            echo "Выполните одну из команд:"
            echo "  newgrp docker    # для текущей сессии"
            echo "  или перезагрузитесь"
            echo ""
            read -p "Продолжить установку с sudo? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                USE_SUDO=true
            else
                echo "Установка прервана. Выполните 'newgrp docker' и запустите скрипт снова."
                exit 1
            fi
        else
            echo "Группа 'docker' не найдена. Возможно, Docker установлен некорректно."
            exit 1
        fi
    else
        echo "✓ Права доступа к Docker OK"
    fi
}

# 1. Проверка и установка Docker
if ! command -v docker &> /dev/null; then
    install_docker
else
    echo "✓ Docker уже установлен"
fi

# Проверка Docker Compose (plugin version)
if ! docker compose version &> /dev/null 2>&1; then
    echo "Docker Compose Plugin не найден, устанавливаю..."
    sudo apt-get install -y docker-compose-plugin
fi

echo "✓ Docker и Docker Compose готовы к работе"

# Проверка прав доступа
check_docker_permissions

# 2. Проверка, установлен ли уже MAX
if command -v max &> /dev/null; then
    echo ""
    echo "✓ MAX Messenger уже установлен в системе"
    read -p "Переустановить? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Пропускаем установку MAX, продолжаем с настройкой Docker..."
        SKIP_MAX_INSTALL=true
    fi
fi

# 3. Добавление официального репозитория MAX (если нужна установка)
if [ -z "$SKIP_MAX_INSTALL" ]; then
    echo ""
    echo "Добавление репозитория MAX Messenger..."
    
    sudo mkdir -p /etc/apt/keyrings
    
    # Импорт GPG ключа
    if curl -fsSL https://download.max.ru/linux/deb/public.asc | sudo gpg --dearmor -o /etc/apt/keyrings/max.gpg 2>/dev/null; then
        echo "✓ GPG ключ MAX импортирован"
    else
        echo "✗ Ошибка: Не удалось загрузить GPG ключ MAX"
        echo "Проверьте доступность https://download.max.ru/linux/deb/public.asc"
        echo ""
        echo "Возможные решения:"
        echo "  1. Проверьте подключение к интернету"
        echo "  2. Если вы в России, возможно, требуется VPN"
        echo "  3. Скачайте .deb файл вручную с https://max.ru/download"
        exit 1
    fi
    
    # Добавление источника
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/max.gpg] https://download.max.ru/linux/deb stable main" | sudo tee /etc/apt/sources.list.d/max.list > /dev/null
    echo "✓ Репозиторий MAX добавлен"
    
    # Обновление индексов и установка MAX
    echo ""
    echo "Установка MAX Messenger из официального репозитория..."
    if ! sudo apt update 2>/dev/null; then
        echo "✗ Ошибка: Не удалось обновить индексы пакетов"
        echo "Проверьте доступность репозитория https://download.max.ru/linux/deb"
        exit 1
    fi
    
    if sudo apt install -y max; then
        echo "✓ MAX Messenger успешно установлен"
    else
        echo "✗ Ошибка при установке MAX"
        echo "Проверьте доступность репозитория https://download.max.ru/linux/deb"
        echo ""
        echo "Альтернативный вариант:"
        echo "  1. Скачайте .deb файл с https://max.ru/download"
        echo "  2. Установите его вручную: sudo dpkg -i max.deb"
        echo "  3. Затем снова запустите этот скрипт"
        exit 1
    fi
else
    echo ""
    echo "✓ Используем уже установленный MAX Messenger"
fi

# 4. Проверка наличия docker-compose.yml
if [ ! -f "docker-compose.yml" ]; then
    echo "✗ Ошибка: docker-compose.yml не найден в текущей директории"
    echo "Убедитесь, что вы запускаете скрипт из корня проекта max-docker"
    exit 1
fi

# 5. Сборка Docker образа (с исправлением предупреждения о version)
echo ""
echo "Сборка Docker образа MAX Messenger..."

# Создаем временный docker-compose.yml без version (или игнорируем предупреждение)
if [ -f "docker-compose.yml" ]; then
    # Заменяем docker-compose.yml на версию без version (опционально)
    if grep -q "^version:" docker-compose.yml; then
        echo "⚠ Обнаружена устаревшая директива 'version' в docker-compose.yml"
        echo "  Это предупреждение не влияет на работу, но для чистоты можно удалить строку 'version:'"
    fi
    
    # Сборка с sudo если нужно
    if [ "$USE_SUDO" = true ]; then
        if sudo docker compose build; then
            echo "✓ Docker образ успешно собран (с sudo)"
        else
            echo "✗ Ошибка при сборке Docker образа"
            exit 1
        fi
    else
        if docker compose build; then
            echo "✓ Docker образ успешно собран"
        else
            echo "✗ Ошибка при сборке Docker образа"
            exit 1
        fi
    fi
fi

# 6. Создание ярлыка (если существует скрипт)
if [ -f "scripts/create-desktop.sh" ]; then
    echo ""
    echo "Создание ярлыка в меню приложений..."
    if ./scripts/create-desktop.sh; then
        echo "✓ Ярлык создан"
    else
        echo "⚠ Внимание: Не удалось создать ярлык, но установка продолжена"
    fi
else
    echo "⚠ Скрипт create-desktop.sh не найден, ярлык не создан"
fi

# 7. Финальная проверка группы Docker
echo ""
if [ "$DOCKER_GROUP_ADDED" = true ]; then
    echo "⚠ ВАЖНО: Вы были добавлены в группу 'docker'"
    echo "Для применения прав выполните:"
    echo "  newgrp docker"
    echo "  или выйдите и зайдите снова"
    echo ""
    echo "После этого запустите скрипт run.sh или перезапустите установку"
elif ! groups $USER | grep -q docker; then
    echo "⚠ ВНИМАНИЕ: Пользователь '$USER' не в группе 'docker'"
    echo "Выполните: sudo usermod -aG docker $USER"
    echo "Затем: newgrp docker"
fi

echo ""
echo "========================================="
echo "✅ Установка завершена успешно!"
echo "========================================="
echo ""
echo "Запустить MAX Messenger можно одним из способов:"
echo "  1. Через меню приложений: 'MAX Messenger (Docker)'"
echo "  2. Командой: ./scripts/run.sh"
echo "  3. Командой: docker compose up"
echo ""
echo "Остановить MAX:"
echo "  • Закройте окно приложения"
echo "  • Или выполните: ./scripts/stop.sh"
echo ""

if [ "$DOCKER_GROUP_ADDED" = true ] || ! groups $USER | grep -q docker; then
    echo "⚠ ПЕРЕД ЗАПУСКОМ выполните: newgrp docker"
elif [ "$USE_SUDO" = true ]; then
    echo "⚠ Для запуска используйте: sudo docker compose up"
else
    echo "🎉 Можно сразу запускать MAX!"
fi
echo "========================================="
