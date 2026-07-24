import SwiftUI

/// Exibe carga recomendada e campo editável da carga que o aluno está usando.
struct ExerciseLoadEditor: View {
    let recommendedWeight: Double?
    @Binding var performedWeightText: String
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 10 : 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recomendada")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(recommendedLabel)
                    .font(compact ? .subheadline.weight(.semibold) : .title3.bold())
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sua carga")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 6) {
                    TextField("0", text: $performedWeightText)
                        .keyboardType(.decimalPad)
                        .font(compact ? .subheadline.weight(.semibold) : .title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, compact ? 8 : 10)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                        )

                    Text("kg")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(compact ? 10 : 12)
        .background(AppTheme.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var recommendedLabel: String {
        guard let recommendedWeight else { return "—" }
        return recommendedWeight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(recommendedWeight)) kg"
            : String(format: "%.1f kg", recommendedWeight)
    }

    static func text(from weight: Double?) -> String {
        guard let weight else { return "" }
        return weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))"
            : String(format: "%.1f", weight)
    }

    static func weight(from text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, let value = Double(normalized), value >= 0 else { return nil }
        return value
    }
}
