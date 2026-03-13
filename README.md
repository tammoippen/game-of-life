[![Test](https://github.com/tammoippen/game-of-life/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/tammoippen/game-of-life/actions/workflows/test.yml)

# Game of Life

A terminal-based implementation of [Conway's Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) written in Zig.

The simulation renders in your terminal using Unicode half-block characters, fitting two cell rows per terminal line for a compact display.

## Rules

Each cell is either **alive** or **dead**. At every step:

1. A live cell with fewer than 2 live neighbours dies (underpopulation)
2. A live cell with 2 or 3 live neighbours survives
3. A live cell with more than 3 live neighbours dies (overpopulation)
4. A dead cell with exactly 3 live neighbours becomes alive (reproduction)

## Install

Pre-built binaries for Linux and macOS are available on the [Releases page](https://github.com/tammoippen/game-of-life/releases).

Download the archive for your platform, extract it, and place the binary somewhere on your `PATH`:

```sh
# Linux x86_64
curl -L https://github.com/tammoippen/game-of-life/releases/latest/download/game_of_life-linux-x86_64.tar.gz | tar xz
sudo mv game_of_life /usr/local/bin/
```

```sh
# Linux aarch64
curl -L https://github.com/tammoippen/game-of-life/releases/latest/download/game_of_life-linux-aarch64.tar.gz | tar xz
sudo mv game_of_life /usr/local/bin/
```

```sh
# macOS Intel
curl -L https://github.com/tammoippen/game-of-life/releases/latest/download/game_of_life-macos-x86_64.tar.gz | tar xz
sudo mv game_of_life /usr/local/bin/
```

```sh
# macOS Apple Silicon
curl -L https://github.com/tammoippen/game-of-life/releases/latest/download/game_of_life-macos-aarch64.tar.gz | tar xz
sudo mv game_of_life /usr/local/bin/
```

```sh
# Windows x86_64 (PowerShell)
Invoke-WebRequest -Uri https://github.com/tammoippen/game-of-life/releases/latest/download/game_of_life-windows-x86_64.zip -OutFile game_of_life.zip
Expand-Archive game_of_life.zip
```

Then run it directly:

```sh
# Run with defaults
game_of_life

# Custom options
game_of_life --width 120 --height 60 --alive 0.3 --sleep 100
```

## Build & Run

Requires [Zig](https://ziglang.org/) (tested with the current stable release).

```sh
# Build
zig build

# Run with defaults (80×40 grid, 50% initial density, 200ms step interval)
zig build run

# Pass custom options
zig build run -- --width 120 --height 60 --alive 0.3 --sleep 100
```

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--width N` | `80` | Grid width (must be even and > 0) |
| `--height N` | `40` | Grid height (must be even and > 0) |
| `--alive F` | `0.5` | Initial fraction of live cells (0–1) |
| `--sleep N` | `200` | Milliseconds between steps |
| `-v` / `--version` | — | Print version and exit |

## Tests

```sh
zig build test
```
