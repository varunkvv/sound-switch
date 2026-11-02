import AppKit
import CoreAudio
import SwiftUI

struct MenuView: View {
    @Environment(AudioModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DeviceSection(
                title: "Output",
                input: false,
                devices: model.outputs,
                selectedID: model.defaultOutput,
                volume: model.outputVolume,
                onSelect: { model.select($0, input: false) },
                onVolume: { model.setVolume($0, input: false) }
            )

            DeviceSection(
                title: "Input",
                input: true,
                devices: model.inputs,
                selectedID: model.defaultInput,
                volume: model.inputVolume,
                onSelect: { model.select($0, input: true) },
                onVolume: { model.setVolume($0, input: true) }
            )

            Divider()

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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            if devices.isEmpty {
                Text("No devices")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }

            ForEach(devices) { device in
                DeviceRow(
                    device: device,
                    input: input,
                    isSelected: device.id == selectedID,
                    action: { onSelect(device) }
                )
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
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(rowFill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var rowFill: Color {
        if isSelected { return Color.accentColor.opacity(0.15) }
        if isHovering { return Color.primary.opacity(0.08) }
        return .clear
    }
}
