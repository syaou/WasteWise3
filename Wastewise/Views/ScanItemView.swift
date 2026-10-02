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

                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(green)
                            .accessibilityHidden(true)
                        TextField("Search the glossary", text: $viewModel.itemName)
                            .focused($isEnteringItem)
                            .submitLabel(.search)
                            .onSubmit { isEnteringItem = false }
                            .autocorrectionDisabled()
                        if !viewModel.itemName.isEmpty {
                            Button {
                                viewModel.itemName = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .accessibilityLabel("Clear search")
                            .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("A–Z disposal glossary")
                            .font(.title2.bold())
                        Text("Browse by name or search above. Tap an item for disposal advice.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let error = viewModel.catalogueError {
                        Text(error)
                        Button("Try again") { viewModel.loadCatalogue() }
                    } else if viewModel.filteredItems.isEmpty {
                        ContentUnavailableView("No items found", systemImage: "magnifyingglass",
                                               description: Text("Try a shorter item name or check the council’s full A–Z guide below."))
                    } else {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.glossaryLetters, id: \.self) { letter in
                                Section {
                                    ForEach(viewModel.filteredItems.filter { String($0.name.prefix(1)).uppercased() == letter }) { item in
                                        glossaryRow(item)
                                    }
                                } header: {
                                    Text(letter)
                                        .font(.title2.bold())
                                        .foregroundStyle(green)
                                        .accessibilityAddTraits(.isHeader)
                                }
                            }
                        }
                    }

                    Link(destination: URL(string: "https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/a-z-guide-to-waste-and-recycling")!) {
                        Label("Council’s full A–Z guide", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.medium))
                    }
                    .tint(green)

                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(background)
            .foregroundStyle(charcoal)
            .navigationTitle("Rubbish glossary")
            .task { viewModel.loadCatalogue() }
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
        case .specialistDropOff, .communityRecyclingCentre, .problemWaste, .bulkyWaste:
            return ("exclamationmark.triangle.fill", blue, blueSurface)
        }
    }

    private func glossaryRow(_ item: WasteItem) -> some View {
        let style = disposalStyle(for: item.disposalStream)
        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 14) {
                Text(item.instruction)
                    .fixedSize(horizontal: false, vertical: true)
                if let source = item.sourceURL, let url = URL(string: source) {
                    Link("Council disposal guidance", destination: url)
                        .font(.subheadline.weight(.medium))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: style.icon)
                    .foregroundStyle(charcoal)
                    .frame(width: 44, height: 44)
                    .background(style.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.headline)
                    Text(item.disposalStream.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(charcoal)
        }
        .tint(green)
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}
