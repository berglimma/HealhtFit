import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    var body: some View {
        TabView {
            activeWorkoutTab
            metricsTab
        }
        .tabViewStyle(.verticalPage)
    }

    private var activeWorkoutTab: some View {
        VStack(spacing: 12) {
            if workoutManager.isActive {
                Text(workoutManager.workoutName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if workoutManager.isResting {
                    restSection
                } else {
                    exerciseSection
                }

                Button("Encerrar") {
                    workoutManager.stopWorkout()
                }
                .tint(.red)
            } else {
                Image(systemName: "heart.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("HealthFit")
                    .font(.headline)
                Text("Aguardando treino do iPhone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private var exerciseSection: some View {
        Group {
            Text("\(Int(workoutManager.heartRate))")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.red)
            Text("BPM")
                .font(.caption)

            HStack {
                VStack {
                    Text("\(Int(workoutManager.calories))")
                        .font(.title3.bold())
                    Text("kcal")
                        .font(.caption2)
                }
            }
        }
    }

    private var restSection: some View {
        Group {
            Text("Descanso")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !workoutManager.restExerciseName.isEmpty {
                Text(workoutManager.restExerciseName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            Text(restTimeText)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(workoutManager.isRestOvertime ? .red : .green)

            if workoutManager.isRestOvertime {
                Text("Hora de voltar!")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            HStack {
                VStack {
                    Text("\(Int(workoutManager.heartRate))")
                        .font(.title3.bold())
                        .foregroundStyle(.red)
                    Text("BPM")
                        .font(.caption2)
                }
            }
        }
    }

    private var restTimeText: String {
        if workoutManager.isRestOvertime {
            let seconds = workoutManager.restOvertimeSeconds
            let minutes = max(seconds, 0) / 60
            let secs = max(seconds, 0) % 60
            return String(format: "+%02d:%02d", minutes, secs)
        }
        let seconds = workoutManager.restRemainingSeconds
        let minutes = max(seconds, 0) / 60
        let secs = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private var metricsTab: some View {
        VStack(spacing: 8) {
            Label("Sincronizado", systemImage: "iphone.and.arrow.forward")
                .font(.caption)
            Text("Dados enviados automaticamente para o iPhone durante o treino.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    WatchContentView()
        .environmentObject(WatchWorkoutManager())
}
