#!/bin/bash
set -euo pipefail

echo "[postdeploy] Running Django migrations..."

# EB docker: aplikacja jest w kontenerze "eb-current-app"
docker exec eb-current-app python manage.py migrate --noinput
docker exec eb-current-app python manage.py collectstatic --noinput || true

echo "[postdeploy] Done."