# SoundSwitch

Menu bar only (no Dock icon) macOS app to switch the default input and output device, with volume sliders.

Native SwiftUI `MenuBarExtra` (window style), CoreAudio for devices. Needs macOS 14+.

## Build and run

```bash
./scripts/build-app.sh
open build/SoundSwitch.app
```

The menu bar icon follows the current output device. Turn on **Start at Login** in the popover to launch it at login (macOS may ask you to approve it in System Settings > General > Login Items). Quit from the popover.

## Device priority

Drag devices in the popover to rank them, highest first. When a device connects or disconnects, SoundSwitch selects the highest-ranked device that is connected. Until you reorder once, the app leaves the default device alone. New devices go to the bottom of the list.

Priority is enforced only when the set of connected devices changes, or within 2 seconds after it. Choosing a device by hand after that holds until the next connect or disconnect.

## Ideas for later

- Global hotkey to cycle outputs

## License

MIT. See [LICENSE](LICENSE).
