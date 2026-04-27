#!/bin/bash

# --- Настройки ---
API_KEY="8d6d91941d3d63964893708f53f938d2"
BASE_URL="https://api.themoviedb.org/3"
LANG="ru-RU"

echo "🍿 Выберите категорию:"
echo "1) 🎬 Популярные фильмы"
echo "2) 📺 Трендовые сериалы"
echo "3) ⛩️ Лучшее аниме"
echo -n "👉 Ваш выбор: "
read -r CAT_CHOICE

case $CAT_CHOICE in
    1) TREND_URL="$BASE_URL/trending/movie/day?api_key=$API_KEY&language=$LANG" ;;
    2) TREND_URL="$BASE_URL/trending/tv/day?api_key=$API_KEY&language=$LANG" ;;
    3) TREND_URL="$BASE_URL/discover/tv?api_key=$API_KEY&language=$LANG&with_keywords=210024&sort_by=popularity.desc" ;;
    *) echo "Отмена."; exit 0 ;;
esac

echo "📡 Загружаю список..."

RESPONSE=$(curl -s "$TREND_URL")

# Проверяем, получили ли мы данные
if ! echo "$RESPONSE" | jq -e '.results | length > 0' > /dev/null 2>&1; then
    echo "❌ Ошибка: Не удалось получить данные от TMDB."
    exit 1
fi

# Формируем список: [Название] @@@ [Описание]
# Мы используем @@@ как уникальный разделитель
CHOICE=$(echo "$RESPONSE" | jq -r '.results[] | "\(.vote_average) | \(.title // .name) (\(.release_date // .first_air_date // "N/A" | .[0:4])) @@@ \(.overview)"' | \
    fzf --delimiter=' @@@ ' --with-nth=1 \
    --height=80% --reverse --header="🔥 Выберите фильм и нажмите Enter" \
    --preview 'echo -e "📖 ОПИСАНИЕ:\n\n{2}"' --preview-window=right:50%:wrap)

[ -z "$CHOICE" ] && exit 0

# Извлекаем название (всё, что до разделителя @@@, убирая рейтинг)
# Мы берем только название фильма без рейтинга и года
MOVIE_TITLE=$(echo "$CHOICE" | awk -F' @@@ ' '{print $1}' | sed -E 's/^.* \| (.*) \(.*\)$/\1/')

# Если sed не сработал, пробуем просто очистить от рейтинга
if [ -z "$MOVIE_TITLE" ]; then
    MOVIE_TITLE=$(echo "$CHOICE" | awk -F' @@@ ' '{print $1}' | cut -d'|' -f2)
fi

echo "🔍 Ищу в прокате: $MOVIE_TITLE..."

# Запускаем fmovie
fmovie "$MOVIE_TITLE"
