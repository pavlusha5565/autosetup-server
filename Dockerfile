FROM ubuntu:latest

# Установка необходимых пакетов для базовой работы и тестирования
RUN apt-get update && apt-get install -y \
    sudo \
    ip \
    bash \
    coreutils \
    procps \
    vim \
    nano \
    curl \
    wget \
    net-tools \
    iputils-ping \
    openssh-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Создание рабочей директории
WORKDIR /autosetup

# Копирование файлов скрипта в контейнер
COPY . /autosetup/

# Сделать скрипты исполняемыми
RUN chmod +x src/main.sh \
    && chmod +x src/modules/*.sh

# Настройка входной точки для контейнера
# Запуск bash при старте контейнера
ENTRYPOINT ["/bin/bash"]

# Можно добавить подсказку в виде комментария о том, как запустить скрипт внутри контейнера
# CMD ["-c", "echo 'Для запуска скрипта настройки выполните: sudo ./main.sh'"]
