import SwiftUI
import RevenueCat

struct PaywallPanelContent: View {
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @Binding var activePanel: ActivePanel
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("BoatNav Pro")
                        .font(.title3.weight(.bold))
                    Spacer()
                }

                // Hero
                VStack(spacing: 8) {
                    Image(systemName: "sailboat.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Design.Colors.violet)

                    Text("Navigeer zorgeloos")
                        .font(.title2.weight(.bold))

                    Text("Upgrade voor volledige route-navigatie, brugwaarschuwingen en meer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Feature comparison
                VStack(spacing: 0) {
                    featureRow(icon: "map.fill", title: "Waterkaart & boeien", free: true, pro: true)
                    Divider().padding(.leading, 44)
                    featureRow(icon: "speedometer", title: "GPS snelheid", free: true, pro: true)
                    Divider().padding(.leading, 44)
                    featureRow(icon: "location.fill", title: "Route navigatie", free: false, pro: true)
                    Divider().padding(.leading, 44)
                    featureRow(icon: "arrow.up.and.down.square.fill", title: "Brughoogte-waarschuwingen", free: false, pro: true)
                    Divider().padding(.leading, 44)
                    featureRow(icon: "star.fill", title: "Onbeperkt favorieten", free: false, pro: true)
                    Divider().padding(.leading, 44)
                    featureRow(icon: "folder.fill", title: "Routes opslaan", free: false, pro: true)
                    Divider().padding(.leading, 44)
                    featureRow(icon: "car.fill", title: "CarPlay weergave", free: false, pro: true)
                }
                .glassCard()

                // Purchase buttons
                if let offerings = subscriptionManager.offerings?.current {
                    VStack(spacing: 12) {
                        // Yearly — primary
                        if let yearly = offerings.annual {
                            Button {
                                Task { await purchase(yearly) }
                            } label: {
                                VStack(spacing: 4) {
                                    HStack {
                                        Text("Jaarabonnement")
                                            .font(.headline)
                                        Spacer()
                                        Text(yearly.localizedPriceString)
                                            .font(.headline)
                                    }
                                    HStack {
                                        Text("7 dagen gratis proberen")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.8))
                                        Spacer()
                                        Text("/jaar")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                                .padding(.vertical, Design.Spacing.lg)
                                .padding(.horizontal, Design.Spacing.lg)
                                .background(Design.Colors.violet, in: RoundedRectangle(cornerRadius: Design.Corner.medium))
                                .foregroundStyle(.white)
                            }
                        }

                        // Lifetime
                        if let lifetime = offerings.lifetime {
                            Button {
                                Task { await purchase(lifetime) }
                            } label: {
                                HStack {
                                    Text("Lifetime")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(lifetime.localizedPriceString)
                                        .font(.subheadline.weight(.semibold))
                                    Text("eenmalig")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, Design.Spacing.lg)
                                .padding(.horizontal, Design.Spacing.lg)
                                .groupedCard()
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                } else {
                    ProgressView("Aanbiedingen laden...")
                        .padding()
                }

                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // Success
                if showSuccess {
                    Label("Je bent nu Pro!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Design.Colors.success)
                        .font(.subheadline.weight(.semibold))
                }

                // Restore
                Button("Aankopen herstellen") {
                    Task { await restore() }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Legal
                Text("Abonnement verlengt automatisch. Opzeggen kan via Instellingen → Apple ID.")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
        }
        .task {
            await subscriptionManager.loadOfferings()
        }
        .overlay {
            if subscriptionManager.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private func featureRow(icon: String, title: String, free: Bool, pro: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Design.Colors.violet)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)

            Spacer()

            Image(systemName: free ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(free ? Design.Colors.success : Color(.quaternaryLabel))
                .font(.system(size: 14))
                .frame(width: 36)

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Design.Colors.violet)
                .font(.system(size: 14))
                .frame(width: 36)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    private func purchase(_ package: Package) async {
        errorMessage = nil
        do {
            try await subscriptionManager.purchase(package: package)
            showSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                activePanel = .none
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        errorMessage = nil
        do {
            try await subscriptionManager.restorePurchases()
            if subscriptionManager.isPro {
                showSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    activePanel = .none
                }
            } else {
                errorMessage = "Geen actief abonnement gevonden"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
