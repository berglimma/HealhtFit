import AVFoundation
import Foundation
import WatchKit

/// Ejeta água do alto-falante do Apple Watch com uma sequência de tons
/// (mesmo princípio do Water Lock do sistema — move o diafragma do speaker).
@MainActor
final class WatchWaterEjection {
    static let shared = WatchWaterEjection()

    private var player: AVAudioPlayer?
    private(set) var isPlaying = false

    private init() {}

    /// Toca a sequência de ejeção. `onFinished` na main actor.
    func play(onFinished: (() -> Void)? = nil) {
        guard !isPlaying else { return }
        isPlaying = true
        WKInterfaceDevice.current().play(.click)

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .default, options: [])
            try session.setActive(true)

            let data = Self.makeEjectionWAV()
            let audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer.volume = 1.0
            audioPlayer.prepareToPlay()
            player = audioPlayer

            let duration = audioPlayer.duration
            audioPlayer.play()

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(max(duration + 0.15, 1.2)))
                self.finish(onFinished: onFinished)
            }
        } catch {
            #if DEBUG
            print("[HealthFitWatch] Water ejection failed: \(error.localizedDescription)")
            #endif
            finish(onFinished: onFinished)
        }
    }

    private func finish(onFinished: (() -> Void)?) {
        player?.stop()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        WKInterfaceDevice.current().play(.success)
        onFinished?()
    }

    /// WAV mono 16-bit com pulsos graves (~165 Hz), estilo ejeção do sistema.
    private static func makeEjectionWAV(
        sampleRate: Int = 22_050
    ) -> Data {
        // 8 pulsos curtos com pausas — empurra água pelo speaker.
        let pulseSeconds = 0.12
        let gapSeconds = 0.08
        let pulseCount = 8
        let frequency = 165.0

        let pulseSamples = Int(Double(sampleRate) * pulseSeconds)
        let gapSamples = Int(Double(sampleRate) * gapSeconds)
        let totalSamples = pulseCount * (pulseSamples + gapSamples)

        var pcm = [Int16]()
        pcm.reserveCapacity(totalSamples)

        for pulse in 0..<pulseCount {
            let amp = Int16(28_000 - pulse * 1_200)
            for i in 0..<pulseSamples {
                let t = Double(i) / Double(sampleRate)
                // Envelope suave para não estourar o speaker.
                let env = sin(Double.pi * Double(i) / Double(max(pulseSamples - 1, 1)))
                let sample = sin(2 * Double.pi * frequency * t) * Double(amp) * env
                pcm.append(Int16(clamping: Int(sample.rounded())))
            }
            pcm.append(contentsOf: repeatElement(0, count: gapSamples))
        }

        return wavData(pcm: pcm, sampleRate: sampleRate)
    }

    private static func wavData(pcm: [Int16], sampleRate: Int) -> Data {
        let dataSize = UInt32(pcm.count * 2)
        var data = Data()
        data.reserveCapacity(44 + Int(dataSize))

        func appendASCII(_ s: String) {
            data.append(contentsOf: s.utf8)
        }
        func appendUInt16(_ v: UInt16) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func appendUInt32(_ v: UInt32) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }

        appendASCII("RIFF")
        appendUInt32(36 + dataSize)
        appendASCII("WAVE")
        appendASCII("fmt ")
        appendUInt32(16) // PCM chunk
        appendUInt16(1) // audio format PCM
        appendUInt16(1) // mono
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * 2)) // byte rate
        appendUInt16(2) // block align
        appendUInt16(16) // bits
        appendASCII("data")
        appendUInt32(dataSize)

        for sample in pcm {
            var le = sample.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        return data
    }
}
