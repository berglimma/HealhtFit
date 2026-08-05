import Combine
import StoreKit
import SwiftUI

/// Paywall com os 4 planos mensais. Usar via sheet ou navigation.
struct PaywallView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var highlight: AppFeature?
    var title: String = "Desbloqueie o HealthFit"
    var onPurchaseSuccess: (() -> Void)?

    @State private var selectedTier: PlanTier = .complete
    @State private var showManage = false

    private let plans: [PlanMarketingCopy] = PlanTier.allCases
        .filter(\.isPaid)
        .map(PlanMarketingCopy.init)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    if let highlight {
                        lockedFeatureBanner(highlight)
                    }
                    plansStack
                    if let message = subscriptions.lastErrorMessage, !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                    purchaseButton
                    secondaryActions
                    LegalLinksView(style: .inline)
                        .padding(.top, 4)
                    Text("A assinatura renova automaticamente até cancelar. Gerencie em Ajustes → Apple ID.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .background(AppTheme.background)
            .navigationTitle("Assinaturas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .task {
                await subscriptions.refresh()
                if subscriptions.currentTier.isPaid {
                    selectedTier = max(selectedTier, subscriptions.currentTier)
                }
            }
            .manageSubscriptionsSheet(isPresented: $showManage)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.accentSecondary)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Escolha o plano ideal. Você pode mudar ou cancelar a qualquer momento.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private func lockedFeatureBanner(_ feature: AppFeature) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Disponível a partir do plano \(FeatureGate.minimumPlan(for: feature).displayName).")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var plansStack: some View {
        VStack(spacing: 12) {
            ForEach(plans) { plan in
                planCard(plan)
            }
        }
    }

    private func planCard(_ plan: PlanMarketingCopy) -> some View {
        let isSelected = selectedTier == plan.tier
        let isCurrent = subscriptions.currentTier == plan.tier

        return Button {
            selectedTier = plan.tier
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(plan.tier.displayName)
                                .font(.headline)
                                .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textPrimary)
                            if plan.isFeatured {
                                Text("Mais popular")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppTheme.accentSecondary.opacity(0.25))
                                    .foregroundStyle(AppTheme.accentSecondary)
                                    .clipShape(Capsule())
                            }
                            if isCurrent {
                                Text("Atual")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(plan.tier.tagline)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Text(subscriptions.displayPrice(for: plan.tier))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                ForEach(plan.bulletPoints, id: \.self) { line in
                    Label(line, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppTheme.accent.opacity(0.12) : AppTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(.plain)
    }

    private var purchaseButton: some View {
        Button {
            Task {
                let ok = await subscriptions.purchase(tier: selectedTier)
                if ok {
                    onPurchaseSuccess?()
                    dismiss()
                }
            }
        } label: {
            if subscriptions.purchaseInProgress {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                Text(subscriptions.currentTier == selectedTier
                      ? "Plano já ativo"
                      : "Assinar \(selectedTier.displayName)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(subscriptions.purchaseInProgress || subscriptions.currentTier == selectedTier)
    }

    private var secondaryActions: some View {
        VStack(spacing: 10) {
            Button("Restaurar compras") {
                Task { await subscriptions.restore() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.accent)

            Button("Gerenciar assinatura") {
                showManage = true
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

// MARK: - Tela “Meu plano” (Perfil)

struct SubscriptionPlanView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showPaywall = false
    @State private var showManage = false
    #if DEBUG
    @State private var debugSelection: Int = -1
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                currentPlanCard
                comparisonSection
                actions
                rolloutNote
                #if DEBUG
                debugSection
                #endif
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle("Meu plano")
        .navigationBarTitleDisplayMode(.large)
        .task { await subscriptions.refresh() }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptions)
        }
        .manageSubscriptionsSheet(isPresented: $showManage)
    }

    private var currentPlanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Plano atual", systemImage: "crown.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accentSecondary)
            Text(subscriptions.currentTier.displayName)
                .font(.title.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(subscriptions.currentTier.tagline)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            if !SubscriptionConfiguration.featureGatesEnabled {
                Text("Bloqueios de plano ainda desativados — o paywall e a loja já estão prontos.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comparativo")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            ForEach(PlanTier.allCases.filter(\.isPaid), id: \.self) { tier in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tier.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(tier.tagline)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(subscriptions.displayPrice(for: tier))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                showPaywall = true
            } label: {
                Label(
                    subscriptions.isSubscribed ? "Mudar de plano" : "Ver planos e assinar",
                    systemImage: "arrow.up.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Restaurar compras") {
                Task { await subscriptions.restore() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.accent)

            Button("Gerenciar na App Store") {
                showManage = true
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.textSecondary)

            if let message = subscriptions.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var rolloutNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Próximos passos")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text("""
            1. Criar grupo “HealthFit Plans” e os 4 product IDs na App Store Connect.
            2. Em Xcode: Scheme → Options → StoreKit Configuration → Products.storekit.
            3. Ativar featureGatesEnabled quando for bloquear IA, Nutrição e Relatórios.
            """)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    #if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEBUG — simular plano")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Picker("Plano", selection: $debugSelection) {
                Text("StoreKit real").tag(-1)
                ForEach(PlanTier.allCases) { tier in
                    Text(tier.displayName).tag(tier.rawValue)
                }
            }
            .onChange(of: debugSelection) { _, value in
                if value < 0 {
                    SubscriptionConfiguration.debugPlanOverride = nil
                } else {
                    SubscriptionConfiguration.debugPlanOverride = PlanTier(rawValue: value)
                }
                subscriptions.objectWillChange.send()
            }
            Toggle("Ativar feature gates", isOn: Binding(
                get: { SubscriptionConfiguration.featureGatesEnabled },
                set: {
                    SubscriptionConfiguration.featureGatesEnabled = $0
                    subscriptions.objectWillChange.send()
                }
            ))
            .tint(AppTheme.accent)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .onAppear {
            debugSelection = SubscriptionConfiguration.debugPlanOverride?.rawValue ?? -1
        }
    }
    #endif
}

// MARK: - Helpers de UI para locks futuros

/// Uso futuro: `.requiresSubscription(feature: .mealPlan) { MealPlanView() }`
struct RequiresSubscriptionModifier: ViewModifier {
    @EnvironmentObject private var subscriptions: SubscriptionService
    let feature: AppFeature
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .disabled(!subscriptions.canAccess(feature))
            .overlay {
                if !subscriptions.canAccess(feature) {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    Button {
                        showPaywall = true
                    } label: {
                        Label("Desbloquear \(feature.displayName)", systemImage: "lock.open.fill")
                            .padding()
                            .background(AppTheme.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(highlight: feature)
                    .environmentObject(subscriptions)
            }
    }
}

extension View {
    func requiresSubscription(_ feature: AppFeature) -> some View {
        modifier(RequiresSubscriptionModifier(feature: feature))
    }
}
