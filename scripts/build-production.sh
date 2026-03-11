#!/bin/bash
# Production build script for AndexEvents
# Usage: ./scripts/build-production.sh [android|ios|web]

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_DIR="$PROJECT_ROOT/secrets"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 AndexEvents Production Build${NC}"
echo "=================================="

# Check if secrets exist
if [ ! -f "$SECRETS_DIR/yandex_mapkit_api_key.txt" ]; then
  echo -e "${RED}❌ Error: yandex_mapkit_api_key.txt not found in secrets/${NC}"
  echo "Run: sh ./scripts/store_yandex_key.sh <MAPKIT_KEY> <GEOCODING_KEY>"
  exit 1
fi

if [ ! -f "$SECRETS_DIR/yandex_geocode_api_key.txt" ]; then
  echo -e "${RED}❌ Error: yandex_geocode_api_key.txt not found in secrets/${NC}"
  echo "Run: sh ./scripts/store_yandex_key.sh <MAPKIT_KEY> <GEOCODING_KEY>"
  exit 1
fi

# Read API keys
MAPKIT_KEY="$(cat "$SECRETS_DIR/yandex_mapkit_api_key.txt")"
GEOCODING_KEY="$(cat "$SECRETS_DIR/yandex_geocode_api_key.txt")"

if [ -z "$MAPKIT_KEY" ] || [ -z "$GEOCODING_KEY" ]; then
  echo -e "${RED}❌ Error: API keys are empty${NC}"
  exit 1
fi

echo -e "${GREEN}✓ API keys loaded${NC}"

# Determine platform
PLATFORM="${1:-android}"

case "$PLATFORM" in
  android)
    echo -e "\n${YELLOW}📱 Building Android Release APK...${NC}"
    
    # Check if keystore exists
    if [ ! -f "$PROJECT_ROOT/android/app/upload-keystore.jks" ]; then
      echo -e "${YELLOW}⚠️  Warning: No keystore found. Building unsigned release.${NC}"
      echo "For signed release, set up android/key.properties and keystore."
    fi
    
    flutter build apk --release \
      --dart-define=YANDEX_MAPKIT_API_KEY="$MAPKIT_KEY" \
      --dart-define=YANDEX_API_KEY="$GEOCODING_KEY"
      
    echo -e "\n${GREEN}✓ Build complete!${NC}"
    echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
    ;;
    
  appbundle)
    echo -e "\n${YELLOW}📱 Building Android App Bundle...${NC}"
    
    flutter build appbundle --release \
      --dart-define=YANDEX_MAPKIT_API_KEY="$MAPKIT_KEY" \
      --dart-define=YANDEX_API_KEY="$GEOCODING_KEY"
      
    echo -e "\n${GREEN}✓ Build complete!${NC}"
    echo "AAB location: build/app/outputs/bundle/release/app-release.aab"
    ;;
    
  ios)
    echo -e "\n${YELLOW}🍎 Building iOS Release...${NC}"
    
    # Setup iOS secrets
    echo "YANDEX_MAPKIT_API_KEY = $MAPKIT_KEY" > "$PROJECT_ROOT/ios/Secrets.xcconfig"
    
    # Install pods
    echo "Installing CocoaPods dependencies..."
    cd "$PROJECT_ROOT/ios" && pod install && cd ..
    
    flutter build ios --release \
      --dart-define=YANDEX_MAPKIT_API_KEY="$MAPKIT_KEY" \
      --dart-define=YANDEX_API_KEY="$GEOCODING_KEY"
      
    echo -e "\n${GREEN}✓ Build complete!${NC}"
    echo "Note: You'll need to sign and archive in Xcode for distribution."
    ;;
    
  web)
    echo -e "\n${YELLOW}🌐 Building Web Release...${NC}"
    
    flutter build web --release \
      --dart-define=YANDEX_MAPKIT_API_KEY="$MAPKIT_KEY" \
      --dart-define=YANDEX_API_KEY="$GEOCODING_KEY"
      
    echo -e "\n${GREEN}✓ Build complete!${NC}"
    echo "Web build location: build/web/"
    ;;
    
  *)
    echo -e "${RED}❌ Error: Unknown platform '$PLATFORM'${NC}"
    echo "Usage: $0 [android|appbundle|ios|web]"
    exit 1
    ;;
esac

echo -e "\n${GREEN}✅ Production build finished successfully!${NC}"
