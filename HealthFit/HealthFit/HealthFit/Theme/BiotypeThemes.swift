//
//  BiotypeCard.swift
//  HealthFit
//
//  Created by Luan Carlos on 26/06/26.
//

import SwiftUI
import Combine
import Foundation

enum BiotypeThemes: String, CaseIterable, Identifiable {
    case ectomorph = "Ectomorfo"
    case mesomorph = "Mesomorfo"
    case endomorph = "Endomorfo"

    var id: Self { self }

    var icon: String {
        switch self {
        case .ectomorph:
            return "figure.run"
        case .mesomorph:
            return "figure.strengthtraining.traditional"
        case .endomorph:
            return "figure.walk"
        }
    }

    var color: Color {
        switch self {
        case .ectomorph:
            return .blue
        case .mesomorph:
            return .green
        case .endomorph:
            return .orange
        }
    }
}
