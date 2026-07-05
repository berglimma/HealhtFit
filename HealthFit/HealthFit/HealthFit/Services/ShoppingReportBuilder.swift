import Foundation

struct WeeklyShoppingReport {
    let periodLabel: String
    let totalItems: Int
    let purchasedCount: Int
    let pendingCount: Int
    let purchasedItems: [ShoppingItem]
    let pendingItems: [ShoppingItem]
    let topPurchasedAllTime: [ShoppingPurchaseStat]
    let topPurchasedThisWeek: [ShoppingPurchaseStat]
    let energyDrinksPerWeek: Int
    let generatedAt: Date

    var completionPercent: Int {
        guard totalItems > 0 else { return 0 }
        return Int((Double(purchasedCount) / Double(totalItems) * 100).rounded())
    }
}

enum ShoppingReportBuilder {
    static func build(
        shoppingList: [ShoppingItem],
        purchaseStats: [ShoppingPurchaseStat],
        energyDrinksPerWeek: Int,
        referenceDate: Date = .now
    ) -> WeeklyShoppingReport {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
        let periodLabel = formattedWeekRange(interval: weekInterval, referenceDate: referenceDate)

        let purchasedItems = shoppingList.filter(\.isPurchased)
        let pendingItems = shoppingList.filter { !$0.isPurchased }

        let topAllTime = purchaseStats.sorted {
            if $0.purchaseCount == $1.purchaseCount {
                return $0.lastPurchasedAt > $1.lastPurchasedAt
            }
            return $0.purchaseCount > $1.purchaseCount
        }

        let topThisWeek: [ShoppingPurchaseStat]
        if let weekInterval {
            topThisWeek = purchaseStats
                .filter { weekInterval.contains($0.lastPurchasedAt) }
                .sorted {
                    if $0.purchaseCount == $1.purchaseCount {
                        return $0.lastPurchasedAt > $1.lastPurchasedAt
                    }
                    return $0.purchaseCount > $1.purchaseCount
                }
        } else {
            topThisWeek = []
        }

        return WeeklyShoppingReport(
            periodLabel: periodLabel,
            totalItems: shoppingList.count,
            purchasedCount: purchasedItems.count,
            pendingCount: pendingItems.count,
            purchasedItems: purchasedItems.sorted { $0.category.rawValue < $1.category.rawValue },
            pendingItems: pendingItems.sorted { $0.category.rawValue < $1.category.rawValue },
            topPurchasedAllTime: topAllTime,
            topPurchasedThisWeek: topThisWeek,
            energyDrinksPerWeek: energyDrinksPerWeek,
            generatedAt: referenceDate
        )
    }

    static func textReport(_ report: WeeklyShoppingReport, athleteName: String = "Atleta") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "pt_BR")
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        var lines: [String] = [
            "Relatório de Compras — HealthFit",
            "Atleta: \(athleteName)",
            "Período: \(report.periodLabel)",
            "Gerado em: \(dateFormatter.string(from: report.generatedAt))",
            "",
            "Resumo da semana",
            "• Itens na lista: \(report.totalItems)",
            "• Comprados: \(report.purchasedCount)",
            "• Pendentes: \(report.pendingCount)",
            "• Progresso: \(report.completionPercent)%",
            "• Energéticos planejados: \(report.energyDrinksPerWeek) un/semana",
            ""
        ]

        if !report.purchasedItems.isEmpty {
            lines.append("Itens já comprados")
            for item in report.purchasedItems {
                lines.append("• \(item.name) — \(item.quantity) (\(item.category.rawValue))")
            }
            lines.append("")
        }

        if !report.pendingItems.isEmpty {
            lines.append("Itens pendentes")
            for item in report.pendingItems {
                lines.append("• \(item.name) — \(item.quantity) (\(item.category.rawValue))")
            }
            lines.append("")
        }

        if !report.topPurchasedThisWeek.isEmpty {
            lines.append("Mais comprados nesta semana")
            for (index, stat) in report.topPurchasedThisWeek.prefix(10).enumerated() {
                lines.append("\(index + 1). \(stat.displayName) — \(stat.purchaseCount)x")
            }
            lines.append("")
        }

        if !report.topPurchasedAllTime.isEmpty {
            lines.append("Mais comprados (histórico)")
            for (index, stat) in report.topPurchasedAllTime.prefix(10).enumerated() {
                let lastDate = shortDate(stat.lastPurchasedAt)
                lines.append("\(index + 1). \(stat.displayName) — \(stat.purchaseCount)x (última: \(lastDate))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func formattedWeekRange(interval: DateInterval?, referenceDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d MMM"

        guard let interval else {
            formatter.dateStyle = .medium
            return formatter.string(from: referenceDate)
        }

        let end = calendarSafeEnd(for: interval)
        return "\(formatter.string(from: interval.start)) – \(formatter.string(from: end))"
    }

    private static func calendarSafeEnd(for interval: DateInterval) -> Date {
        interval.end.addingTimeInterval(-1)
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d/M"
        return formatter.string(from: date)
    }
}
