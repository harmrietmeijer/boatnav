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
                .foregroundStyle(Design.Purple.p5)
                .frame(width: 52, height: 52)
                .background(Design.Ink.primary, in: RoundedRectangle(cornerRadius: Design.Corner.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Design.Corner.lg, style: .continuous)
                        .strokeBorder(Color(hex: 0x3C2875), lineWidth: 1)
                )
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
                    .foregroundStyle(Design.Purple.p5)
                Spacer()
                Button {
                    withAnimation(Design.Animation.quick) {
                        hazardReportViewModel.showCategoryPicker = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Design.Purple.p4)
                        .frame(width: 28, height: 28)
                        .background(Design.Purple.p3.opacity(0.15), in: RoundedRectangle(cornerRadius: Design.Corner.sm))
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
                                .font(.system(size: 18))
                                .foregroundStyle(Color(hex: category.iconColorHex))
                                .frame(width: 32)

                            Text(category.displayName)
                                .font(.subheadline)
                                .foregroundStyle(Design.Purple.p5)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Design.Purple.p3)
                        }
                        .padding(.horizontal, Design.Spacing.xl)
                        .padding(.vertical, Design.Spacing.md)
                    }

                    if category != HazardReport.HazardCategory.allCases.last {
                        Divider()
                            .background(Design.Purple.p3.opacity(0.2))
                            .padding(.leading, 66)
                    }
                }
            }
            .padding(.bottom, Design.Spacing.lg)
        }
    }
}

// MARK: - Color from hex string (used by hazard categories)

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
