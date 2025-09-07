#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Имя образа и контейнера
IMAGE_NAME="autosetup-test"
CONTAINER_NAME="autosetup-container"
BACKUP_NAME="autosetup-backup"

# Проверка наличия docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Docker не установлен. Пожалуйста, установите Docker и повторите попытку."
    exit 1
fi

# Функция для вывода информации
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Функция для вывода предупреждений
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Функция для вывода ошибок
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Функция проверки наличия контейнера
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^$1$"
    return $?
}

# Функция проверки наличия образа
image_exists() {
    docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$1:latest$"
    return $?
}

# Функция для очистки (удаления) контейнера, если он существует
cleanup_container() {
    if container_exists "$CONTAINER_NAME"; then
        info "Удаление существующего контейнера $CONTAINER_NAME..."
        docker rm -f "$CONTAINER_NAME" > /dev/null
    fi
}

# Вывод меню
show_menu() {
    echo -e "\n${GREEN}=== AUTOSETUP ТЕСТИРОВАНИЕ ===${NC}"
    echo "1. Собрать новый образ и запустить контейнер"
    echo "2. Запустить существующий контейнер (если есть)"
    echo "3. Создать бэкап настроенного контейнера"
    echo "4. Восстановить контейнер из бэкапа"
    echo "5. Удалить контейнер"
    echo "6. Войти в работающий контейнер (bash)"
    echo "0. Выход"
    echo -n -e "\nВыберите действие (0-6): "
}

# Сборка образа и запуск нового контейнера
build_and_run() {
    info "Сборка Docker-образа..."
    docker build -t "$IMAGE_NAME" .

    cleanup_container

    info "Запуск нового контейнера..."
    docker run -it --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro --name "$CONTAINER_NAME" "$IMAGE_NAME"
}

# Запуск существующего контейнера
run_existing() {
    if container_exists "$CONTAINER_NAME"; then
        info "Запуск существующего контейнера $CONTAINER_NAME..."
        docker start -i "$CONTAINER_NAME"
    else
        error "Контейнер $CONTAINER_NAME не существует."
        echo "Используйте опцию 1 для создания нового контейнера или опцию 4 для восстановления из бэкапа."
    fi
}

# Создание бэкапа контейнера
create_backup() {
    if container_exists "$CONTAINER_NAME"; then
        info "Создание бэкапа контейнера $CONTAINER_NAME..."
        # Создаем новый образ из контейнера
        docker commit "$CONTAINER_NAME" "$BACKUP_NAME"
        info "Бэкап создан как образ $BACKUP_NAME"
    else
        error "Контейнер $CONTAINER_NAME не существует. Нечего бэкапить."
    fi
}

# Восстановление из бэкапа
restore_from_backup() {
    if image_exists "$BACKUP_NAME"; then
        cleanup_container

        info "Восстановление контейнера из бэкапа $BACKUP_NAME..."
        docker run -it --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro --name "$CONTAINER_NAME" "$BACKUP_NAME"
    else
        error "Образ бэкапа $BACKUP_NAME не существует."
        echo "Сначала создайте бэкап с помощью опции 3."
    fi
}

# Удаление контейнера
remove_container() {
    if container_exists "$CONTAINER_NAME"; then
        info "Удаление контейнера $CONTAINER_NAME..."
        docker rm -f "$CONTAINER_NAME"
        info "Контейнер удален."
    else
        warn "Контейнер $CONTAINER_NAME не существует."
    fi
}

# Вход в работающий контейнер
enter_container() {
    if container_exists "$CONTAINER_NAME"; then
        RUNNING=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")
        if [ "$RUNNING" = "true" ]; then
            info "Вход в контейнер $CONTAINER_NAME..."
            docker exec -it "$CONTAINER_NAME" bash
        else
            warn "Контейнер $CONTAINER_NAME не запущен. Используйте опцию 2 для запуска."
        fi
    else
        error "Контейнер $CONTAINER_NAME не существует."
    fi
}

# Основной цикл программы
while true; do
    show_menu
    read -r choice

    case $choice in
        1) build_and_run ;;
        2) run_existing ;;
        3) create_backup ;;
        4) restore_from_backup ;;
        5) remove_container ;;
        6) enter_container ;;
        0) info "Выход из программы."; exit 0 ;;
        *) warn "Неверный выбор. Пожалуйста, выберите от 0 до 6." ;;
    esac
done
