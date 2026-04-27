#!/bin/bash

# --- Конфигурация ---
BIN_PATH="$HOME/.local/bin"
PROJECT_DIR="$HOME/Projects/movie-cli"

echo "🎬 Обновление Movie-CLI (movie + fmovie + movie-trends)..."

# 1. Установка зависимостей
if [ -f /etc/debian_version ]; then
    sudo apt update && sudo apt install -y mpv jq curl fzf
elif [ -f /etc/arch-release ]; then
    sudo pacman -S --needed --noconfirm mpv jq curl fzf
fi

# 2. Установка скриптов
mkdir -p "$BIN_PATH"
cp "$PROJECT_DIR/movie.sh" "$BIN_PATH/movie"
cp "$PROJECT_DIR/fmovie.sh" "$BIN_PATH/fmovie"
cp "$PROJECT_DIR/movie-trends.sh" "$BIN_PATH/movie-trends"

chmod +x "$BIN_PATH/movie" "$BIN_PATH/fmovie" "$BIN_PATH/movie-trends"

# 3. Настройка оболочек
if [ -d "$HOME/.config/fish" ]; then
    mkdir -p "$HOME/.config/fish/functions"
    echo "function movie; $BIN_PATH/movie \$argv; end" > "$HOME/.config/fish/functions/movie.fish"
    echo "function fmovie; $BIN_PATH/fmovie \$argv; end" > "$HOME/.config/fish/functions/fmovie.fish"
    echo "function movie-trends; $BIN_PATH/movie-trends \$argv; end" > "$HOME/.config/fish/functions/movie-trends.fish"
    fish -c "set -U fish_user_paths $BIN_PATH \$fish_user_paths" 2>/dev/null
fi

echo "--------------------------------------------------"
echo "✅ ОБНОВЛЕНИЕ ЗАВЕРШЕНА!"
echo "🚀 'movie'        - классический список"
echo "🚀 'fmovie'       - живой поиск"
echo "🚀 'movie-trends' - популярные фильмы и рецензии 🔥"
echo "--------------------------------------------------"
