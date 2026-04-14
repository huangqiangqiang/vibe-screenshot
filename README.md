# ScreenshotTool

`ScreenshotTool` is a macOS 13+ menu bar screenshot utility built with Swift Package Manager.

## Features

- Shows a camera icon in the macOS menu bar.
- Reuses the same camera symbol to generate the app icon at build time.
- Clicking the icon opens a menu with `区域截图` and `全屏截图`.
- `区域截图` launches the system interactive drag-to-select screenshot mode.
- Captures are saved to the Desktop as `shot-(YYYY-MM-DD-HH-mm-ss).png`.
- Packaging is done by `Makefile`, which assembles a `.app` bundle and a nested `.appex` companion bundle.

## Build

```bash
make
```

The packaged app will be created at:

```bash
dist/ScreenshotTool.app
```

## Run

```bash
make run
```

On the first capture, macOS may ask for Screen Recording or screenshot-related permission.

## Verify

```bash
make verify
```

## Project Layout

- `Package.swift`: SwiftPM manifest.
- `Sources/ScreenshotCore`: shared file naming and capture process logic.
- `Sources/ScreenshotTool`: menu bar app entry point.
- `Sources/ScreenshotCompanionExtension`: lightweight nested companion target packaged as `.appex`.
- `Support`: bundle metadata and the app-icon generation script used by `Makefile`.

## Notes

The screenshot functionality lives in the main menu bar app. The nested `.appex` is included so the final assembled output has the requested `.app + .appex` bundle structure without relying on an Xcode project.
