import SwiftUI

struct VisionWorkoutView: View {
    @StateObject private var visionService = VisionWorkoutService()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                if let session = visionService.captureSessionForPreview {
                    CameraPreviewView(session: session)
                        .ignoresSafeArea()
                } else {
                    AppTheme.background.ignoresSafeArea()
                }

                VStack {
                    postureBanner
                    Spacer()
                    repCounter
                    controlsBar
                }
            }
            .navigationTitle("Vision AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        visionService.stopDetection()
                        dismiss()
                    }
                }
            }
            .onAppear { visionService.startDetection() }
            .onDisappear { visionService.stopDetection() }
        }
    }

    private var postureBanner: some View {
        HStack {
            Image(systemName: postureIcon)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(visionService.postureStatus.rawValue)
                    .font(.headline)
                Text("Confiança: \(Int(visionService.confidence * 100))%")
                    .font(.caption)
            }
            Spacer()
            Text(visionService.currentPhase)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding()
        .background(postureColor.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    private var repCounter: some View {
        VStack(spacing: 8) {
            Text("\(visionService.repCount)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.spring, value: visionService.repCount)
            Text("Repetições")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var controlsBar: some View {
        HStack(spacing: 24) {
            Button {
                visionService.resetReps()
            } label: {
                Label("Resetar", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }

            Button {
                if visionService.isDetecting {
                    visionService.stopDetection()
                } else {
                    visionService.startDetection()
                }
            } label: {
                Image(systemName: visionService.isDetecting ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(visionService.isDetecting ? Color.red : AppTheme.accent)
                    .clipShape(Circle())
            }
        }
        .padding(.bottom, 40)
    }

    private var postureIcon: String {
        switch visionService.postureStatus {
        case .correct: return "checkmark.circle.fill"
        case .incorrect: return "exclamationmark.triangle.fill"
        case .unknown: return "eye.fill"
        }
    }

    private var postureColor: Color {
        switch visionService.postureStatus {
        case .correct: return .green
        case .incorrect: return .orange
        case .unknown: return .gray
        }
    }
}
