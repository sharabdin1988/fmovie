#!/bin/bash

# --- Настройки ---
# Используем Shikimori API для аниме и публичный хаб для Кинопоиска
SHIKIMORI_URL="https://shikimori.one/api/animes"
# Для Кинопоиска используем открытый агрегатор трендов
KP_URL="https://api.kinopoisk.dev/v1.4/movie"
KP_TOKEN="Z8699G5-M7G4M68-N3P5G9K-H9B7P5G" # Публичный демо-токен

echo "🍿 Что будем смотреть сегодня?"
echo "1) 🎬 Популярные фильмы (Кинопоиск)"
echo "2) 📺 Трендовые сериалы (Кинопоиск)"
echo "3) ⛩️ Топ аниме (Shikimori)"
echo -n "👉 Ваш выбор: "
read -r CAT_CHOICE

echo "📡 Загружаю российский топ..."

case $CAT_CHOICE in
    1)
        # Топ фильмов по рейтингу и популярности
        RESPONSE=$(curl -s -H "X-API-KEY: $KP_TOKEN" "$KP_URL?limit=20&page=1&selectFields=name&selectFields=description&selectFields=rating&selectFields=year&sortField=rating.kp&sortType=-1&type=movie")
        CHOICE=$(echo "$RESPONSE" | jq -r '.docs[] | "\(.rating.kp) | \(.name) (\(.year)) @@@ \(.description)"' | \
            fzf --delimiter=' @@@ ' --with-nth=1 --height=80% --reverse --header="🔥 Топ Кинопоиска" --preview 'echo -e "📖 ОПИСАНИЕ:\n\n{2}"' --preview-window=right:50%:wrap)
        ;;
    2)
        # Топ сериалов
        RESPONSE=$(curl -s -H "X-API-KEY: $KP_TOKEN" "$KP_URL?limit=20&page=1&selectFields=name&selectFields=description&selectFields=rating&selectFields=year&sortField=rating.kp&sortType=-1&type=tv-series")
        CHOICE=$(echo "$RESPONSE" | jq -r '.docs[] | "\(.rating.kp) | \(.name) (\(.year)) @@@ \(.description)"' | \
            fzf --delimiter=' @@@ ' --with-nth=1 --height=80% --reverse --header="📺 Популярные сериалы" --preview 'echo -e "📖 ОПИСАНИЕ:\n\n{2}"' --preview-window=right:50%:wrap)
        ;;
    3)
        # Аниме через Shikimori (полностью открыто)
        RESPONSE=$(curl -s "$SHIKIMORI_URL?order=popularity&limit=20&kind=tv")
        CHOICE=$(echo "$RESPONSE" | jq -r '.[] | "\(.score) | \(.russian // .name) @@@ Статус: \(.status)\nТип: \(.kind)"' | \
            fzf --delimiter=' @@@ ' --with-nth=1 --height=80% --reverse --header="⛩️ Популярное Аниме (Shikimori)" --preview 'echo -e "📖 ИНФОРМАЦИЯ:\n\n{2}"' --preview-window=right:50%:wrap)
        ;;
    *) echo "Отмена."; exit 0 ;;
esac

[ -z "$CHOICE" ] && exit 0

# Извлекаем название для поиска
MOVIE_TITLE=$(echo "$CHOICE" | awk -F' @@@ ' '{print $1}' | sed -E 's/^[0-9\.]+ \| (.*) \(.*\)$/\1/')

if [ -z "$MOVIE_TITLE" ]; then
    MOVIE_TITLE=$(echo "$CHOICE" | awk -F' @@@ ' '{print $1}' | cut -d'|' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
fi

echo "🔍 Ищу в качестве: $MOVIE_TITLE..."
fmovie "$MOVIE_TITLE"
