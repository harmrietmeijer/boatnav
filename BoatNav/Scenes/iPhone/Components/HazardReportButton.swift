import SwiftUI

struct HazardReportButton: View {
    @EnvironmentObject var hazardReportViewModel: HazardReportViewModel

    var body: some View {
        Button {
            hazardReportViewModel.showCategoryPicker = true
        } label: {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.orange, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $hazardReportViewModel.showCategoryPicker) {
            HazardCategoryPicker()
                .environmentObject(hazardReportViewModel)
                .presentationDetents([.medium])
        }
    }
}

struct HazardCategoryPicker: View {
    @EnvironmentObject var hazardReportViewModel: HazardReportViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(HazardReport.HazardCategory.allCases, id: \.self) { category in
                    Button {
                        hazardReportViewModel.addReport(category: category)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 22))
                                .foregroundStyle(Color(hex: category.iconColorHex))
                                .frame(width: 32)

                            Text(category.displayName)
                                .foregroundStyle(.primary)
                                .font(.body)

                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Melding plaatsen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
            }
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
