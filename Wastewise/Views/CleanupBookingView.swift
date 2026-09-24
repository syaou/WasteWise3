import SwiftUI
import Lottie

struct CleanupBookingView: View {
    @EnvironmentObject private var addressStore: ResidentAddressStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddressEditor = false
    @StateObject private var viewModel = CleanupBookingViewModel()

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
                VStack(alignment: .leading, spacing: 20) {
                    LottieView {
                        try await DotLottieFile.named("cleanup")
                    }
                    .animationSpeed(1.5)
                    .playbackMode(reduceMotion
                        ? .paused(at: .progress(0))
                        : .playing(.fromProgress(0, toProgress: 1, loopMode: .loop)))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Time for a clean-up?")
                            .font(.largeTitle.bold())
                        Text("Choose the household items you’re clearing out.")
                            .foregroundStyle(charcoal.opacity(0.8))
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select items")
                            .font(.title3.bold())
                        Text("Paint and asbestos need specialist disposal.")
                            .font(.subheadline)
                            .foregroundStyle(charcoal.opacity(0.8))
                        ForEach(CleanupItemType.allCases) { item in
                            Button {
                                if viewModel.selectedItems.contains(item) {
                                    viewModel.selectedItems.remove(item)
                                } else {
                                    viewModel.selectedItems.insert(item)
                                }
                            } label: {
                                HStack(spacing: 16) {
                                    Text(item.rawValue)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(charcoal)
                                    Spacer(minLength: 12)
                                    Image(systemName: viewModel.selectedItems.contains(item) ? "checkmark.square.fill" : "square")
                                        .font(.title2)
                                        .foregroundStyle(green)
                                        .accessibilityHidden(true)
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(viewModel.selectedItems.contains(item) ? greenSurface : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                                .contentShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(viewModel.selectedItems.contains(item) ? "Selected" : "Not selected")
                            .accessibilityAddTraits(viewModel.selectedItems.contains(item) ? .isSelected : [])
                        }
                    }

                    VStack(spacing: 12) {
                        if !addressStore.hasSavedAddress {
                            Text("Add your address on Home to prepare a request.")
                                .font(.subheadline)
                                .foregroundStyle(charcoal.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            viewModel.submitBooking(address: addressStore.address)
                        } label: {
                            HStack {
                                Text("Prepare clean up request")
                                Spacer(minLength: 12)
                                Image(systemName: "arrow.right")
                                    .accessibilityHidden(true)
                            }
                            .font(.headline)
                            .padding(20)
                            .foregroundStyle(colorScheme == .dark ? Color(red: 0.08, green: 0.16, blue: 0.11) : .white)
                            .background(green, in: RoundedRectangle(cornerRadius: 16))
                            .opacity(addressStore.hasSavedAddress ? 1 : 0.45)
                        }
                        .buttonStyle(.plain)
                        .disabled(!addressStore.hasSavedAddress)
                    }

                    if let confirmation = viewModel.result {
                        VStack(alignment: .leading, spacing: 14) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(green)
                                .accessibilityHidden(true)
                            Text("Demo reference").font(.subheadline.weight(.medium))
                            Text(confirmation.reference)
                                .font(.title2.bold())
                                .foregroundStyle(green)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(greenSurface, in: RoundedRectangle(cornerRadius: 28))
                    }
                    if let error = viewModel.errorMessage {
                        Label {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("What to do next").font(.headline)
                                Text(error).fixedSize(horizontal: false, vertical: true)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(.red)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(background)
            .foregroundStyle(charcoal)
            .navigationTitle("Clean Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingAddressEditor) { AddressEditorView() }
            .onChange(of: addressStore.address) { _, _ in viewModel.clearResult() }
        }
    }
}
