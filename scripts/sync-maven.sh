#!/bin/bash
# Sync Maven repository to Moscow VPS
# Usage: ./scripts/sync-maven.sh

set -e

# Configuration
REMOTE_USER="ubuntu"
REMOTE_HOST="msk.okhsunrog.ru"
REMOTE_PATH="/var/www/maven"
LOCAL_MAVEN_CACHE="$HOME/.m2/repository"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Maven Repository Sync ===${NC}"
echo "Source: $LOCAL_MAVEN_CACHE/org/jetbrains/compose"
echo "Target: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"
echo ""

# Check if local maven cache exists
if [ ! -d "$LOCAL_MAVEN_CACHE/org/jetbrains/compose" ]; then
    echo -e "${RED}Error: Local maven cache not found at $LOCAL_MAVEN_CACHE/org/jetbrains/compose${NC}"
    echo "Run the publish tasks first to populate the local maven cache."
    exit 1
fi

# Show what will be synced
echo -e "${YELLOW}Files to sync:${NC}"
du -sh "$LOCAL_MAVEN_CACHE/org/jetbrains/compose"
find "$LOCAL_MAVEN_CACHE/org/jetbrains/compose" -name "*.klib" | wc -l | xargs -I {} echo "{} klib files"
echo ""

# Confirm
read -p "Continue with sync? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Sync with rsync (only compose artifacts)
echo -e "${YELLOW}Syncing files...${NC}"
rsync -avz --progress \
    "$LOCAL_MAVEN_CACHE/org/jetbrains/compose/" \
    "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/org/jetbrains/compose/"

echo ""
echo -e "${GREEN}=== Sync Complete ===${NC}"
echo "Maven repo available at: https://maven.okhsunrog.dev"
echo ""
echo "Users can add to their build.gradle.kts:"
echo '  repositories {'
echo '      maven("https://maven.okhsunrog.dev")'
echo '  }'
