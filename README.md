# SoundSwitch

Menu bar only (no Dock icon) macOS app to switch the default input and output device, with volume sliders.

Native SwiftUI `MenuBarExtra` (window style), CoreAudio for devices. Needs macOS 14+.

## Build and run

```bash
./scripts/build-app.sh
open build/SoundSwitch.app
```

The menu bar icon follows the current output device. Quit from the popover.

## Ideas for later

- Launch at login (`SMAppService.mainApp`)
- Global hotkey to cycle outputs

## License

MIT. See [LICENSE](LICENSE).
