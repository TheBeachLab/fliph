# Flip H

A small native macOS utility that horizontally flips one external monitor.
Select an extended display, activate the mirror, and press **Esc** to stop.
The built-in display and other monitors retain their normal presentation.

## Run

Open `outputs/Flip H.app`. On first activation, allow **Flip H** in System
Settings → Privacy & Security → Screen & System Audio Recording, then reopen
the app if macOS requests it. The app captures video only and processes it
locally. It has no network client, recording output, or third-party dependencies.

An external screen must be configured as an extended display. Native macOS
mirror groups are excluded from the selector. The app starts with flipping off.
Esc is reserved while flipping is active and is released when flipping stops.
The menu-bar item and control window also provide a stop action.

## Build and test

Requirements: macOS 14+, Xcode or its Swift command-line toolchain.

```sh
./script/build_and_run.sh          # Build, sign locally, and launch
./script/build_and_run.sh --build  # Produce outputs/Flip H.app
./script/build_and_run.sh --verify # Build, launch, and check the process
swift test --disable-sandbox
```

The Run action in `.codex/environments/environment.toml` uses the same script.
Builds are ad-hoc signed for local use. Rebuilding or moving the app can require
macOS to approve its screen-capture permission again. The delivered binary was
built for Apple Silicon; the source can be built on Intel Macs.

## Implementation

- SwiftUI owns the small control window and menu-bar menu.
- ScreenCaptureKit captures only the selected screen. The content filter excludes
  this app, which prevents feedback from the full-screen overlay.
- A single replaceable pixel buffer bounds memory and latency. Core Image renders
  the horizontal transform into a Metal-backed, non-activating AppKit panel at
  30 frames per second. All image processing stays on this Mac.
- The captured image includes a reflected arrow pointer drawn by the app. The
  system cursor is hidden only while it is over the selected screen and is
  restored on exit, screen changes, and display sleep.
- Input coordinates remain those of the original desktop, matching an H-flipped
  video output viewed through a physical mirror. The displayed pointer uses the
  standard arrow shape.
- A Carbon hot key handles physical Esc without requesting Accessibility access.
- Display reconfiguration, display sleep, capture errors, and app termination
  stop the presentation and release resources. Capture must provide a complete
  frame before the overlay appears.

## Validation

Verified on 2026-11-08 on an Apple M1 Pro, macOS 27.0.1, with an extended HDMI
display at 1920 × 1080:

- Release build, local code signature, app launch, and HDMI selector.
- Pixel-level test with asymmetric colors: horizontal reversal, rows preserved.
- Test of nonzero input origin and Retina output scaling.
- Live capture started after screen-recording permission was granted.
- User confirmed the HDMI image was horizontally flipped and physical Esc worked.
- Stop button returned the UI to its inactive state.

The graphics tests need access to macOS graphics services; a restricted runner
without that access can return empty Core Image output.

API references:

- https://developer.apple.com/documentation/screencapturekit
- https://developer.apple.com/documentation/screencapturekit/sccontentfilter
- https://developer.apple.com/documentation/coreimage/ciimage/transformed(by:)
- https://developer.apple.com/documentation/metalkit/mtkview
