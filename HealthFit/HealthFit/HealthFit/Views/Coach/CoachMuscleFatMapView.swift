import SwiftUI

/// Regiões corporais mapeadas no silhueta de corpo completo.
enum BodyFatRegion: String, CaseIterable, Identifiable, Hashable {
    case chest
    case core
    case deltoids
    case biceps
    case forearms
    case quads
    case adductors
    case calves

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: return "Peito"
        case .core: return "Core"
        case .deltoids: return "Deltoides"
        case .biceps: return "Bíceps"
        case .forearms: return "Antebraços"
        case .quads: return "Quadríceps"
        case .adductors: return "Adutores"
        case .calves: return "Panturrilhas"
        }
    }

    var shortTitle: String { title }

    /// Posição anatômica no silhueta corpo inteiro (0…1) — calibrado na arte atual.
    var muscleCenter: UnitPoint {
        switch self {
        case .deltoids: return UnitPoint(x: 0.64, y: 0.195)
        case .chest: return UnitPoint(x: 0.50, y: 0.255)
        case .biceps: return UnitPoint(x: 0.72, y: 0.305)
        case .core: return UnitPoint(x: 0.50, y: 0.385)
        case .forearms: return UnitPoint(x: 0.76, y: 0.415)
        case .quads: return UnitPoint(x: 0.40, y: 0.595)
        case .adductors: return UnitPoint(x: 0.46, y: 0.635)
        case .calves: return UnitPoint(x: 0.39, y: 0.855)
        }
    }

    /// Segundo ponto (lado oposto) para músculos bilaterais.
    var muscleCenterMirror: UnitPoint? {
        switch self {
        case .deltoids: return UnitPoint(x: 0.36, y: 0.195)
        case .biceps: return UnitPoint(x: 0.28, y: 0.305)
        case .forearms: return UnitPoint(x: 0.24, y: 0.415)
        case .quads: return UnitPoint(x: 0.60, y: 0.595)
        case .adductors: return UnitPoint(x: 0.54, y: 0.635)
        case .calves: return UnitPoint(x: 0.61, y: 0.855)
        case .chest, .core: return nil
        }
    }

    var muscleSize: CGSize {
        switch self {
        case .chest: return CGSize(width: 0.28, height: 0.065)
        case .core: return CGSize(width: 0.22, height: 0.095)
        case .deltoids: return CGSize(width: 0.12, height: 0.05)
        case .biceps: return CGSize(width: 0.09, height: 0.045)
        case .forearms: return CGSize(width: 0.09, height: 0.05)
        case .quads: return CGSize(width: 0.13, height: 0.10)
        case .adductors: return CGSize(width: 0.08, height: 0.06)
        case .calves: return CGSize(width: 0.10, height: 0.075)
        }
    }

    /// Posição do rótulo na coluna (espaçada — evita sobreposição).
    var labelSlotY: CGFloat {
        switch self {
        case .deltoids: return 0.16
        case .chest: return 0.22
        case .biceps: return 0.32
        case .core: return 0.38
        case .forearms: return 0.46
        case .quads: return 0.58
        case .adductors: return 0.70
        case .calves: return 0.86
        }
    }

    /// Coluna esquerda ou direita na UI.
    var isLeftColumn: Bool {
        switch self {
        case .chest, .core, .quads, .adductors: return true
        default: return false
        }
    }

    /// Ordem vertical na coluna (alinha com a figura).
    var columnOrder: Int {
        switch self {
        case .chest, .deltoids: return 0
        case .core, .biceps: return 1
        case .quads, .forearms: return 2
        case .adductors, .calves: return 3
        }
    }

    func fatPercent(in m: BodyMeasurements) -> Double? {
        switch self {
        case .chest: return m.chestFatPercent
        case .core: return m.coreFatPercent
        case .deltoids: return m.deltoidsFatPercent
        case .biceps: return m.bicepsFatPercent
        case .forearms: return m.forearmsFatPercent
        case .quads: return m.quadsFatPercent
        case .adductors: return m.adductorsFatPercent
        case .calves: return m.calvesFatPercent
        }
    }

    func setFatPercent(_ value: Double?, in m: inout BodyMeasurements) {
        switch self {
        case .chest: m.chestFatPercent = value
        case .core: m.coreFatPercent = value
        case .deltoids: m.deltoidsFatPercent = value
        case .biceps: m.bicepsFatPercent = value
        case .forearms: m.forearmsFatPercent = value
        case .quads: m.quadsFatPercent = value
        case .adductors: m.adductorsFatPercent = value
        case .calves: m.calvesFatPercent = value
        }
    }

    func circumferenceCm(in m: BodyMeasurements) -> Double? {
        switch self {
        case .chest: return m.chestCm
        case .core: return m.abdomenCm ?? m.waistCm
        case .deltoids: return m.shouldersCm
        case .biceps, .forearms: return average(m.rightArmCm, m.leftArmCm)
        case .quads, .adductors: return average(m.rightThighCm, m.leftThighCm)
        case .calves: return average(m.rightCalfCm, m.leftCalfCm)
        }
    }

    func setCircumferenceCm(_ value: Double?, in m: inout BodyMeasurements) {
        switch self {
        case .chest: m.chestCm = value
        case .core:
            m.abdomenCm = value
            if m.waistCm == nil { m.waistCm = value }
        case .deltoids: m.shouldersCm = value
        case .biceps, .forearms:
            m.rightArmCm = value
            m.leftArmCm = value
        case .quads, .adductors:
            m.rightThighCm = value
            m.leftThighCm = value
        case .calves:
            m.rightCalfCm = value
            m.leftCalfCm = value
        }
    }

    func intensity(in m: BodyMeasurements) -> Int {
        if let fat = fatPercent(in: m), fat > 0 {
            switch fat {
            case ..<10: return 1
            case ..<16: return 2
            case ..<22: return 3
            default: return 4
            }
        }
        if let cm = circumferenceCm(in: m), cm > 0 { return 2 }
        return 0
    }

    private func average(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (l?, r?): return (l + r) / 2
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    func value(in m: BodyMeasurements) -> Double? { fatPercent(in: m) }
    func setValue(_ value: Double?, in m: inout BodyMeasurements) { setFatPercent(value, in: &m) }
    func loadLevel(from percent: Double?) -> Int {
        guard let percent, percent > 0 else { return 0 }
        switch percent {
        case ..<10: return 1
        case ..<16: return 2
        case ..<22: return 3
        default: return 4
        }
    }
}

enum BodyFatLoadPalette {
    static func color(level: Int) -> Color {
        switch level {
        case 0: return Color(white: 0.28)
        case 1: return Color(red: 0.16, green: 0.42, blue: 0.20)
        case 2: return Color(red: 0.22, green: 0.58, blue: 0.28)
        case 3: return Color(red: 0.35, green: 0.78, blue: 0.32)
        default: return Color(red: 0.55, green: 0.95, blue: 0.40)
        }
    }
}

/// Mapa corporal completo: cada rótulo acende o músculo correspondente na figura.
struct CoachMuscleFatMapView: View {
    @Binding var measurements: BodyMeasurements
    @Binding var selectedRegion: BodyFatRegion?

    @State private var measureText = ""
    @State private var fatText = ""

    private let mapAssetName = "BodyFatRegionMap"
    private let figureAspect: CGFloat = 291.0 / 825.0

    var body: some View {
        VStack(spacing: 14) {
            Text("Gordura por região")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            fullBodyMap
                .frame(height: 420)

            greenScaleLegend

            Text("Toque no músculo ou no nome para inserir a medida (cm) e o % de gordura.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let region = selectedRegion {
                regionEditor(region)
            }

            regionValuesGrid
        }
        .padding(16)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onChange(of: selectedRegion) { _, region in
            guard let region else { return }
            syncEditorTexts(from: region)
        }
    }

    private var fullBodyMap: some View {
        GeometryReader { geo in
            let sideW = min(100.0, geo.size.width * 0.27)
            let figureH = geo.size.height
            // Largura pela altura mantendo aspect — a imagem preenche o retângulo.
            let figureW = figureH * figureAspect
            let totalW = sideW * 2 + figureW + 8
            let scale = min(1, geo.size.width / max(totalW, 1))
            let sSide = sideW * scale
            let sFigW = figureW * scale
            let sFigH = figureH * scale

            HStack(alignment: .center, spacing: 4 * scale) {
                labelColumn(
                    regions: BodyFatRegion.allCases.filter(\.isLeftColumn).sorted { $0.columnOrder < $1.columnOrder },
                    trailingAlign: true,
                    height: sFigH,
                    width: sSide
                )
                .frame(width: sSide, height: sFigH)

                Image(mapAssetName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: sFigW, height: sFigH)
                    .overlay {
                        ZStack {
                            ForEach(BodyFatRegion.allCases) { region in
                                musclePatches(region, figureSize: CGSize(width: sFigW, height: sFigH))
                            }
                            ForEach(BodyFatRegion.allCases) { region in
                                hitZones(for: region, in: CGSize(width: sFigW, height: sFigH))
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                labelColumn(
                    regions: BodyFatRegion.allCases.filter { !$0.isLeftColumn }.sorted { $0.columnOrder < $1.columnOrder },
                    trailingAlign: false,
                    height: sFigH,
                    width: sSide
                )
                .frame(width: sSide, height: sFigH)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel("Mapa corporal completo por região")
    }

    private func labelColumn(
        regions: [BodyFatRegion],
        trailingAlign: Bool,
        height: CGFloat,
        width: CGFloat
    ) -> some View {
        ZStack {
            ForEach(regions) { region in
                Button {
                    select(region)
                } label: {
                    VStack(alignment: trailingAlign ? .trailing : .leading, spacing: 2) {
                        Text(region.shortTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(trailingAlign ? .trailing : .leading)
                        Text(measureCaption(for: region))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(measureColor(for: region))
                    }
                    .frame(maxWidth: .infinity, alignment: trailingAlign ? .trailing : .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(selectedRegion == region
                                  ? BodyFatLoadPalette.color(level: 3).opacity(0.28)
                                  : Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .frame(width: width - 4, height: 40)
                .position(
                    x: width / 2,
                    y: height * region.labelSlotY
                )
            }
        }
    }

    private func musclePatches(_ region: BodyFatRegion, figureSize: CGSize) -> some View {
        let level = region.intensity(in: measurements)
        let selected = selectedRegion == region
        let show = level > 0 || selected
        let opacity: Double = {
            if selected { return 0.62 }
            if level == 0 { return 0 }
            return 0.28 + Double(level) * 0.12
        }()
        let color = BodyFatLoadPalette.color(level: max(level, selected ? 3 : 0))

        return ZStack {
            patch(at: region.muscleCenter, size: region.muscleSize, in: figureSize, color: color, opacity: opacity, selected: selected, visible: show)
            if let mirror = region.muscleCenterMirror {
                patch(at: mirror, size: region.muscleSize, in: figureSize, color: color, opacity: opacity, selected: selected, visible: show)
            }
        }
        .allowsHitTesting(false)
    }

    private func hitZones(for region: BodyFatRegion, in figureSize: CGSize) -> some View {
        ZStack {
            hitButton(at: region.muscleCenter, size: region.muscleSize, in: figureSize) {
                select(region)
            }
            if let mirror = region.muscleCenterMirror {
                hitButton(at: mirror, size: region.muscleSize, in: figureSize) {
                    select(region)
                }
            }
        }
    }

    private func hitButton(at center: UnitPoint, size: CGSize, in figureSize: CGSize, action: @escaping () -> Void) -> some View {
        let w = figureSize.width * size.width * 1.2
        let h = figureSize.height * size.height * 1.2
        return Button(action: action) {
            Color.clear
                .frame(width: w, height: h)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .position(
            x: figureSize.width * center.x,
            y: figureSize.height * center.y
        )
        .accessibilityLabel("Selecionar região")
    }

    private func select(_ region: BodyFatRegion) {
        selectedRegion = region
        syncEditorTexts(from: region)
    }

    private func patch(
        at center: UnitPoint,
        size: CGSize,
        in figureSize: CGSize,
        color: Color,
        opacity: Double,
        selected: Bool,
        visible: Bool
    ) -> some View {
        let w = figureSize.width * size.width
        let h = figureSize.height * size.height
        return Capsule(style: .continuous)
            .fill(color.opacity(visible ? opacity : 0))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(selected ? Color.white : Color.clear, lineWidth: 2)
            )
            .frame(width: w, height: h)
            .position(
                x: figureSize.width * center.x,
                y: figureSize.height * center.y
            )
    }

    private func measureCaption(for region: BodyFatRegion) -> String {
        if let cm = region.circumferenceCm(in: measurements) {
            return String(format: "%.0f cm", cm)
        }
        if let fat = region.fatPercent(in: measurements) {
            return String(format: "%.0f%%", fat)
        }
        return "Medir"
    }

    private func measureColor(for region: BodyFatRegion) -> Color {
        let level = region.intensity(in: measurements)
        if level == 0 { return Color.white.opacity(0.4) }
        return BodyFatLoadPalette.color(level: max(level, 2))
    }

    private var greenScaleLegend: some View {
        HStack(alignment: .bottom, spacing: 5) {
            Text("Escala")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(BodyFatLoadPalette.color(level: level))
                    .frame(width: 11, height: 8 + CGFloat(level) * 5)
            }
        }
    }

    private var regionValuesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(BodyFatRegion.allCases) { region in
                let cm = region.circumferenceCm(in: measurements)
                let fat = region.fatPercent(in: measurements)
                Button {
                    select(region)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(region.shortTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        HStack {
                            Text(cm.map { String(format: "%.0f cm", $0) } ?? "— cm")
                                .font(.caption2.monospacedDigit())
                            Spacer()
                            Text(fat.map { String(format: "%.0f%%", $0) } ?? "—%")
                                .font(.caption2.monospacedDigit().weight(.bold))
                                .foregroundStyle(BodyFatLoadPalette.color(level: region.intensity(in: measurements)))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                selectedRegion == region
                                    ? BodyFatLoadPalette.color(level: 3).opacity(0.18)
                                    : Color.white.opacity(0.06)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func regionEditor(_ region: BodyFatRegion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(region.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Medida corporal (cm)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                HStack {
                    TextField("ex: 92", text: $measureText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: measureText) { _, newValue in
                            var m = measurements
                            region.setCircumferenceCm(parseNumber(newValue), in: &m)
                            measurements = m
                        }
                    Text("cm")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("% de gordura na região")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                HStack {
                    TextField("ex: 18", text: $fatText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: fatText) { _, newValue in
                            var m = measurements
                            region.setFatPercent(parseNumber(newValue), in: &m)
                            measurements = m
                        }
                    Text("%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Slider(
                    value: Binding(
                        get: { region.fatPercent(in: measurements) ?? 0 },
                        set: { newValue in
                            var m = measurements
                            let v = newValue <= 0.5 ? nil : (newValue * 10).rounded() / 10
                            region.setFatPercent(v, in: &m)
                            measurements = m
                            fatText = v.map { formatNumber($0) } ?? ""
                        }
                    ),
                    in: 0...40,
                    step: 0.5
                )
                .tint(BodyFatLoadPalette.color(level: 3))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func syncEditorTexts(from region: BodyFatRegion) {
        measureText = region.circumferenceCm(in: measurements).map { formatNumber($0) } ?? ""
        fatText = region.fatPercent(in: measurements).map { formatNumber($0) } ?? ""
    }

    private func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    private func parseNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else { return nil }
        return value
    }
}

struct CoachFatAssessmentInsights: View {
    let measurements: BodyMeasurements
    let heightCm: Double
    let gender: Gender

    var body: some View {
        let total = measurements.resolvedBodyFatPercent(heightCm: heightCm, gender: gender)
        let tips = recommendations
        return VStack(alignment: .leading, spacing: 10) {
            if let total {
                HStack {
                    Text("Gordura corporal estimada")
                    Spacer()
                    Text(BodyMeasurements.formatPercent(total))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(BodyFatLoadPalette.color(level: 3))
                }
                if measurements.bodyFatPercent == nil,
                   measurements.navyBodyFatPercent(heightCm: heightCm, gender: gender) != nil {
                    Text("Calculado pela fórmula US Navy (pescoço/cintura/quadril/altura).")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Text("A distribuição de gordura por região ajuda a equilibrar o treino e ajustar volume entre membros superiores e inferiores.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(tips, id: \.self) { tip in
                Label {
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textPrimary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BodyFatLoadPalette.color(level: 3))
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var recommendations: [String] {
        var tips: [String] = []
        let quads = measurements.quadsFatPercent ?? 0
        let chest = measurements.chestFatPercent ?? 0
        let core = measurements.coreFatPercent ?? 0
        let delts = measurements.deltoidsFatPercent ?? 0
        if quads >= 20 || (measurements.adductorsFatPercent ?? 0) >= 20 {
            tips.append("Reduzir o volume de pernas na próxima sessão.")
        }
        if chest < 12 && delts < 12 && (measurements.bicepsFatPercent ?? 0) < 12 {
            tips.append("Adicionar mais trabalho de membros superiores.")
        }
        if core >= 18 {
            tips.append("Incluir core anti-extensão conforme protocolo do personal.")
        }
        if tips.isEmpty {
            tips.append("Manter distribuição atual e reavaliar em 30 dias com as mesmas circunferências.")
        }
        return tips
    }
}
