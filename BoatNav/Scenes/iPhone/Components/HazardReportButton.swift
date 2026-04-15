import SwiftUI

struct HazardReportButton: View {
    @EnvironmentObject var hazardReportViewModel: HazardReportViewModel

    var body: some View {
        Button {
            Haptics.medium()
            withAnimation(Design.Animation.quick) {
                hazardReportViewModel.showCategoryPicker = true
            }
        } label: {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Design.Colors.amber)
                .frame(width: Design.Touch.minimum + 8, height: Design.Touch.minimum + 8)
                .glassCard(cornerRadius: Design.Corner.medium)
        }
        .buttonStyle(.boatNav)
    }
}

struct HazardCategoryPicker: View {
    @EnvironmentObject var hazardReportViewModel: HazardReportViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Melding plaatsen")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(Design.Animation.quick) {
                        hazardReportViewModel.showCategoryPicker = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(.quaternary, in: Circle())
                }
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.top, Design.Spacing.xl)
            .padding(.bottom, Design.Spacing.md)

            // Categories
            VStack(spacing: 2) {
                ForEach(HazardReport.HazardCategory.allCases, id: \.self) { category in
                    Button {
                        Haptics.selection()
                        hazardReportViewModel.addReport(category: category)
                        withAnimation(Design.Animation.quick) {
                            hazardReportViewModel.showCategoryPicker = false
                        }
                    } label: {
                        HStack(spacing: Design.Spacing.lg) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 20))
                                .foregroundStyle(Color(hex: category.iconColorHex))
                                .frame(width: 32)

                            Text(category.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, Design.Spacing.xl)
                        .padding(.vertical, Design.Spacing.md)
                    }

                    if category != HazardReport.HazardCategory.allCases.last {
                        Divider().padding(.leading, 66)
                    }
                }
            }
            .padding(.bottom, Design.Spacing.lg)
        }
    }
}

// MARK: - Color from hex

private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
