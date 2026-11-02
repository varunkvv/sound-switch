import CoreAudio

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let transport: UInt32
    let hasInput: Bool
    let hasOutput: Bool

    func symbol(input: Bool) -> String {
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return "headphones"
        case kAudioDeviceTransportTypeUSB:
            return "cable.connector"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort, kAudioDeviceTransportTypeThunderbolt:
            return "display"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate:
            return "square.stack.3d.up"
        case kAudioDeviceTransportTypeBuiltIn:
            return input ? "mic.fill" : "laptopcomputer"
        default:
            return input ? "mic" : "hifispeaker"
        }
    }
}

enum CoreAudioDevices {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    static func all() -> [AudioDevice] {
        var address = makeAddress(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap(device(_:))
    }

    static func defaultDevice(input: Bool) -> AudioDeviceID {
        let selector = input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
        return getValue(system, selector, initial: AudioDeviceID(0)) ?? 0
    }

    static func setDefault(_ id: AudioDeviceID, input: Bool) {
        let selector = input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
        var address = makeAddress(selector)
        var device = id
        AudioObjectSetPropertyData(system, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &device)
    }

    static func volume(_ id: AudioDeviceID, input: Bool) -> Float? {
        let scope = input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
        return getValue(id, kAudioDevicePropertyVolumeScalar, scope: scope, initial: Float(0))
            ?? getValue(id, kAudioDevicePropertyVolumeScalar, scope: scope, element: 1, initial: Float(0))
    }

    static func setVolume(_ value: Float, device id: AudioDeviceID, input: Bool) {
        let scope = input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
        for element: AudioObjectPropertyElement in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = makeAddress(kAudioDevicePropertyVolumeScalar, scope: scope, element: element)
            guard AudioObjectHasProperty(id, &address) else { continue }
            var volume = value
            AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<Float>.size), &volume)
        }
    }

    /// Calls `handler` on the main queue whenever `selector` changes on `object`.
    static func addListener(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        handler: @escaping () -> Void
    ) {
        var address = makeAddress(selector, scope: scope)
        AudioObjectAddPropertyListenerBlock(object, &address, DispatchQueue.main) { _, _ in handler() }
    }

    // MARK: - Private

    private static func device(_ id: AudioDeviceID) -> AudioDevice? {
        // The system keeps private helper aggregates around; they are flagged hidden.
        guard getValue(id, kAudioDevicePropertyIsHidden, initial: UInt32(0)) != 1 else { return nil }
        let hasInput = channelCount(id, scope: kAudioObjectPropertyScopeInput) > 0
        let hasOutput = channelCount(id, scope: kAudioObjectPropertyScopeOutput) > 0
        guard hasInput || hasOutput, let name = name(id) else { return nil }
        let transport = getValue(id, kAudioDevicePropertyTransportType, initial: UInt32(0)) ?? 0
        return AudioDevice(id: id, name: name, transport: transport, hasInput: hasInput, hasOutput: hasOutput)
    }

    private static func name(_ id: AudioDeviceID) -> String? {
        var address = makeAddress(kAudioObjectPropertyName)
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr else { return nil }
        return name as String
    }

    private static func channelCount(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var address = makeAddress(kAudioDevicePropertyStreamConfiguration, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr else { return 0 }
        let buffers = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func getValue<T>(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
        initial: T
    ) -> T? {
        var address = makeAddress(selector, scope: scope, element: element)
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func makeAddress(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }
}
