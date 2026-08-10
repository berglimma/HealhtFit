import Combine
import CoreBluetooth
import Foundation

struct BLEHeartRateDevice: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var rssi: Int

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Sensor sem nome" : trimmed
    }
}

enum BluetoothHeartRateConnectionState: Equatable {
    case poweredOff
    case unauthorized
    case unsupported
    case idle
    case scanning
    case connecting
    case connected
}

/// Conecta sensores/relógios que expõem o Heart Rate Service padrão (GATT 0x180D).
@MainActor
final class BluetoothHeartRateService: NSObject, ObservableObject {
    static let shared = BluetoothHeartRateService()

    nonisolated static let heartRateServiceUUID = CBUUID(string: "180D")
    nonisolated static let heartRateMeasurementUUID = CBUUID(string: "2A37")

    @Published private(set) var connectionState: BluetoothHeartRateConnectionState = .idle
    @Published private(set) var isScanning = false
    @Published private(set) var discoveredDevices: [BLEHeartRateDevice] = []
    @Published private(set) var connectedDevice: BLEHeartRateDevice?
    @Published private(set) var heartRateBPM: Double = 0
    @Published private(set) var statusMessage = "Bluetooth pronto para sensores de batimento."
    @Published private(set) var lastError: String?

    private var central: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var didAttemptAutoReconnect = false

    private let preferredIdKey = "healthfit.ble.hr.preferredPeripheralId"

    var preferredPeripheralId: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: preferredIdKey) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: preferredIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: preferredIdKey)
            }
        }
    }

    var isConnected: Bool { connectionState == .connected && connectedDevice != nil }

    /// Evita reconectar automaticamente após Desconectar / Esquecer.
    private var suppressAutoReconnect = false

    private override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: true
        ])
    }

    func startScanning() {
        lastError = nil
        guard central.state == .poweredOn else {
            applyCentralState(central.state)
            return
        }
        discoveredDevices.removeAll()
        peripheralsByID.removeAll(keepingCapacity: true)
        isScanning = true
        connectionState = .scanning
        statusMessage = "Procurando sensores com batimentos (BLE)…"
        central.scanForPeripherals(
            withServices: [Self.heartRateServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
        if connectionState == .scanning {
            connectionState = connectedPeripheral == nil ? .idle : .connected
        }
        if connectedPeripheral == nil {
            statusMessage = discoveredDevices.isEmpty
                ? "Nenhum sensor encontrado. Coloque o relógio/cinta em modo pareamento."
                : "Selecione um sensor na lista."
        }
    }

    func connect(_ device: BLEHeartRateDevice) {
        lastError = nil
        suppressAutoReconnect = false
        guard let peripheral = peripheralsByID[device.id] else {
            lastError = "Dispositivo não disponível. Escaneie novamente."
            return
        }
        stopScanning()
        connectionState = .connecting
        statusMessage = "Conectando a \(device.displayName)…"
        preferredPeripheralId = device.id
        connectedPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func disconnect() {
        suppressAutoReconnect = true
        if let peripheral = connectedPeripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        clearLiveConnection(forgetPreferred: false)
        statusMessage = "Sensor desconectado."
    }

    func forgetDevice() {
        suppressAutoReconnect = true
        if let peripheral = connectedPeripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        clearLiveConnection(forgetPreferred: true)
        statusMessage = "Sensor esquecido. Escaneie para parear outro."
    }

    /// Tenta religar o último sensor salvo (quando o Bluetooth está ligado).
    func reconnectPreferredIfPossible() {
        guard central.state == .poweredOn else { return }
        guard connectedPeripheral == nil, let id = preferredPeripheralId else { return }
        suppressAutoReconnect = false
        let peripherals = central.retrievePeripherals(withIdentifiers: [id])
        guard let peripheral = peripherals.first else {
            statusMessage = "Sensor salvo não encontrado. Escaneie novamente."
            return
        }
        peripheralsByID[peripheral.identifier] = peripheral
        let name = peripheral.name ?? connectedDevice?.name ?? "Sensor BLE"
        connect(BLEHeartRateDevice(id: peripheral.identifier, name: name, rssi: 0))
    }

    // MARK: - Parsing

    /// Decodifica a characteristic Heart Rate Measurement (0x2A37).
    nonisolated static func parseHeartRate(from data: Data) -> Double? {
        guard !data.isEmpty else { return nil }
        let flags = data[0]
        let isUint16 = (flags & 0x01) != 0
        if isUint16 {
            guard data.count >= 3 else { return nil }
            let value = UInt16(data[1]) | (UInt16(data[2]) << 8)
            return Double(value)
        }
        guard data.count >= 2 else { return nil }
        return Double(data[1])
    }

    // MARK: - Private

    private func applyCentralState(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            if connectionState == .poweredOff || connectionState == .unauthorized || connectionState == .unsupported {
                connectionState = .idle
            }
            statusMessage = "Bluetooth ligado. Escaneie ou reconecte o sensor."
            if !didAttemptAutoReconnect {
                didAttemptAutoReconnect = true
                reconnectPreferredIfPossible()
            }
        case .poweredOff:
            clearLiveConnection(forgetPreferred: false)
            connectionState = .poweredOff
            statusMessage = "Ligue o Bluetooth do iPhone para conectar sensores."
        case .unauthorized:
            clearLiveConnection(forgetPreferred: false)
            connectionState = .unauthorized
            statusMessage = "Permita o Bluetooth para o HealthFit em Ajustes."
            lastError = statusMessage
        case .unsupported:
            connectionState = .unsupported
            statusMessage = "Este iPhone não suporta Bluetooth LE."
            lastError = statusMessage
        case .resetting:
            statusMessage = "Bluetooth reiniciando…"
        case .unknown:
            statusMessage = "Aguardando Bluetooth…"
        @unknown default:
            statusMessage = "Estado Bluetooth desconhecido."
        }
    }

    private func clearLiveConnection(forgetPreferred: Bool) {
        stopScanning()
        connectedPeripheral?.delegate = nil
        connectedPeripheral = nil
        connectedDevice = nil
        heartRateBPM = 0
        if forgetPreferred {
            preferredPeripheralId = nil
        }
        if central.state == .poweredOn {
            connectionState = .idle
        }
    }

    private func upsertDiscovered(_ peripheral: CBPeripheral, rssi: Int, advertisementName: String?) {
        peripheralsByID[peripheral.identifier] = peripheral
        let name = advertisementName ?? peripheral.name ?? "Sensor BLE"
        let device = BLEHeartRateDevice(id: peripheral.identifier, name: name, rssi: rssi)
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }
        discoveredDevices.sort { $0.rssi > $1.rssi }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothHeartRateService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            self.applyCentralState(state)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let rssi = RSSI.intValue
        Task { @MainActor in
            self.upsertDiscovered(peripheral, rssi: rssi, advertisementName: name)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.connectionState = .connected
            let name = peripheral.name ?? self.connectedDevice?.name ?? "Sensor BLE"
            self.connectedDevice = BLEHeartRateDevice(id: peripheral.identifier, name: name, rssi: 0)
            self.statusMessage = "Conectado a \(name). Aguardando batimentos…"
            peripheral.discoverServices([Self.heartRateServiceUUID])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            self.connectionState = .idle
            self.connectedPeripheral = nil
            self.connectedDevice = nil
            self.lastError = error?.localizedDescription ?? "Falha ao conectar ao sensor."
            self.statusMessage = self.lastError ?? "Falha ao conectar."
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            let wasPreferred = peripheral.identifier == self.preferredPeripheralId
            self.connectedPeripheral = nil
            self.connectedDevice = nil
            self.heartRateBPM = 0
            self.connectionState = self.central.state == .poweredOn ? .idle : self.connectionState
            if let error {
                self.statusMessage = "Desconectado: \(error.localizedDescription)"
            } else {
                self.statusMessage = "Sensor desconectado."
            }
            if wasPreferred, !self.suppressAutoReconnect, self.central.state == .poweredOn {
                // Reconexão leve após queda acidental.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.reconnectPreferredIfPossible()
                }
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothHeartRateService: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                self.lastError = error.localizedDescription
                self.statusMessage = "Erro ao ler serviços: \(error.localizedDescription)"
                return
            }
            guard let service = peripheral.services?.first(where: { $0.uuid == Self.heartRateServiceUUID }) else {
                self.lastError = "Este aparelho não expõe batimentos por Bluetooth padrão."
                self.statusMessage = self.lastError ?? ""
                return
            }
            peripheral.discoverCharacteristics([Self.heartRateMeasurementUUID], for: service)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.lastError = error.localizedDescription
                return
            }
            guard let characteristic = service.characteristics?.first(where: {
                $0.uuid == Self.heartRateMeasurementUUID
            }) else {
                self.lastError = "Característica de batimentos não encontrada."
                return
            }
            peripheral.setNotifyValue(true, for: characteristic)
            self.statusMessage = "Recebendo batimentos do sensor."
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == Self.heartRateMeasurementUUID,
              let data = characteristic.value,
              error == nil else { return }
        let bpm = Self.parseHeartRate(from: data)
        Task { @MainActor in
            if let bpm, bpm > 0 {
                self.heartRateBPM = bpm
                HealthKitManager.shared.applyLiveWatchMetrics(heartRate: bpm, calories: nil, steps: nil)
            }
        }
    }
}
