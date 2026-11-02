import CoreAudio
import Observation

@MainActor
@Observable
final class AudioModel {
    private(set) var outputs: [AudioDevice] = []
    private(set) var inputs: [AudioDevice] = []
    private(set) var defaultOutput: AudioDeviceID = 0
    private(set) var defaultInput: AudioDeviceID = 0
    private(set) var outputVolume: Float?
    private(set) var inputVolume: Float?

    private var volumeListeners = Set<String>()

    init() {
        let systemSelectors = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultInputDevice,
        ]
        for selector in systemSelectors {
            CoreAudioDevices.addListener(CoreAudioDevices.system, selector) { [weak self] in
                Task { @MainActor in self?.refresh() }
            }
        }
        refresh()
    }

    var currentOutput: AudioDevice? {
        outputs.first { $0.id == defaultOutput }
    }

    func select(_ device: AudioDevice, input: Bool) {
        CoreAudioDevices.setDefault(device.id, input: input)
        refresh()
    }

    func setVolume(_ value: Float, input: Bool) {
        CoreAudioDevices.setVolume(value, device: input ? defaultInput : defaultOutput, input: input)
        if input {
            inputVolume = value
        } else {
            outputVolume = value
        }
    }

    func refresh() {
        let all = CoreAudioDevices.all()
        outputs = all.filter(\.hasOutput)
        inputs = all.filter(\.hasInput)
        defaultOutput = CoreAudioDevices.defaultDevice(input: false)
        defaultInput = CoreAudioDevices.defaultDevice(input: true)
        observeVolumes()
        refreshVolumes()
    }

    private func refreshVolumes() {
        outputVolume = CoreAudioDevices.volume(defaultOutput, input: false)
        inputVolume = CoreAudioDevices.volume(defaultInput, input: true)
    }

    /// Follows volume changes made elsewhere (keyboard keys, Control Center).
    private func observeVolumes() {
        for (id, input) in [(defaultOutput, false), (defaultInput, true)] where id != 0 {
            guard volumeListeners.insert("\(id)-\(input)").inserted else { continue }
            let scope = input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
            CoreAudioDevices.addListener(id, kAudioDevicePropertyVolumeScalar, scope: scope) { [weak self] in
                Task { @MainActor in self?.refreshVolumes() }
            }
        }
    }
}
