#!/bin/bash

# --- Настройки ---
# Используем публичный API TMDB через прокси-зеркало для стабильности
API_KEY="8d6d91941d3d63964893708f53f938d2"
BASE_URL="https://api.tmdb.org/3" # Пробуем основной домен через HTTPS
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

# Используем curl с таймаутом и проверкой ошибок
RESPONSE=$(curl -s -L --connect-timeout 10 "$TREND_URL")

# Проверка на пустой ответ или ошибку
if [ -z "$RESPONSE" ] || [[ $RESPONSE == *"status_message"* ]]; then
    echo "⚠️ Проблема с основным сервером. Пробую зеркало..."
    # Попытка через публичный прокси-сервер (иногда помогает)
    RESPONSE=$(curl -s -L "https://tmdb-proxy.api.workers.dev/3/${TREND_URL#$BASE_URL/}")
fi

if ! echo "$RESPONSE" | jq -e '.results | length > 0' > /dev/null 2>&1; then
    echo "❌ Ошибка: Не удалось получить данные. Попробуйте включить VPN или повторить позже."
    # Выведем ответ для диагностики, если он не секретный
    # echo "$RESPONSE" | head -c 100
    exit 1
fi

# Формируем список: [Название] @@@ [Описание]
CHOICE=$(echo "$RESPONSE" | jq -r '.results[] | "\(.vote_average) | \(.title // .name) (\(.release_date // .first_air_date // \"N/A\" | .[0:4])) @@@ \(.overview)"' | \
    fzf --delimiter=' @@@ ' --with-nth=1 \
    --height=80% --reverse --header="🔥 Выберите и нажмите Enter" \
    --preview 'echo -e "📖 ОПИСАНИЕ:\n\n{2}"' --preview-window=right:50%:wrap)

[ -z "$CHOICE" ] && exit 0

# Извлекаем название
RAW_NAME=$(echo "$CHOICE" | awk -F' @@@ ' '{print $1}')
# Убираем рейтинг и год, оставляя только название
MOVIE_TITLE=$(echo "$RAW_NAME" | sed -E 's/^[0-9\.]+ \| (.*) \(.*\)$/\1/')

# Если sed не сработал (например, нет года), берем всё между | и @@@
if [ -z "$MOVIE_TITLE" ]; then
    MOVIE_TITLE=$(echo "$RAW_NAME" | cut -d'|' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
fi

echo "🔍 Ищу в прокате: $MOVIE_TITLE..."
fmovie "$MOVIE_TITLE"
