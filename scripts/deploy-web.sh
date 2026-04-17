#!/usr/bin/env bash
# Usage: ./deploy-web.sh <path-to-loveweb-zip>
# Extracts the LoveWebBuilder output into docs/ and patches index.html
# for GitHub Pages compatibility (SharedArrayBuffer via service worker).

set -e

ZIP="$1"

if [ -z "$ZIP" ]; then
    echo "Usage: $0 <loveweb-output.zip>"
    echo ""
    echo "Steps:"
    echo "  1. Run: zip -9 -r game.love main.lua conf.lua data.lua draw.lua sound.lua lboard.lua bonus.lua boss.lua levels.lua assets/"
    echo "  2. Upload game.love to https://schellingb.github.io/LoveWebBuilder/"
    echo "  3. Download the ZIP and run: scripts/deploy-web.sh <downloaded.zip>"
    exit 1
fi

if [ ! -f "$ZIP" ]; then
    echo "Error: file not found: $ZIP"
    exit 1
fi

echo "Extracting game.js from $ZIP into docs/..."
unzip -o "$ZIP" game.js -d docs/

echo ""
echo "All done! Commit the docs/ folder and push to GitHub."
echo "Then in Settings → Pages, set Source to 'main branch / docs folder'."
