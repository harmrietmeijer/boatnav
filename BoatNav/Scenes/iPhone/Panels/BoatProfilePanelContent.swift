import SwiftUI
import PhotosUI

struct BoatProfilePanelContent: View {
    @EnvironmentObject var boatProfileVM: BoatProfileViewModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name, height, beam, draft
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "sailboat.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Bootprofiel")
                    .font(.title2.bold())
                Spacer()
            }

            // Avatar
            VStack(spacing: 12) {
                PhotosPicker(selection: $boatProfileVM.selectedPhotoItem, matching: .images) {
                    if let image = boatProfileVM.avatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.white.opacity(0.3), lineWidth: 2)
                            )
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .frame(width: 100, height: 100)
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
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .height }
            }

            // Dimensions
            VStack(alignment: .leading, spacing: 14) {
                Text("Afmetingen")
                    .font(.subheadline.bold())
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
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

            // Info
            if boatProfileVM.isConfigured {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Afmetingen worden meegenomen in routeberekening")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.orange)
                    Text("Vul afmetingen in voor brughoogte- en diepgangwaarschuwingen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
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

    private func dimensionRow(
        icon: String, label: String, value: Binding<Double>, unit: String, hint: String,
        field: Field, nextField: Field?
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
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
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: field)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
        }
    }
}
