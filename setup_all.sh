#!/bin/bash

# --- Конфигурация ---
BIN_PATH="$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🎬 Установка/Обновление Movie-CLI (movie + fmovie)..."

# 1. Установка зависимостей
OS="$(uname -s)"
case "${OS}" in
    Linux*)
        echo "🐧 Обнаружен Linux. Проверка пакетного менеджера..."
        if [ -f /etc/debian_version ]; then
            sudo apt update && sudo apt install -y mpv jq curl fzf
        elif [ -f /etc/arch-release ]; then
            sudo pacman -S --needed --noconfirm mpv jq curl fzf
        else
            echo "⚠️  Неизвестный дистрибутив Linux. Пожалуйста, установите mpv, jq, curl, fzf вручную."
        fi
        ;;
    Darwin*)
        echo "🍎 Обнаружена macOS. Проверка Homebrew..."
        if command -v brew >/dev/null 2>&1; then
            brew install mpv jq fzf
        else
            echo "⚠️  Homebrew не найден. Пожалуйста, установите его (https://brew.sh) или зависимости (mpv, jq, fzf) вручную."
        fi
        ;;
    *)
        echo "⚠️  ОС ${OS} не поддерживается автоматически для установки зависимостей."
        ;;
esac

# 2. Установка скриптов
echo "📂 Копирование скриптов в $BIN_PATH..."
mkdir -p "$BIN_PATH"
cp "$SCRIPT_DIR/movie.sh" "$BIN_PATH/movie"
cp "$SCRIPT_DIR/fmovie.sh" "$BIN_PATH/fmovie"

chmod +x "$BIN_PATH/movie" "$BIN_PATH/fmovie"

# 3. Настройка PATH
echo "🛠 Настройка переменных окружения..."
SHELL_TYPE="$(basename "$SHELL")"
case "$SHELL_TYPE" in
    zsh)  CONFIG_FILE="$HOME/.zshrc" ;;
    bash) CONFIG_FILE="$HOME/.bashrc"; [ -f "$HOME/.bash_profile" ] && CONFIG_FILE="$HOME/.bash_profile" ;;
    *)    CONFIG_FILE="" ;;
esac

if [ -n "$CONFIG_FILE" ]; then
    if ! grep -q "$BIN_PATH" "$CONFIG_FILE" 2>/dev/null; then
        echo "export PATH=\"\$PATH:$BIN_PATH\"" >> "$CONFIG_FILE"
        echo "✨ Путь $BIN_PATH добавлен в $CONFIG_FILE"
    fi
fi

# 4. Настройка Fish (отдельно)
if command -v fish >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/fish/functions"
    echo "function movie; $BIN_PATH/movie \$argv; end" > "$HOME/.config/fish/functions/movie.fish"
    echo "function fmovie; $BIN_PATH/fmovie \$argv; end" > "$HOME/.config/fish/functions/fmovie.fish"
    fish -c "set -U fish_user_paths $BIN_PATH \$fish_user_paths" 2>/dev/null
    echo "✨ Настройки для Fish применены"
fi

echo "--------------------------------------------------"
echo "✅ УСТАНОВКА ЗАВЕРШЕНА!"
echo "🚀 'movie'        - классический список"
echo "🚀 'fmovie'       - живой поиск (fzf)"
echo "--------------------------------------------------"
if [ -n "$CONFIG_FILE" ]; then
    echo "💡 Перезапустите терминал или выполните: source $CONFIG_FILE"
fi
