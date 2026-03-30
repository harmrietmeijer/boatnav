import SwiftUI
import CoreLocation

struct LocationSharingPanelContent: View {
    @EnvironmentObject var locationSharingViewModel: LocationSharingViewModel
    @Binding var activePanel: ActivePanel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Locatie delen")
                    .font(.title3.weight(.bold))
                Spacer()
            }
            .padding(.bottom, 20)

            VStack(spacing: 20) {
                // My sharing section
                sectionHeader("Mijn locatie")

                VStack(spacing: 0) {
                    // Display name
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                            .frame(width: 28, height: 28)
                            .background(Color.blue.opacity(0.12), in: Circle())

                        TextField("Naam (bijv. Harm's Boot)", text: $locationSharingViewModel.displayName)
                            .font(.subheadline)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider().padding(.leading, 48)

                    // Share toggle
                    HStack(spacing: 12) {
                        Image(systemName: locationSharingViewModel.isSharing ? "location.fill" : "location.slash.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(locationSharingViewModel.isSharing ? .green : .secondary)
                            .frame(width: 28, height: 28)
                            .background((locationSharingViewModel.isSharing ? Color.green : Color.gray).opacity(0.12), in: Circle())

                        Text("Locatie delen")
                            .font(.subheadline)

                        Spacer()

                        if locationSharingViewModel.isSettingUp {
                            ProgressView()
                        } else {
                            Toggle("", isOn: Binding(
                                get: { locationSharingViewModel.isSharing },
                                set: { newValue in
                                    if newValue {
                                        Task { await locationSharingViewModel.setupSharing() }
                                    } else {
                                        locationSharingViewModel.stopSharing()
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(.blue)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    // Share code
                    if locationSharingViewModel.isSharing && !locationSharingViewModel.shareCode.isEmpty {
                        Divider().padding(.leading, 48)

                        HStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 14))
                                .foregroundStyle(.purple)
                                .frame(width: 28, height: 28)
                                .background(Color.purple.opacity(0.12), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mijn code")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(locationSharingViewModel.shareCode)
                                    .font(.system(.title3, design: .monospaced).weight(.bold))
                            }

                            Spacer()

                            Button {
                                UIPasteboard.general.string = locationSharingViewModel.shareCode
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                // Add friend section
                sectionHeader("Vriend toevoegen")

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                            .frame(width: 28)

                        TextField("Voer code in", text: $locationSharingViewModel.searchCode)
                            .font(.system(.subheadline, design: .monospaced))
                            .textFieldStyle(.plain)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)

                        Button {
                            Task { await locationSharingViewModel.searchFriend() }
                        } label: {
                            if locationSharingViewModel.isSearching {
                                ProgressView()
                            } else {
                                Text("Zoek")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(.blue, in: Capsule())
                            }
                        }
                        .disabled(locationSharingViewModel.searchCode.count < 6)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    // Search result
                    if let result = locationSharingViewModel.searchResult {
                        Divider().padding(.leading, 48)

                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.teal)

                            Text(result.displayName)
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            Button {
                                locationSharingViewModel.addFriend(result)
                            } label: {
                                Text("Toevoegen")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.green, in: Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                // Error message
                if let error = locationSharingViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // Friends list
                if !locationSharingViewModel.friends.isEmpty || !locationSharingViewModel.friendAnnotations.isEmpty {
                    sectionHeader("Vrienden")

                    VStack(spacing: 0) {
                        let friendList = locationSharingViewModel.friends.isEmpty
                            ? friendsFromCache()
                            : locationSharingViewModel.friends

                        ForEach(Array(friendList.enumerated()), id: \.element.userID) { index, friend in
                            if index > 0 {
                                Divider().padding(.leading, 48)
                            }

                            friendRow(friend)
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }

                Text("Deel je code met bekenden zodat zij jouw locatie kunnen zien. Locatie wordt alleen gedeeld zolang de schakelaar aan staat.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                Spacer(minLength: 20)
            }
        }
    }

    // MARK: - Components

    private func friendRow(_ friend: FriendLocation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.teal)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.subheadline.weight(.medium))
                let age = Date().timeIntervalSince(friend.lastUpdated)
                Text(age < 60 ? "Zojuist" : age < 3600 ? "\(Int(age / 60)) min geleden" : "\(Int(age / 3600)) uur geleden")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Navigate button
            Button {
                locationSharingViewModel.navigateToFriend(friend)
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    activePanel = .navigation
                }
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
            }

            // Delete button
            Button {
                locationSharingViewModel.removeFriend(friend.userID)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func friendsFromCache() -> [FriendLocation] {
        // Show cached friend names even if locations haven't loaded yet
        return []
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
