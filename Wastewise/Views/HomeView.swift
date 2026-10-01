import SwiftUI
import Lottie

struct HomeView: View {
    @EnvironmentObject private var addressStore: ResidentAddressStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmingRemoval = false
    @State private var showingAddressEditor = false

    private var charcoal: Color {
        colorScheme == .dark ? Color(red: 0.91, green: 0.94, blue: 0.92) : Color(red: 0.15, green: 0.20, blue: 0.18)
    }
    private var green: Color {
        colorScheme == .dark ? Color(red: 0.43, green: 0.83, blue: 0.58) : Color(red: 0.12, green: 0.43, blue: 0.27)
    }
    private var background: Color {
        colorScheme == .dark ? Color(red: 0.08, green: 0.11, blue: 0.10) : Color(red: 0.96, green: 0.97, blue: 0.96)
    }
    private var greenSurface: Color {
        colorScheme == .dark ? Color(red: 0.13, green: 0.23, blue: 0.17) : Color(red: 0.87, green: 0.95, blue: 0.88)
    }
    private var blueSurface: Color {
        colorScheme == .dark ? Color(red: 0.13, green: 0.21, blue: 0.27) : Color(red: 0.89, green: 0.95, blue: 0.99)
    }
    private var blue: Color {
        colorScheme == .dark ? Color(red: 0.57, green: 0.77, blue: 0.94) : Color(red: 0.20, green: 0.39, blue: 0.55)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 20) {
                        LottieView {
                            try await DotLottieFile.named("rubbish")
                        }
                            .animationSpeed(1.5)
                            .playbackMode(reduceMotion
                                ? .paused(at: .progress(0))
                                : .playing(.fromProgress(0, toProgress: 1, loopMode: .loop)))
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Check what goes where, find your bin day and plan a clean up.")
                                .font(.body)
                                .foregroundStyle(charcoal.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Label("For Parramatta households", systemImage: "mappin.and.ellipse")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(green)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(greenSurface, in: RoundedRectangle(cornerRadius: 28))

                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 14) {
                            Image(systemName: "house.fill")
                                .font(.title2)
                                .foregroundStyle(blue)
                                .frame(width: 50, height: 50)
                                .background(blueSurface, in: RoundedRectangle(cornerRadius: 16))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your household")
                                    .font(.title3.bold())
                                Text(addressStore.hasSavedAddress ? "Saved address" : "Start with your address")
                                    .font(.subheadline)
                                    .foregroundStyle(charcoal.opacity(0.75))
                            }
                        }

                        if addressStore.hasSavedAddress {
                            Text(addressStore.formattedAddress)
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(blueSurface, in: RoundedRectangle(cornerRadius: 16))
                        } else {
                            Text("Add your address to find your collection day.")
                                .foregroundStyle(charcoal.opacity(0.8))
                        }

                        Button {
                            showingAddressEditor = true
                        } label: {
                            HStack {
                                Text(addressStore.hasSavedAddress ? "Edit address" : "Add address")
                                Spacer()
                                Image(systemName: addressStore.hasSavedAddress ? "pencil" : "plus")
                                    .accessibilityHidden(true)
                            }
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 17)
                            .foregroundStyle(colorScheme == .dark ? Color(red: 0.08, green: 0.16, blue: 0.11) : .white)
                            .background(green, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)

                        if addressStore.hasSavedAddress {
                            Button("Remove address", role: .destructive) { confirmingRemoval = true }
                                .font(.subheadline)
                                .frame(minHeight: 44)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(24)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(background)
            .foregroundStyle(charcoal)
            .navigationTitle("WasteWise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingAddressEditor) { AddressEditorView() }
            .confirmationDialog("Remove your saved address?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                Button("Remove address", role: .destructive) { addressStore.clear() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}
