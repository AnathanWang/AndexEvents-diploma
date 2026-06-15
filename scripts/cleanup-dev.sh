#!/usr/bin/env bash
# Освобождает RAM: Gradle/Kotlin daemons, опционально Docker.
# Usage:
#   ./scripts/cleanup-dev.sh           # только Gradle + Kotlin (~10-15 GB)
#   ./scripts/cleanup-dev.sh --docker    # + остановить Docker (~3-4 GB)
#   ./scripts/cleanup-dev.sh --simulator # + выключить iOS Simulator

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STOP_DOCKER=false
STOP_SIMULATOR=false

for arg in "$@"; do
  case "$arg" in
    --docker) STOP_DOCKER=true ;;
    --simulator) STOP_SIMULATOR=true ;;
    -h|--help)
      echo "Usage: $0 [--docker] [--simulator]"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

mem_used() {
  memory_pressure 2>/dev/null | awk -F: '/System-wide memory free percentage/ {gsub(/[^0-9.]/,"",$2); printf "%.0f%% free\n", $2}' \
    || vm_stat | awk '/Pages free/ {free=$3} /Pages active/ {a=$3} /Pages inactive/ {i=$3} /Pages wired/ {w=$3} END {gsub(/\./,"",free); gsub(/\./,"",a); gsub(/\./,"",i); gsub(/\./,"",w); total=(free+a+i+w)*4096/1024/1024/1024; printf "~%.1f GB in use (approx)\n", total}'
}

echo "==> AndexEvents dev cleanup"
echo "    Before: $(mem_used)"

echo "==> Stopping Gradle daemons (project)..."
if [ -x "$ROOT/android/gradlew" ]; then
  (cd "$ROOT/android" && ./gradlew --stop) 2>/dev/null || true
fi

echo "==> Stopping all Gradle/Kotlin daemons (system)..."
pkill -f 'org.gradle.launcher.daemon.bootstrap.GradleDaemon' 2>/dev/null || true
pkill -f 'org.jetbrains.kotlin.daemon.KotlinCompileDaemon' 2>/dev/null || true

if $STOP_DOCKER; then
  echo "==> Stopping Docker stack..."
  docker compose -f "$ROOT/deployments/docker/docker-compose.yml" -p andexevents down 2>/dev/null || true
  docker compose -f "$ROOT/docker-compose.yml" down --remove-orphans 2>/dev/null || true
fi

if $STOP_SIMULATOR; then
  echo "==> Shutting down iOS Simulator..."
  xcrun simctl shutdown all 2>/dev/null || true
fi

sleep 2
echo "==> Done. After: $(mem_used)"
echo ""
echo "Tip: закрой лишние IDE (оставь только Cursor), Arc/Telegram если не нужны."
echo "     Сборка APK: ./scripts/cleanup-dev.sh && flutter build apk --debug"
