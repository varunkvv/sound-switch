import AppKit
import CoreAudio
import SwiftUI

struct MenuView: View {
    @Environment(AudioModel.self) private var model
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DeviceSection(
                title: "Output",
                input: false,
                devices: model.outputs,
                selectedID: model.defaultOutput,
                volume: model.outputVolume,
                onSelect: { model.select($0, input: false) },
                onVolume: { model.setVolume($0, input: false) },
                onMove: { model.move($0, before: $1, input: false) },
                onNudge: { model.nudge($0, up: $1, input: false) }
            )

            DeviceSection(
                title: "Input",
                input: true,
                devices: model.inputs,
                selectedID: model.defaultInput,
                volume: model.inputVolume,
                onSelect: { model.select($0, input: true) },
                onVolume: { model.setVolume($0, input: true) },
                onMove: { model.move($0, before: $1, input: true) },
                onNudge: { model.nudge($0, up: $1, input: true) }
            )

            Divider()

            Toggle("Start at Login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        try LaunchAtLogin.setEnabled(enabled)
                    } catch {
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }

            HStack {
                Button("Sound Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
        .padding(14)
        .frame(width: 300)
    }
}

private struct DeviceSection: View {
    let title: String
    let input: Bool
    let devices: [AudioDevice]
    let selectedID: AudioDeviceID
    let volume: Float?
    let onSelect: (AudioDevice) -> Void
    let onVolume: (Float) -> Void
    /// Called with (dragged uid, target uid) when a row is dropped onto another row.
    let onMove: (String, String) -> Void
    /// Called with (uid, true) to raise a device one place, (uid, false) to lower it.
    let onNudge: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if devices.count > 1 {
                    Text("drag to prioritize")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)

            if devices.isEmpty {
                Text("No devices")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }

            ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                DeviceRow(
                    device: device,
                    input: input,
                    isSelected: device.id == selectedID,
                    canMoveUp: index > 0,
                    canMoveDown: index < devices.count - 1,
                    action: { onSelect(device) },
                    onNudge: { up in onNudge(device.uid, up) }
                )
                .draggable(device.uid)
                .dropDestination(for: String.self) { uids, _ in
                    guard let uid = uids.first, uid != device.uid else { return false }
                    onMove(uid, device.uid)
                    return true
                }
            }

            if let volume {
                HStack(spacing: 8) {
                    Image(systemName: input ? "mic.fill" : "speaker.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Slider(value: Binding(get: { Double(volume) }, set: { onVolume(Float($0)) }))
                        .controlSize(.small)
                    Image(systemName: input ? "mic.badge.plus" : "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
            }
        }
    }
}

private struct DeviceRow: View {
    let device: AudioDevice
    let input: Bool
    let isSelected: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let action: () -> Void
    /// Called with true to raise the device one place, false to lower it.
    let onNudge: (Bool) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 2) {
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: device.symbol(input: input))
                        .frame(width: 20)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                    Text(device.name)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 8)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isHovering {
                ReorderButton(systemName: "chevron.up", help: "Raise priority", enabled: canMoveUp) { onNudge(true) }
                ReorderButton(systemName: "chevron.down", help: "Lower priority", enabled: canMoveDown) { onNudge(false) }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(rowFill)
        )
        .onHover { isHovering = $0 }
    }

    private var rowFill: Color {
        if isSelected { return Color.accentColor.opacity(0.15) }
        if isHovering { return Color.primary.opacity(0.08) }
        return .clear
    }
}

private struct ReorderButton: View {
    let systemName: String
    let help: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption2.weight(.bold))
                .frame(width: 14, height: 14)
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .help(help)
    }
}
