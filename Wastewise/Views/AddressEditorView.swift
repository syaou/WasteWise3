import SwiftUI

struct AddressEditorView: View {
    var isPresentedAsSheet = true
    @EnvironmentObject private var addressStore: ResidentAddressStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectionTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isPresentedAsSheet {
                NavigationStack {
                    Form { addressFields }
                        .navigationTitle("Residential address")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { dismiss() }
                            }
                        }
                }
            } else {
                addressFields
            }
        }
        .onAppear { addressStore.endEditing() }
        .onDisappear {
            selectionTask?.cancel()
            addressStore.endEditing()
        }
    }

    private var addressFields: some View {
        Section {
            TextField("Enter your full Australian address", text: Binding(
                get: { addressStore.query },
                set: { addressStore.updateQuery($0) }
            ))
            .textContentType(.fullStreetAddress)
            .autocorrectionDisabled()
            ForEach(addressStore.suggestions) { suggestion in
                Button {
                    selectionTask?.cancel()
                    selectionTask = Task {
                        if await addressStore.select(suggestion), isPresentedAsSheet {
                            dismiss()
                        }
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(suggestion.title)
                        Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if addressStore.isResolving {
                ProgressView("Saving address…")
            }
            if let message = addressStore.autocompleteError {
                Text(message).foregroundStyle(.red)
            }
        } header: {
            Text("Residential address")
        } footer: {
            Text("Select an address to save it.")
        }
    }
}
