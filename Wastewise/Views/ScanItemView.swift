import SwiftUI
import Lottie

struct ScanItemView: View {
    @StateObject private var viewModel = ScanItemViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isEnteringItem: Bool

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
                        try await DotLottieFile.named("Search")
                    }
                    .animationSpeed(1.5)
                    .playbackMode(reduceMotion
                        ? .paused(at: .progress(0))
                        : .playing(.fromProgress(0, toProgress: 1, loopMode: .loop)))
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What goes where?")
                            .font(.largeTitle.bold())
                        Text("Find the right place for your household waste.")
                            .foregroundStyle(charcoal.opacity(0.8))
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 18) {
                        Label("Check an item", systemImage: "magnifyingglass")
                            .font(.headline)
                            .foregroundStyle(blue)
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(blue)
                                .accessibilityHidden(true)
                            TextField("Item name", text: $viewModel.itemName)
                                .focused($isEnteringItem)
                                .submitLabel(.search)
                                .onSubmit { checkItem() }
                        }
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                        Button(action: checkItem) {
                            HStack {
                                Text("Check disposal guidance")
                                Spacer(minLength: 12)
                                Image(systemName: "arrow.right")
                                    .accessibilityHidden(true)
                            }
                            .font(.headline)
                            .padding(20)
                            .foregroundStyle(colorScheme == .dark ? Color(red: 0.08, green: 0.16, blue: 0.11) : .white)
                            .background(green, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                    .background(blueSurface, in: RoundedRectangle(cornerRadius: 24))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Try these items")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 12)], spacing: 12) {
                            ForEach(["Cardboard box", "Plastic bag", "Grass", "Battery"], id: \.self) { item in
                                Text(item)
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }

                    if let result = viewModel.result {
                        let style = disposalStyle(for: result.disposalStream)
                        VStack(alignment: .leading, spacing: 16) {
                            Image(systemName: style.icon)
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(charcoal)
                                .frame(width: 60, height: 60)
                                .background(style.accent.opacity(colorScheme == .dark ? 0.35 : 0.25), in: RoundedRectangle(cornerRadius: 18))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(result.itemName)
                                    .font(.subheadline.weight(.medium))
                                Text(result.disposalStream.rawValue)
                                    .font(.title.bold())
                                    .foregroundStyle(charcoal)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text(result.instruction)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(style.surface, in: RoundedRectangle(cornerRadius: 28))
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
            .scrollDismissesKeyboard(.interactively)
            .background(background)
            .foregroundStyle(charcoal)
            .navigationTitle("Check an Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func disposalStyle(for stream: DisposalStream) -> (icon: String, accent: Color, surface: Color) {
        switch stream {
        case .generalWaste:
            return ("trash.fill", .red, Color.red.opacity(colorScheme == .dark ? 0.18 : 0.09))
        case .recycling:
            return ("arrow.3.trianglepath", .yellow, Color.yellow.opacity(colorScheme == .dark ? 0.18 : 0.20))
        case .greenWaste:
            return ("leaf.fill", green, greenSurface)
        case .specialistDropOff:
            return ("exclamationmark.triangle.fill", blue, blueSurface)
        }
    }

    private func checkItem() {
        isEnteringItem = false
        viewModel.checkDisposalGuidance()
    }
}
