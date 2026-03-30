import SwiftUI

struct HazardReportButton: View {
    @EnvironmentObject var hazardReportViewModel: HazardReportViewModel

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                hazardReportViewModel.showCategoryPicker = true
            }
        } label: {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.orange, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
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
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
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
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Categories
            VStack(spacing: 2) {
                ForEach(HazardReport.HazardCategory.allCases, id: \.self) { category in
                    Button {
                        hazardReportViewModel.addReport(category: category)
                        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                            hazardReportViewModel.showCategoryPicker = false
                        }
                    } label: {
                        HStack(spacing: 14) {
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
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }

                    if category != HazardReport.HazardCategory.allCases.last {
                        Divider().padding(.leading, 66)
                    }
                }
            }
            .padding(.bottom, 16)
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
