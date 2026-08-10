import SwiftUI

struct BluetoothHeartRateSettingsView: View {
    @ObservedObject private var ble = BluetoothHeartRateService.shared
    @ObservedObject private var metrics = LiveMetricsHub.shared

    var body: some View {
        List {
            Section {
                Text(
                    "Batimentos ao vivo vêm de sensores Bluetooth com Heart Rate Service (cintas e alguns relógios). Passos e calorias do dia continuam vindo do Apple Saúde — ative a sincronização do app do seu relógio para o Saúde."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Status") {
                LabeledContent("Bluetooth") {
                    Text(bluetoothStateLabel)
                        .foregroundStyle(bluetoothStateColor)
                }
                LabeledContent("Sensor") {
                    Text(ble.connectedDevice?.displayName ?? "Nenhum")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("BPM ao vivo") {
                    Text(metrics.heartRateBPM > 0 ? "\(Int(metrics.heartRateBPM))" : "—")
                        .foregroundStyle(metrics.heartRateSource == .bluetooth ? .red : .secondary)
                }
                LabeledContent("Fonte atual") {
                    Text(metrics.heartRateSource.displayName)
                        .foregroundStyle(.secondary)
                }
                Text(ble.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = ble.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Conexão") {
                if ble.isConnected {
                    Button("Desconectar") {
                        ble.disconnect()
                    }
                    Button("Esquecer sensor", role: .destructive) {
                        ble.forgetDevice()
                    }
                } else {
                    Button(ble.isScanning ? "Parar busca" : "Buscar sensores") {
                        if ble.isScanning {
                            ble.stopScanning()
                        } else {
                            ble.startScanning()
                        }
                    }
                    if ble.preferredPeripheralId != nil {
                        Button("Reconectar último sensor") {
                            ble.reconnectPreferredIfPossible()
                        }
                    }
                }
            }

            if !ble.discoveredDevices.isEmpty {
                Section("Dispositivos encontrados") {
                    ForEach(ble.discoveredDevices) { device in
                        Button {
                            ble.connect(device)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.displayName)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("Sinal: \(device.rssi) dBm")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if ble.connectedDevice?.id == device.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                } else {
                                    Text("Conectar")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                        .disabled(ble.connectionState == .connecting)
                    }
                }
            }

            Section("Passos e calorias") {
                LabeledContent("Passos (hoje)") {
                    Text("\(metrics.todaySteps)")
                }
                LabeledContent("Calorias ativas (Saúde)") {
                    Text("\(Int(metrics.todayActiveCalories.rounded())) kcal")
                }
                Text(
                    "Prioridade de batimentos no treino: Apple Watch → Bluetooth → Apple Saúde."
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("Sensor Bluetooth")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            ble.stopScanning()
        }
    }

    private var bluetoothStateLabel: String {
        switch ble.connectionState {
        case .poweredOff: return "Desligado"
        case .unauthorized: return "Sem permissão"
        case .unsupported: return "Indisponível"
        case .scanning: return "Buscando…"
        case .connecting: return "Conectando…"
        case .connected: return "Conectado"
        case .idle: return "Ligado"
        }
    }

    private var bluetoothStateColor: Color {
        switch ble.connectionState {
        case .connected: return .green
        case .scanning, .connecting: return .orange
        case .poweredOff, .unauthorized, .unsupported: return .red
        case .idle: return .secondary
        }
    }
}
