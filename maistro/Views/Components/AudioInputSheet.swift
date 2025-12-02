//
//  AudioInputSheet.swift
//  maistro
//
//  A sheet for selecting audio input sources (MIDI devices, microphones, etc.)

import SwiftUI

struct AudioInputSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var midiManager: MIDIManager

    var body: some View {
        NavigationView {
            List {
                // MIDI Devices Section
                Section {
                    if midiManager.availableDevices.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(themeManager.colors.neutralAccent)
                            Text("No MIDI devices found")
                                .foregroundColor(themeManager.colors.textSecondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(midiManager.availableDevices) { device in
                            MIDIDeviceRow(
                                device: device,
                                isConnected: midiManager.connectedDevice?.id == device.id,
                                onSelect: {
                                    midiManager.connect(to: device)
                                }
                            )
                        }
                    }

                    // Refresh button
                    Button {
                        midiManager.refreshDevices()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Devices")
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "pianokeys")
                        Text("MIDI Devices")
                    }
                } footer: {
                    Text("Connect a MIDI keyboard or controller to use it as input.")
                }

                // Microphone Section (placeholder for future)
                Section {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(themeManager.colors.neutralAccent)
                        Text("Coming soon")
                            .foregroundColor(themeManager.colors.textSecondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    HStack {
                        Image(systemName: "mic")
                        Text("Microphone")
                    }
                } footer: {
                    Text("Microphone input for pitch detection will be available in a future update.")
                }
            }
            .navigationTitle("Audio Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MIDIDeviceRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    let device: MIDIDevice
    let isConnected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .foregroundColor(themeManager.colors.textPrimary)
                        .fontWeight(isConnected ? .semibold : .regular)

                    Text(device.manufacturer)
                        .font(.caption)
                        .foregroundColor(themeManager.colors.textSecondary)
                }

                Spacer()

                if isConnected {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(themeManager.colors.confirmation)
                            .frame(width: 8, height: 8)
                        Text("Connected")
                            .font(.caption)
                            .foregroundColor(themeManager.colors.confirmation)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AudioInputSheet(midiManager: MIDIManager(config: MIDIManagerConfig.standard()))
        .environmentObject(ThemeManager.shared)
}
