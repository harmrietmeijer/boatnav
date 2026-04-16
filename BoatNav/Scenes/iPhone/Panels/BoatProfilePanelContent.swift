import SwiftUI
import PhotosUI

struct BoatProfilePanelContent: View {
    @EnvironmentObject var boatProfileVM: BoatProfileViewModel
    @FocusState private var focusedField: Field?

    // Owner-bypass hidden activation — count taps within a short window
    @State private var secretTapCount: Int = 0
    @State private var secretTapTimer: Timer?
    @State private var showBypassConfirmation = false

    enum Field: Hashable {
        case name, height, beam, draft
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "sailboat.fill")
                    .font(.title2)
                    .foregroundStyle(Design.Blue.b4)
                    .contentShape(Rectangle())
                    .onTapGesture { handleSecretTap() }
                Text("Bootprofiel")
                    .font(.title2.weight(.regular))
                Spacer()
            }
            .alert("Pro-toegang geactiveerd", isPresented: $showBypassConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Alle Pro-functies zijn ontgrendeld op dit apparaat.")
            }

            // Avatar
            VStack(spacing: 12) {
                PhotosPicker(selection: $boatProfileVM.selectedPhotoItem, matching: .images) {
                    if let image = boatProfileVM.avatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: Design.Corner.xl))
                            .overlay(
                                RoundedRectangle(cornerRadius: Design.Corner.xl)
                                    .stroke(Design.Colors.border, lineWidth: 1)
                            )
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: Design.Corner.xl)
                                .fill(Design.Colors.bg)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Design.Corner.xl)
                                        .stroke(Design.Colors.border, lineWidth: 1)
                                )
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                Text("Foto")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Boat name
            VStack(alignment: .leading, spacing: 6) {
                Text("Naam boot")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Bijv. Zeemeeuw", text: $boatProfileVM.profile.name)
                    .textFieldStyle(.plain).padding(Design.Spacing.md).surfaceCard(cornerRadius: Design.Corner.sm)
                    .font(.body)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .height }
            }

            // Dimensions
            VStack(alignment: .leading, spacing: 14) {
                Text("Afmetingen")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                dimensionRow(
                    icon: "arrow.up.and.down",
                    label: "Doorvaarthoogte",
                    value: $boatProfileVM.profile.height,
                    unit: "m",
                    hint: "Hoogte boven waterlijn",
                    field: .height,
                    nextField: .beam
                )

                dimensionRow(
                    icon: "arrow.left.and.right",
                    label: "Breedte",
                    value: $boatProfileVM.profile.beam,
                    unit: "m",
                    hint: "Breedste punt",
                    field: .beam,
                    nextField: .draft
                )

                dimensionRow(
                    icon: "arrow.down",
                    label: "Diepgang",
                    value: $boatProfileVM.profile.draft,
                    unit: "m",
                    hint: "Onder waterlijn",
                    field: .draft,
                    nextField: nil
                )
            }
            .padding(Design.Spacing.lg)
            .surfaceCard()

            // Info
            if boatProfileVM.isConfigured {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Design.Green.g4)
                    Text("Afmetingen worden meegenomen in routeberekening")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Design.Amber.a5)
                    Text("Vul afmetingen in voor brughoogte- en diepgangwaarschuwingen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Design.Spacing.lg)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Gereed") {
                    focusedField = nil
                }
                .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Hidden Pro bypass

    /// Counts taps on the sailboat icon. 5 taps within 3 seconds
    /// activates the owner bypass for this device.
    private func handleSecretTap() {
        secretTapCount += 1
        secretTapTimer?.invalidate()
        secretTapTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            Task { @MainActor in secretTapCount = 0 }
        }

        if secretTapCount >= 5 {
            secretTapCount = 0
            secretTapTimer?.invalidate()
            Haptics.medium()
            Task { @MainActor in
                SubscriptionManager.shared.activateOwnerBypass()
                showBypassConfirmation = true
            }
        }
    }

    private func dimensionRow(
        icon: String, label: String, value: Binding<Double>, unit: String, hint: String,
        field: Field, nextField: Field?
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Design.Blue.b4)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 4) {
                TextField("0.0", value: value, format: .number.precision(.fractionLength(1)))
                    .font(.system(.body, design: .monospaced))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .textFieldStyle(.plain).padding(Design.Spacing.md).surfaceCard(cornerRadius: Design.Corner.sm)
                    .focused($focusedField, equals: field)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
        }
    }
}
