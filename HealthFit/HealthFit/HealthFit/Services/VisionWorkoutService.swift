import Foundation
import Vision
@preconcurrency import AVFoundation
import Combine
import UIKit

enum PostureStatus: String {
    case correct = "Postura Correta"
    case incorrect = "Ajuste a Postura"
    case unknown = "Detectando..."
}

@MainActor
final class VisionWorkoutService: NSObject, ObservableObject {
    @Published var repCount = 0
    @Published var postureStatus: PostureStatus = .unknown
    @Published var isDetecting = false
    @Published var confidence: Float = 0
    @Published var currentPhase: String = "Aguardando"

    private var captureSession: AVCaptureSession?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.healthfit.vision", qos: .userInitiated)

    private var lastBodyPosition: CGPoint?
    private var isInDownPosition = false
    private var downThreshold: CGFloat = 0.6
    private var upThreshold: CGFloat = 0.4

    func startDetection() {
        guard !isDetecting else { return }
        setupCaptureSession()
        isDetecting = true
        repCount = 0
        postureStatus = .unknown
    }

    func stopDetection() {
        captureSession?.stopRunning()
        isDetecting = false
        postureStatus = .unknown
    }

    func resetReps() {
        repCount = 0
        isInDownPosition = false
        currentPhase = "Aguardando"
    }

    var captureSessionForPreview: AVCaptureSession? {
        captureSession
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }

        if session.canAddInput(input) { session.addInput(input) }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        captureSession = session

        let sessionBox = CaptureSessionBox(session)
        processingQueue.async {
            sessionBox.start()
        }
    }

    private func processBodyPose(_ observation: VNHumanBodyPoseObservation) {
        guard let nose = try? observation.recognizedPoint(.nose),
              let leftHip = try? observation.recognizedPoint(.leftHip),
              let rightHip = try? observation.recognizedPoint(.rightHip),
              let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              nose.confidence > 0.3,
              leftHip.confidence > 0.3,
              rightHip.confidence > 0.3 else {
            Task { @MainActor in
                postureStatus = .unknown
            }
            return
        }

        let hipY = (leftHip.location.y + rightHip.location.y) / 2
        let bodyAlignment = abs(leftShoulder.location.x - rightShoulder.location.x)
        let spineAngle = abs(nose.location.y - hipY)

        Task { @MainActor in
            confidence = nose.confidence

            if bodyAlignment < 0.15 && spineAngle > 0.2 {
                postureStatus = .correct
            } else {
                postureStatus = .incorrect
            }

            detectRepetition(hipY: hipY)
        }
    }

    private func detectRepetition(hipY: CGFloat) {
        if hipY < upThreshold && isInDownPosition {
            isInDownPosition = false
            repCount += 1
            currentPhase = "Subindo ↑"
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else if hipY > downThreshold && !isInDownPosition {
            isInDownPosition = true
            currentPhase = "Descendo ↓"
        } else if !isInDownPosition {
            currentPhase = "Posição Alta"
        }
    }
}

private final class CaptureSessionBox: @unchecked Sendable {
    let session: AVCaptureSession

    init(_ session: AVCaptureSession) {
        self.session = session
    }

    func start() {
        session.startRunning()
    }
}

extension VisionWorkoutService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard error == nil,
                  let observations = request.results as? [VNHumanBodyPoseObservation],
                  let body = observations.first else { return }
            Task { @MainActor in
                self?.processBodyPose(body)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }
}
