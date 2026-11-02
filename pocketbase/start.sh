#!/bin/sh
set -e
PORT="${PORT:-10000}"
export PB_URL="http://127.0.0.1:${PORT}"
export PB_SUPERUSER_EMAIL="${PB_SUPERUSER_EMAIL:-root@autoschool.test}"
: "${PB_SUPERUSER_PASSWORD:?не задан PB_SUPERUSER_PASSWORD}"
./pocketbase superuser upsert "$PB_SUPERUSER_EMAIL" "$PB_SUPERUSER_PASSWORD" --dir=/app/pb_data
./pocketbase serve --http="0.0.0.0:${PORT}" --dir=/app/pb_data --hooksDir=/app/pb_hooks &
SERVER=$!
until curl -sf "${PB_URL}/api/health" > /dev/null; do sleep 1; done
(cd tools && node setup.mjs --reset)
wait $SERVER
