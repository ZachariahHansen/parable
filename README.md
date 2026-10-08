# Parable

Run Windows games on an Apple Silicon Mac. Free, and built on Wine.

Parable is a small Mac app that sets up and launches Windows software, Steam included, using its own build of Wine. It does not emulate Windows or include any part of it; Wine translates what Windows programs ask for into what macOS provides.

> **Status: early.** It has been used for Steam and a handful of games on one Mac (M4 Pro, macOS 27). Expect rough edges.

## What works

- **Steam for Windows**, including sign-in, downloads and launching games.
- **DirectX 11 and 12 games** through Apple's D3DMetal, once you import it (see below).
- **Controllers**, including a Nintendo Switch Pro Controller, presented to games as an Xbox pad. Use a USB cable if you can; see the note on controllers below.
- **Online play** in games that use Steam's networking.

## What doesn't

- **Games with Easy Anti-Cheat, BattlEye or kernel-level anti-cheat.** Their vendors don't support Wine on macOS, and Parable makes no attempt to get around them.
- **Older 32-bit DirectX 9 games** are untested and likely to struggle.
- **In-game video** that relies on Windows media codecs (the engine is built without GStreamer for now).
- **macOS Game Mode** doesn't switch on automatically yet.

## Requirements

- A Mac with Apple Silicon, macOS 14 or later
- Rosetta 2: `softwareupdate --install-rosetta --agree-to-license`

## Getting started

1. Download `Parable.zip` from the [releases page](https://github.com/ZachariahHansen/parable/releases), unzip it and move Parable to Applications. The app isn't notarized, so the first time, right-click it and choose **Open**.
2. Open Parable and click **Install** to download the engine (about 95 MB).
3. Click **+** to create a bottle. A bottle is a self-contained Windows environment; one for Steam is a good start.
4. Drop a Windows installer onto the window, for example `SteamSetup.exe` from Steam's website. Once Steam is installed, use **Add Program** to pick `steam.exe` so it gets a Run button.

### DirectX 11 and 12 (D3DMetal)

Most modern games need Apple's D3DMetal, which Parable cannot include. It's free:

1. Sign in at <https://developer.apple.com/games/> and download the **Game Porting Toolkit**.
2. Open the downloaded disk image.
3. In Parable, select a bottle and click **Import D3DMetal…**, then choose the mounted disk image.

Apple licenses the toolkit for non-commercial use.

### Controllers: use a cable

A controller works over Bluetooth, but expect input delay. In testing with a Switch Pro Controller, the Bluetooth link stalled intermittently, with some inputs arriving more than a tenth of a second late, which makes games feel sluggish. The same controller on a USB cable was steady and felt much better.

- **Connect by USB** whenever you play anything timing-sensitive. The cable must carry data; many charging cables don't, and the Mac won't see the controller at all on those.
- **Connect the controller before starting the game.** Some games only look for controllers at launch.
- **If you do use Bluetooth**, quit other apps that talk to controllers, such as the Mac version of Steam.

### Bottle settings

- **Engine**: which Wine build the bottle uses.
- **Retina mode**: sharper picture at full display resolution. Quit the bottle's programs before changing it.
- **Controller face buttons**: match the letters printed on a Nintendo-style controller, or match Xbox positions.
- **Show Metal performance HUD**: frame rate overlay in games.

## Command line

The app is a front end for a library and a command-line tool that do the same things:

```sh
parable doctor                         # check Rosetta, engines, bottles
parable engine install parable         # download the engine
parable bottle create games
parable run games ~/Downloads/setup.exe
parable d3dmetal import "/Volumes/Game Porting Toolkit-3.0"
parable open games                     # the bottle's C: drive in Finder
```

Data lives in `~/Library/Application Support/Parable`. Set `PARABLE_HOME` to use another location.

## Building from source

Needs Xcode.

```sh
swift build            # the library and the `parable` command-line tool
./make-app.sh          # Parable.app in this folder
./make-release.sh      # Parable.zip for a release
```

Layout:

- `Sources/ParableCore`: engines, bottles, launching, D3DMetal import. No UI.
- `Sources/parable`: the command-line tool.
- `Sources/ParableApp`: the SwiftUI app.
- `Engine/`: patches and scripts for building the engine.

## The engine

Parable's engine is CodeWeavers' CrossOver 26.3 source release (Wine 11.0) with the patches in `Engine/patches`:

- `0001`: return the type-of-service detail on received packets on macOS. Steam's networking library aborts the game without it, which crashed online play.
- `0002`: start Steam's UI helper with in-process painting. Wine's Mac driver cannot show a window painted from another process, which left Steam's window black.

It is built with SDL so that controllers reach games through Wine itself.

`Engine/build-engine.sh` builds it and `Engine/package-engine.sh` packages it for a release; the comments in both record the pitfalls. The large inputs live in `EngineBuild/`, which is not in version control.

## Licensing

- Parable's own code is MIT licensed; see [LICENSE](LICENSE).
- The engine is a modified Wine, under the LGPL. Its source is CodeWeavers' published tarball plus `Engine/patches`. See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for Wine and every bundled library.
- Parable does not distribute Apple's D3DMetal, Steam, or any game.

Parable is an independent project. It is not affiliated with or endorsed by the Wine project, CodeWeavers, Apple, Valve or Nintendo.

## Acknowledgements

Parable stands on the work of the Wine developers, CodeWeavers, Gcenx's macOS Wine builds, and the Whisky project, which showed how approachable a Wine front end for the Mac could be.
