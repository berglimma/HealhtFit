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
                    if workoutManager.restSeconds > 0 {
                        VStack {
                            Text("\(workoutManager.restSeconds)")
                                .font(.title3.bold())
                            Text("descanso")
                                .font(.caption2)
                        }
                    }
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
