# NTE Super Sound Script

> note that this is vibecoded asf enjoy ai slop

AutoHotkey script that automatically completes the Super Sound minigame in Neverness to Everness (NTE).

~95% accuracy. Only supports 16:9 aspect ratios.

## Requirements

- [AutoHotkey v2](https://www.autohotkey.com/)
- Run as administrator (auto-elevates if not)

## Usage

Run `NTESuperSound.ahk`.

| Key | Action |
|-----|--------|
| F1  | Start  |
| F2  | Stop   |
| F4  | Exit   |

## How It Works

The script samples pixel colors at 4 fixed screen positions corresponding to the note lanes. When a note's color is detected, it sends the matching keypress in the background. Keypresses are set to the game's default controls (D, F, J, K) but can be changed in the script.

Color matching uses a configurable tolerance to handle slight rendering variations.

## Background Play

The game does **not** need to be focused. The script uses `PostMessage` to send `WM_KEYDOWN`/`WM_KEYUP` directly to the game window, and reads pixels in screen coordinates, so you can use other applications while it plays.

## Resolution Support

All detection coordinates are referenced from a 3840×2160 baseline and scaled proportionally to the actual game window size. Any **16:9** resolution should work.

Tested resolutions: 3840×2160, 1280×720.

## Limitations

- **16:9 only** — non-standard aspect ratios will misalign the detection points.
- **Requires administrator** — the script auto-elevates on launch.
- **Game window must be visible** — pixel reading cannot see through overlapping windows.

