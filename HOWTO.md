# How to build and distribute the web version

## 1. Package the game

```bash
zip -9 -r game.love main.lua conf.lua data.lua draw.lua sound.lua lboard.lua bonus.lua boss.lua levels.lua assets/
```

## 2. Build the HTML5 version

Go to https://schellingb.github.io/LoveWebBuilder/, upload `game.love`, and download the output ZIP.

## 3. Distribute

### itch.io

1. Create a new project → set *Kind of project* to **HTML**
2. Upload the ZIP, check **"This file will be played in the browser"**
3. Set viewport size to **840×640**
4. Publish

### GitHub Pages

The `docs/` folder is set up for GitHub Pages. After building `game.love` with LoveWebBuilder, run:

```bash
./scripts/deploy-web.sh <loveweb-output.zip>
```

To test locally before pushing:

```bash
cd docs && python3 -m http.server 8080
```

Then open `http://localhost:8080`. Then commit and push. In your repo **Settings → Pages**, set source to **main branch / docs folder**.

> The `docs/coi-serviceworker.js` handles the `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` headers that GitHub Pages can't set natively but LÖVE.js needs for SharedArrayBuffer.

### Own server

Extract the ZIP and copy the files to your web root. If the game loads but freezes, add these headers (required for SharedArrayBuffer):

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

**nginx example:**
```nginx
location /galaxian/ {
    add_header Cross-Origin-Opener-Policy "same-origin";
    add_header Cross-Origin-Embedder-Policy "require-corp";
}
```
