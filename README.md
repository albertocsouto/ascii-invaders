# ASCII Invaders

A typing game built with [LÖVE2D](https://love2d.org/). Shoot down the invaders by typing the words printed on them. Letters get longer as you advance.

**Play in your browser: [albertocsouto.github.io/ascii-invaders](https://albertocsouto.github.io/ascii-invaders/)** (keyboard required)

## How to play

- **Type** the word shown on an enemy to shoot it
- **Type** the word on an incoming bullet to deflect it
- No lock-on: just start typing — the game matches as you go
- A mistype flashes red; backspace is not supported (keep going)
- Protect your bases from dive-bombers and enemy fire

## Running locally

Requires [LÖVE2D 11.x](https://love2d.org/).

```bash
love .
```

Pass `debug` to enable level-jump keys (`1`–`7` from the title screen):

```bash
love . debug
```

## Credits

- Font: [Inconsolata](https://levien.com/type/myfonts/inconsolata.html) by Raph Levien — [SIL Open Font License](assets/fonts/OFL.txt)
- A huge thank you to [Bernhard Schelling](https://github.com/schellingb) for [LÖVE Web Builder](https://schellingb.github.io/LoveWebBuilder/), which made the web version possible with zero hassle.

## License

[MIT](LICENSE) © Alberto Caamaño Souto
