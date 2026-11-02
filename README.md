# SoundSwitch

Menu bar only (no Dock icon) macOS app to switch the default input and output device, with volume sliders.

Native SwiftUI `MenuBarExtra` (window style), CoreAudio for devices. Needs macOS 14+.

## Build and run

```bash
./scripts/build-app.sh
open build/SoundSwitch.app
```

The menu bar icon follows the current output device. Turn on **Start at Login** in the popover to launch it at login (macOS may ask you to approve it in System Settings > General > Login Items). Quit from the popover.

## Ideas for later

- Global hotkey to cycle outputs

## License

MIT. See [LICENSE](LICENSE).
