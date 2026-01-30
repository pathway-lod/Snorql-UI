#!/usr/bin/env bash
set -euo pipefail

# Load .env if present
if [ -f .env ]; then
  echo "🔧 Loading environment from .env"
  set -a
  source .env
  set +a
fi

cmd="${1:-up}"

case "$cmd" in
  up)
    echo "🚀 Starting Docker Compose..."
    docker compose up -d

    echo "⏳ Waiting for Virtuoso container (${VIRTUOSO_CONTAINER})..."
    for _ in {1..60}; do
      if docker inspect -f '{{.State.Running}}' "$VIRTUOSO_CONTAINER" 2>/dev/null | grep -q true; then
        echo "✅ Virtuoso is running."
        break
      fi
      sleep 2
    done

    echo "🌐 Enabling CORS..."
    ./scripts/enable-cors.sh

    echo "🎉 Setup complete."
    echo "  Snorql UI:  http://localhost:${SNORQL_PORT}"
    echo "  Virtuoso:   http://localhost:${VIRTUOSO_HTTP_PORT}/sparql"
    ;;

  down)
    echo "🛑 Stopping services..."
    docker compose down
    echo "✅ Containers stopped."
    ;;

  clean)
    echo "🧹 Stopping services and removing local images..."
    docker compose down --rmi local
    echo "✅ Containers and local images removed."
    ;;

  *)
    echo "Usage:"
    echo "  ./plantmetwiki-setup.sh up     # start + enable CORS"
    echo "  ./plantmetwiki-setup.sh down   # stop containers"
    echo "  ./plantmetwiki-setup.sh clean  # stop + remove local images"
    exit 1
    ;;
esac