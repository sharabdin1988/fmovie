#!/bin/bash

# --- Конфигурация ---
BIN_PATH="$HOME/.local/bin"
PROJECT_DIR="$HOME/Projects/movie-cli"

echo "🎬 Начинаю универсальную установку Movie-CLI..."

# 1. Определение дистрибутива и установка зависимостей
if [ -f /etc/debian_version ]; then
    echo "📦 Обнаружена Ubuntu/Debian. Установка через apt..."
    sudo apt update
    sudo apt install -y mpv jq curl fzf
elif [ -f /etc/arch-release ]; then
    echo "📦 Обнаружен Arch/CachyOS. Установка через pacman..."
    sudo pacman -S --needed --noconfirm mpv jq curl fzf
else
    echo "⚠️ Неизвестная система. Убедитесь, что mpv, jq, curl и fzf установлены."
fi

# 2. Проверка TorrServer
if ! command -v torrserver &> /dev/null; then
    echo "🌐 TorrServer не найден."
    if [ -f /etc/arch-release ]; then
        echo "📥 Устанавливаю TorrServer через AUR..."
        if command -v paru &> /dev/null; then paru -S --noconfirm torrserver-bin;
        elif command -v yay &> /dev/null; then yay -S --noconfirm torrserver-bin; fi
    else
        echo "📥 Для Ubuntu рекомендую установить TorrServer вручную:"
        echo "   https://github.com/YouROK/TorrServer/releases"
        echo "   Или используйте команду: snap install torrserver (если доступно)"
    fi
fi

# 3. Установка скриптов
echo "🔨 3. Установка скриптов в $BIN_PATH..."
mkdir -p "$BIN_PATH"

# Копируем файлы из папки проекта (если они там есть) или создаем заново
cp "$PROJECT_DIR/movie.sh" "$BIN_PATH/movie" 2>/dev/null || echo "Ошибка: movie.sh не найден"
cp "$PROJECT_DIR/fmovie.sh" "$BIN_PATH/fmovie" 2>/dev/null || echo "Ошибка: fmovie.sh не найден"

chmod +x "$BIN_PATH/movie" "$BIN_PATH/fmovie"

# 4. Настройка Shell
echo "⚙️ 4. Регистрация в системе..."

# Для Bash/Zsh
grep -q "$BIN_PATH" "$HOME/.bashrc" || echo "export PATH=\"\$PATH:$BIN_PATH\"" >> "$HOME/.bashrc"
grep -q "$BIN_PATH" "$HOME/.zshrc" || echo "export PATH=\"\$PATH:$BIN_PATH\"" >> "$HOME/.zshrc"

# Для Fish
if [ -d "$HOME/.config/fish" ]; then
    mkdir -p "$HOME/.config/fish/functions"
    echo "function movie; $BIN_PATH/movie \$argv; end" > "$HOME/.config/fish/functions/movie.fish"
    echo "function fmovie; $BIN_PATH/fmovie \$argv; end" > "$HOME/.config/fish/functions/fmovie.fish"
    fish -c "set -U fish_user_paths $BIN_PATH \$fish_user_paths" 2>/dev/null
fi

echo "--------------------------------------------------"
echo "✅ УСТАНОВКА ЗАВЕРШЕНА!"
echo "🚀 'movie'  - классический список"
echo "🚀 'fmovie' - живой поиск через fzf"
echo "--------------------------------------------------"
