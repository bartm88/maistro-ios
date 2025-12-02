//
//  MIDIManager.swift
//  maistro
//
//  A service that manages CoreMIDI connections and forwards MIDI note events
//  to a NoteInputListener for processing.

import Foundation
import CoreMIDI
import Combine

/// Configuration for the MIDI manager
struct MIDIManagerConfig {
    /// Name for the MIDI client
    let clientName: String

    /// Name for the input port
    let inputPortName: String

    static func standard() -> MIDIManagerConfig {
        MIDIManagerConfig(
            clientName: "Maistro",
            inputPortName: "Maistro Input"
        )
    }
}

/// Represents a connected MIDI device
struct MIDIDevice: Identifiable, Equatable {
    let id: MIDIEndpointRef
    let name: String
    let manufacturer: String

    static func == (lhs: MIDIDevice, rhs: MIDIDevice) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manager for MIDI input from external devices
@MainActor
final class MIDIManager: ObservableObject {
    private let config: MIDIManagerConfig

    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0

    /// Currently connected MIDI sources
    @Published private(set) var availableDevices: [MIDIDevice] = []

    /// Currently connected device (if any)
    @Published private(set) var connectedDevice: MIDIDevice?

    /// Whether MIDI is successfully initialized
    @Published private(set) var isInitialized: Bool = false

    /// The note input listener to forward events to
    private var noteInputListener: NoteInputListener?

    /// Lock for thread-safe access to the listener
    private let listenerLock = NSLock()

    init(config: MIDIManagerConfig) {
        self.config = config
    }

    /// Set the note input listener to receive MIDI events
    func setNoteInputListener(_ listener: NoteInputListener?) {
        listenerLock.lock()
        noteInputListener = listener
        listenerLock.unlock()
    }

    /// Initialize the MIDI system
    func initialize() {
        guard !isInitialized else { return }

        // Create MIDI client with notification callback
        let clientName = config.clientName as CFString
        var client: MIDIClientRef = 0

        let status = MIDIClientCreateWithBlock(clientName, &client) { [weak self] notification in
            Task { @MainActor in
                self?.handleMIDINotification(notification)
            }
        }

        guard status == noErr else {
            print("MIDIManager: Failed to create MIDI client: \(status)")
            return
        }

        midiClient = client

        // Create input port with protocol (iOS 14+/macOS 11+)
        let portName = config.inputPortName as CFString
        var port: MIDIPortRef = 0

        let portStatus = MIDIInputPortCreateWithProtocol(
            midiClient,
            portName,
            MIDIProtocolID._1_0,
            &port
        ) { [weak self] eventList, srcConnRefCon in
            self?.handleMIDIEventList(eventList)
        }

        guard portStatus == noErr else {
            print("MIDIManager: Failed to create input port: \(portStatus)")
            return
        }

        inputPort = port
        isInitialized = true

        // Scan for available devices
        refreshDevices()

        // Auto-connect to first available device
        if let firstDevice = availableDevices.first {
            connect(to: firstDevice)
        }

        print("MIDIManager: Initialized successfully")
    }

    /// Refresh the list of available MIDI devices
    func refreshDevices() {
        var devices: [MIDIDevice] = []

        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let endpoint = MIDIGetSource(i)
            if let device = createDevice(from: endpoint) {
                devices.append(device)
            }
        }

        availableDevices = devices
        print("MIDIManager: Found \(devices.count) MIDI source(s)")

        // Check if connected device is still available
        if let connected = connectedDevice,
           !devices.contains(where: { $0.id == connected.id }) {
            connectedDevice = nil
        }
    }

    /// Connect to a specific MIDI device
    func connect(to device: MIDIDevice) {
        guard isInitialized else {
            print("MIDIManager: Cannot connect - not initialized")
            return
        }

        // Disconnect from current device if any
        if let current = connectedDevice {
            MIDIPortDisconnectSource(inputPort, current.id)
        }

        // Connect to new device
        let status = MIDIPortConnectSource(inputPort, device.id, nil)

        if status == noErr {
            connectedDevice = device
            print("MIDIManager: Connected to \(device.name)")
        } else {
            print("MIDIManager: Failed to connect to \(device.name): \(status)")
        }
    }

    /// Disconnect from the current MIDI device
    func disconnect() {
        guard let device = connectedDevice else { return }

        MIDIPortDisconnectSource(inputPort, device.id)
        connectedDevice = nil
        print("MIDIManager: Disconnected from \(device.name)")
    }

    /// Shut down the MIDI system
    func shutdown() {
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
            inputPort = 0
        }

        if midiClient != 0 {
            MIDIClientDispose(midiClient)
            midiClient = 0
        }

        isInitialized = false
        connectedDevice = nil
        availableDevices = []

        print("MIDIManager: Shut down")
    }

    // MARK: - Private Methods

    private func createDevice(from endpoint: MIDIEndpointRef) -> MIDIDevice? {
        guard endpoint != 0 else { return nil }

        var name: Unmanaged<CFString>?
        var manufacturer: Unmanaged<CFString>?

        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyManufacturer, &manufacturer)

        let deviceName = (name?.takeRetainedValue() as String?) ?? "Unknown Device"
        let deviceManufacturer = (manufacturer?.takeRetainedValue() as String?) ?? "Unknown"

        return MIDIDevice(
            id: endpoint,
            name: deviceName,
            manufacturer: deviceManufacturer
        )
    }

    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        switch notification.pointee.messageID {
        case .msgSetupChanged, .msgObjectAdded, .msgObjectRemoved:
            refreshDevices()

            // Auto-connect if we lost connection and a device is available
            if connectedDevice == nil, let firstDevice = availableDevices.first {
                connect(to: firstDevice)
            }

        default:
            break
        }
    }

    private func handleMIDIEventList(_ eventListPtr: UnsafePointer<MIDIEventList>) {
        // Use withUnsafePointer to safely iterate through packets
        withUnsafePointer(to: eventListPtr.pointee.packet) { firstPacketPtr in
            var packetPtr = UnsafeMutablePointer(mutating: firstPacketPtr)

            for _ in 0..<eventListPtr.pointee.numPackets {
                processEventPacket(packetPtr.pointee)
                packetPtr = MIDIEventPacketNext(packetPtr)
            }
        }
    }

    private func processEventPacket(_ packet: MIDIEventPacket) {
        let timestamp = packet.timeStamp
        let wordCount = packet.wordCount

        guard wordCount > 0 else { return }

        // Get the first word which contains the MIDI message
        let words = Mirror(reflecting: packet.words).children.map { $0.value as! UInt32 }

        for i in 0..<Int(wordCount) {
            guard i < words.count else { break }
            let word = words[i]
            processMIDI1Word(word, timestamp: timestamp)
        }
    }

    private func processMIDI1Word(_ word: UInt32, timestamp: MIDITimeStamp) {
        // MIDI 1.0 Channel Voice messages in UMP format:
        // Bits 31-28: Message Type (0x2 for MIDI 1.0 Channel Voice)
        // Bits 27-24: Group
        // Bits 23-20: Status (note on = 0x9, note off = 0x8)
        // Bits 19-16: Channel
        // Bits 15-8: Note number (or data byte 1)
        // Bits 7-0: Velocity (or data byte 2)

        let messageType = (word >> 28) & 0x0F
        let statusNibble = (word >> 20) & 0x0F
        let noteNumber = UInt8((word >> 8) & 0x7F)
        let velocity = UInt8(word & 0x7F)

        // Check for MIDI 1.0 Channel Voice message (type 0x2)
        guard messageType == 0x2 else { return }

        let timestampMs = midiTimestampToMs(timestamp)

        switch statusNibble {
        case 0x9: // Note On
            if velocity > 0 {
                let pitchDeciHz = midiNoteToDeciHz(noteNumber)
                sendNoteStart(pitchDeciHz: pitchDeciHz, timestampMs: timestampMs)
            } else {
                // Velocity 0 is treated as note off
                let pitchDeciHz = midiNoteToDeciHz(noteNumber)
                sendNoteEnd(pitchDeciHz: pitchDeciHz, timestampMs: timestampMs)
            }

        case 0x8: // Note Off
            let pitchDeciHz = midiNoteToDeciHz(noteNumber)
            sendNoteEnd(pitchDeciHz: pitchDeciHz, timestampMs: timestampMs)

        default:
            break
        }
    }

    private func sendNoteStart(pitchDeciHz: UInt32, timestampMs: UInt64) {
        listenerLock.lock()
        let listener = noteInputListener
        listenerLock.unlock()

        guard let listener = listener else { return }

        Task {
            await listener.noteStarted(pitchDeciHz: pitchDeciHz, timestampMs: timestampMs)
        }
    }

    private func sendNoteEnd(pitchDeciHz: UInt32, timestampMs: UInt64) {
        listenerLock.lock()
        let listener = noteInputListener
        listenerLock.unlock()

        guard let listener = listener else { return }

        Task {
            await listener.noteEnded(pitchDeciHz: pitchDeciHz, timestampMs: timestampMs)
        }
    }

    /// Convert MIDI timestamp (host ticks) to milliseconds since epoch
    private func midiTimestampToMs(_ timestamp: MIDITimeStamp) -> UInt64 {
        // MIDI timestamps are in host ticks (Mach absolute time)
        // If timestamp is 0, use current time
        if timestamp == 0 {
            return UInt64(Date().timeIntervalSince1970 * 1000)
        }

        // Convert host ticks to nanoseconds
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)

        let hostTicks = timestamp
        let nanos = hostTicks * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)

        // Convert to milliseconds and add to a reference point
        // Note: This gives relative time from boot, which is fine for our use case
        // since we care about relative timing between notes
        return nanos / 1_000_000
    }

    /// Convert MIDI note number to frequency in deciHz (tenths of Hz)
    /// Formula: f = 440 * 2^((n-69)/12)
    /// deciHz = f * 10
    private func midiNoteToDeciHz(_ noteNumber: UInt8) -> UInt32 {
        let exponent = (Double(noteNumber) - 69.0) / 12.0
        let frequency = 440.0 * pow(2.0, exponent)
        return UInt32(frequency * 10)
    }
}
