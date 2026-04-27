#!/bin/bash

# --- Настройки ---
# Используем API YTS для получения популярных фильмов (хорошо подходит для поиска трендов)
TRENDS_URL="https://yts.mx/api/v2/list_movies.json?sort_by=download_count&limit=30&minimum_rating=7"
HISTORY_FILE="$HOME/.cache/movie-cli-last"

echo "🍿 Загружаю список популярных фильмов..."

# Получаем данные
RESPONSE=$(curl -s "$TRENDS_URL")

if [ "$(echo "$RESPONSE" | jq -r '.status')" != "ok" ]; then
    echo "❌ Ошибка загрузки трендов."
    exit 1
fi

# Формируем список для fzf
# В основной строке: Рейтинг, Название, Год
# В скрытой колонке: Полное название для поиска
# В окне предпросмотра: Синопсис (рецензия)
CHOICE=$(echo "$RESPONSE" | jq -r '.data.movies[] | "⭐ \(.rating) | \(.title) (\(.year)) \t \(.title) \t \(.summary)"' | \
    fzf --delimiter='\t' --with-nth=1 \
    --height=80% --reverse --header="🔥 Популярные фильмы с высоким рейтингом | [Enter] искать в fmovie" \
    --preview 'echo -e "📖 ОПИСАНИЕ:\n\n{3}"' --preview-window=right:50%:wrap)

if [ -z "$CHOICE" ]; then
    echo "Отмена."
    exit 0
fi

# Извлекаем чистое название для поиска
MOVIE_TITLE=$(echo "$CHOICE" | awk -F'\t' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

echo "🔍 Ищу '$MOVIE_TITLE' в кинотеатре..."

# Запускаем fmovie с этим названием
fmovie "$MOVIE_TITLE"
