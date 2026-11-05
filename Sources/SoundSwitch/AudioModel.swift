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

    /// Device UIDs, highest priority first, one list per direction.
    private var outputOrder: [String]
    private var inputOrder: [String]

    /// UIDs connected at the last refresh. Priority is enforced when this set changes.
    private var connectedUIDs: Set<String> = []
    private var lastTopologyChange = Date.distantPast
    /// After a connect or disconnect, keep enforcing for this long. macOS can finish its own
    /// auto-switch after our first callback, and this window puts priority back on top.
    private static let settleWindow: TimeInterval = 2

    private var volumeListeners = Set<String>()

    /// Off until the user reorders once, so launching the app never changes the current device.
    private var priorityEnabled: Bool

    private static let outputKey = "priority.output"
    private static let inputKey = "priority.input"
    private static let enabledKey = "priority.enabled"

    init() {
        outputOrder = UserDefaults.standard.stringArray(forKey: Self.outputKey) ?? []
        inputOrder = UserDefaults.standard.stringArray(forKey: Self.inputKey) ?? []
        priorityEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)

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

    /// Puts `uid` directly above `target` in the priority list and applies it right away.
    func move(_ uid: String, before target: String, input: Bool) {
        var order = order(input: input)
        guard uid != target, let from = order.firstIndex(of: uid) else { return }
        order.remove(at: from)
        order.insert(uid, at: order.firstIndex(of: target) ?? order.endIndex)
        setOrder(order, input: input)
        if !priorityEnabled {
            priorityEnabled = true
            UserDefaults.standard.set(true, forKey: Self.enabledKey)
        }

        let connected = CoreAudioDevices.all().filter { input ? $0.hasInput : $0.hasOutput }
        applyPriority(connected, input: input)
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
        let outs = all.filter(\.hasOutput)
        let ins = all.filter(\.hasInput)

        adoptNewDevices(outs, input: false)
        adoptNewDevices(ins, input: true)

        let uids = Set(all.map(\.uid))
        let topologyChanged = uids != connectedUIDs
        connectedUIDs = uids
        if topologyChanged {
            lastTopologyChange = .now
        }

        let settling = Date.now.timeIntervalSince(lastTopologyChange) < Self.settleWindow
        if priorityEnabled && (topologyChanged || settling) {
            applyPriority(outs, input: false)
            applyPriority(ins, input: true)
        }

        outputs = ranked(outs, input: false)
        inputs = ranked(ins, input: true)
        defaultOutput = CoreAudioDevices.defaultDevice(input: false)
        defaultInput = CoreAudioDevices.defaultDevice(input: true)
        observeVolumes()
        refreshVolumes()
    }

    private func refreshVolumes() {
        outputVolume = CoreAudioDevices.volume(defaultOutput, input: false)
        inputVolume = CoreAudioDevices.volume(defaultInput, input: true)
    }

    /// Selects the highest-priority device in `devices`, if it isn't already the default.
    private func applyPriority(_ devices: [AudioDevice], input: Bool) {
        guard let top = ranked(devices, input: input).first else { return }
        if CoreAudioDevices.defaultDevice(input: input) != top.id {
            CoreAudioDevices.setDefault(top.id, input: input)
        }
    }

    private func ranked(_ devices: [AudioDevice], input: Bool) -> [AudioDevice] {
        let order = order(input: input)
        return devices.sorted { lhs, rhs in
            (order.firstIndex(of: lhs.uid) ?? Int.max) < (order.firstIndex(of: rhs.uid) ?? Int.max)
        }
    }

    /// New devices go to the bottom of the list. Drag them up to change that.
    private func adoptNewDevices(_ devices: [AudioDevice], input: Bool) {
        var order = order(input: input)
        let new = devices.map(\.uid).filter { !order.contains($0) }
        guard !new.isEmpty else { return }
        order += new
        setOrder(order, input: input)
    }

    private func order(input: Bool) -> [String] {
        input ? inputOrder : outputOrder
    }

    private func setOrder(_ order: [String], input: Bool) {
        if input {
            inputOrder = order
            UserDefaults.standard.set(order, forKey: Self.inputKey)
        } else {
            outputOrder = order
            UserDefaults.standard.set(order, forKey: Self.outputKey)
        }
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
