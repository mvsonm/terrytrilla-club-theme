#!/bin/bash
#
# ПРЕДВЫКАТНЫЙ ЗАСЛОН (G3). Проверяет тему ДО того, как её увидит посетитель.
#
# ## Зачем
#
# Приёмка spec/acceptance.mjs бьёт по живому форуму — то есть ловит поломку
# ПОСЛЕ выката. Это лучше, чем ничего, но означает, что каждую правку темы
# первым проверяет посетитель. Отдельный экземпляр Discourse ради этого ставить
# дорого, и оказалось — не нужно: у самого движка есть предпросмотр темы.
#
# ## Как устроено
#
#   ветка staging  ->  тема #3 «TerryTrilla Club (staging)» на форуме
#   ветка main     ->  тема #1, та, что видят все
#
# Обе привязаны к ОДНОМУ репозиторию и обновляются ОДНИМ механизмом (git-импорт).
# Это важнее, чем кажется: раньше копия для разработки заливалась вручную через
# `discourse_theme upload`, и проверять на ней «то же самое, что поедет в бой»
# было нечем — ручная заливка и git-импорт расходятся молча. Цветовые схемы,
# например, ставит только импорт, и из-за этого 15.09 владелец смотрел
# предпросмотр без схемы и сказал «всё осталось как было».
#
# Порядок:
#   1. текущая ветка уезжает в staging
#   2. тема #3 обновляется из git, кэш таблиц стилей сбрасывается
#   3. приёмка гоняется по теме #3 через ?preview_theme_id=3
#   4. зелено -> main двигается на ту же точку, тема #1 обновляется
#      красно  -> в бой ничего не едет, показывается, что именно упало
#
# ## Сеанс
#
# Предпросмотр темы работает только у сотрудника. Сеанс выпускается на время
# прогона и отзывается в конце. Он передаётся ФАЙЛОМ с правами 600 — не
# аргументом команды (аргументы видны в `ps` всем на машине) и не заголовком
# запроса (заголовок утекает при первом переходе на чужой домен).
#
# ⚠️ Имена переменных ЛАТИНИЦЕЙ. bash не принимает кириллицу в именах, а ошибку
# выдаёт как «No such file or directory» — то есть читается как отсутствующий
# файл, а не как синтаксис. И `bash -n` этого НЕ ловит: для разборщика строка
# выглядит вызовом команды. За один день 16.09 наступил дважды.
#
# Запуск из корня репозитория темы:
#   bash scripts/gate.sh            — проверить и, если зелено, выкатить
#   bash scripts/gate.sh --check    — только проверить, в бой не выкатывать
set -uo pipefail

FORUM="-i $HOME/.ssh/tt_train -p 2222 deploy@159.195.137.243"
WEB="-i $HOME/.ssh/id_rsa -p 2222 deploy@159.195.13.167"
THEME_STAGING=3
THEME_LIVE=1
OWNER_ID=8              # канонический админский аккаунт на форуме
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

SESSION_FILE=/tmp/.tt_gate_session

step() { echo; echo "── $1 ──────────────────────────────────────────"; }

cleanup() {
  # Сеанс отзывается ВСЕГДА — и на зелёном, и на красном, и при обрыве.
  ssh $FORUM "rm -f ${SESSION_FILE}" 2>/dev/null || true
  ssh $WEB "rm -f ${SESSION_FILE}" 2>/dev/null || true
  ssh $FORUM "sudo docker exec app rails runner /tmp/gate_revoke.rb" >/dev/null 2>&1 || true
}
trap cleanup EXIT

stop() { echo; echo "✗ ЗАСЛОН: $1"; exit 1; }

# ── 1. Ветка staging ────────────────────────────────────────────────────────
step "1. Отправляю ветку в staging"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
POINT="$(git rev-parse HEAD)"
SHORT="${POINT:0:8}"
echo "  ветка ${BRANCH}, точка ${SHORT}"
git push -f origin "HEAD:staging" || stop "не удалось отправить staging"

# ── 2. Обновляю тему staging на форуме ──────────────────────────────────────
step "2. Обновляю тему #${THEME_STAGING} из git"
ssh $FORUM "cat > /tmp/gate_update.rb" <<RB
t = Theme.find(${THEME_STAGING})
t.remote_theme.update_from_remote
t.reload
puts "local=#{t.remote_theme.local_version.to_s[0,8]}"
Stylesheet::Manager.clear_theme_cache!
Stylesheet::Manager.clear_color_scheme_cache!
puts "cache=cleared"
RB
ANSWER="$(ssh $FORUM "sudo docker cp /tmp/gate_update.rb app:/tmp/gate_update.rb >/dev/null && sudo docker exec app rails runner /tmp/gate_update.rb" 2>&1 | grep -E '^(local|cache)=')"
echo "  ${ANSWER}" | tr '\n' ' '; echo
echo "${ANSWER}" | grep -q "local=${SHORT}" || stop "тема не встала на ${SHORT} — обновление не доехало"

# ── 3. Сеанс сотрудника ─────────────────────────────────────────────────────
step "3. Выпускаю временный сеанс"
ssh $FORUM "cat > /tmp/gate_session.rb" <<RB
u = User.find(${OWNER_ID})
raise "ne sotrudnik" unless u.staff?
t = UserAuthToken.generate!(user_id: u.id, user_agent: "tt-gate", client_ip: "127.0.0.1")
File.write("/tmp/.gate_out", t.unhashed_auth_token)
File.write("/tmp/gate_token_id", t.id.to_s)
RB

# Скрипт отзыва кладём ДО выпуска: уборка обязана работать даже при обрыве.
ssh $FORUM "cat > /tmp/gate_revoke_src.rb" <<'RB'
id = (File.read("/tmp/gate_token_id").to_i rescue 0)
UserAuthToken.where(id: id).destroy_all if id > 0
File.delete("/tmp/gate_token_id") rescue nil
RB
ssh $FORUM "sudo docker cp /tmp/gate_revoke_src.rb app:/tmp/gate_revoke.rb >/dev/null" || true

# ⚠️ Значение сеанса НЕ печатается: оно идёт из контейнера сразу в файл 600.
ssh $FORUM "sudo docker cp /tmp/gate_session.rb app:/tmp/gate_session.rb >/dev/null \
  && sudo docker exec app rails runner /tmp/gate_session.rb >/dev/null 2>&1 \
  && umask 077 && sudo docker cp app:/tmp/.gate_out ${SESSION_FILE} >/dev/null \
  && chmod 600 ${SESSION_FILE} && sudo chown deploy:deploy ${SESSION_FILE} \
  && sudo docker exec app rm -f /tmp/.gate_out" \
  || stop "не удалось выпустить сеанс"

# Перенос на машину с браузером — тоже потоком в файл, не аргументом.
ssh $FORUM "cat ${SESSION_FILE}" | ssh $WEB "umask 077; cat > ${SESSION_FILE}" \
  || stop "не удалось перенести сеанс"
SIZE="$(ssh $WEB "stat -c %s ${SESSION_FILE}")"
[ "${SIZE}" -gt 20 ] || stop "файл сеанса подозрительно мал (${SIZE} Б)"
echo "  сеанс выпущен и перенесён (${SIZE} Б), содержимое нигде не печаталось"

# ── 4. Приёмка по теме staging ──────────────────────────────────────────────
step "4. Приёмка по теме #${THEME_STAGING}"
scp -q -i "$HOME/.ssh/id_rsa" -P 2222 spec/acceptance.mjs \
  deploy@159.195.13.167:~/browser-probe/acceptance.mjs \
  || stop "не удалось положить приёмку на машину с браузером"

ssh $WEB "cd ~/browser-probe && TT_PREVIEW_THEME_ID=${THEME_STAGING} TT_SESSION_FILE=${SESSION_FILE} node acceptance.mjs"
CODE=$?
[ "${CODE}" -eq 0 ] || stop "приёмка не прошла — в бой НИЧЕГО не поехало. Правьте и гоняйте снова."

# ── 5. Выкат ────────────────────────────────────────────────────────────────
if [ "${CHECK_ONLY}" = "1" ]; then
  echo; echo "✓ Зелено. Выкат не делаю — запрошена только проверка."
  exit 0
fi

step "5. Выкатываю в бой"
git push origin "HEAD:main" || stop "не удалось отправить main"
ssh $FORUM "cat > /tmp/gate_live.rb" <<RB
t = Theme.find(${THEME_LIVE})
t.remote_theme.update_from_remote
t.reload
puts "local=#{t.remote_theme.local_version.to_s[0,8]}"
Stylesheet::Manager.clear_theme_cache!
Stylesheet::Manager.clear_color_scheme_cache!
RB
LIVE="$(ssh $FORUM "sudo docker cp /tmp/gate_live.rb app:/tmp/gate_live.rb >/dev/null && sudo docker exec app rails runner /tmp/gate_live.rb" 2>&1 | grep -E '^local=')"
echo "  боевая тема: ${LIVE}"
echo "${LIVE}" | grep -q "${SHORT}" || stop "боевая тема не встала на ${SHORT}"

echo
echo "✓ Выкачено, и проверено ДО выката."
