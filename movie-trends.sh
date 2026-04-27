#!/bin/bash

# --- Настройки ---
# Используем RSS Rutor для новинок кино и Shikimori для аниме
RUTOR_RSS="http://rutor.info/rss.php?category=1" # Фильмы
RUTOR_SERIES_RSS="http://rutor.info/rss.php?category=4" # Сериалы
SHIKIMORI_URL="https://shikimori.one/api/animes"

echo "🍿 Новинки и тренды:"
echo "1) 🎬 Новинки кино (Rutor)"
echo "2) 📺 Свежие серии (Rutor)"
echo "3) ⛩️ Популярное аниме (Shikimori)"
echo -n "👉 Ваш выбор: "
read -r CAT_CHOICE

echo "📡 Загружаю список..."

case $CAT_CHOICE in
    1)
        # Парсим RSS Rutor через простую обработку текста
        RESPONSE=$(curl -s -L --connect-timeout 10 "$RUTOR_RSS")
        CHOICE=$(echo "$RESPONSE" | grep -oP '(?<=<title>).*?(?=</title>)' | tail -n +2 | \
            fzf --height=80% --reverse --header="🔥 Новинки Кино (Rutor)")
        ;;
    2)
        RESPONSE=$(curl -s -L --connect-timeout 10 "$RUTOR_SERIES_RSS")
        CHOICE=$(echo "$RESPONSE" | grep -oP '(?<=<title>).*?(?=</title>)' | tail -n +2 | \
            fzf --height=80% --reverse --header="📺 Свежие Серии (Rutor)")
        ;;
    3)
        RESPONSE=$(curl -s "https://shikimori.one/api/animes?order=popularity&limit=30&kind=tv")
        CHOICE=$(echo "$RESPONSE" | jq -r '.[] | "\(.score) | \(.russian // .name) @@@ \(.status)"' | \
            fzf --delimiter=' @@@ ' --with-nth=1 --height=80% --reverse --header="⛩️ Аниме Тренды (Shikimori)")
        ;;
    *) echo "Отмена."; exit 0 ;;
esac

[ -z "$CHOICE" ] && exit 0

# Очистка названия для Rutor (убираем лишнее из заголовка RSS)
if [[ "$CAT_CHOICE" == "1" || "$CAT_CHOICE" == "2" ]]; then
    # Названия на Rutor часто содержат год и качество, fmovie с этим справится
    MOVIE_TITLE=$(echo "$CHOICE" | sed -E 's/ \[[^]]+\]//g')
else
    # Для аниме
    MOVIE_TITLE=$(echo "$CHOICE" | awk -F' @@@ ' '{print $1}' | cut -d'|' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
fi

echo "🔍 Ищу: $MOVIE_TITLE..."
fmovie "$MOVIE_TITLE"
