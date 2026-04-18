import SwiftUI
import FamilyControls

/// "Edit monitored apps" settings screen. Resolves M4 compromise #4
/// (previously the only way to change which apps were monitored was
/// to uninstall and re-onboard).
///
/// Flow:
/// 1. Loads the current `FamilyActivitySelection` from `SharedDefaults`.
/// 2. Shows the `FamilyActivityPicker` pre-filled with it.
/// 3. On "Save", persists the new selection, then re-applies the
///    shield + restarts monitoring with the updated threshold ladder.
/// 4. Dismisses back to the caller.
///
/// Errors during save surface in an inline error strip; on success,
/// the view dismisses.
struct EditMonitoredAppsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection = FamilyActivitySelection()
    @State private var isLoaded = false
    @State private var saving = false
    @State private var errorMessage: String?

    private let service = RealScreenTimeService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Pick the apps you want Sealo to watch over. Changes take effect immediately.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                FamilyActivityPicker(selection: $selection)
                    .frame(maxHeight: .infinity)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Edit monitored apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if saving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(saving)
                }
            }
            .onAppear {
                guard !isLoaded else { return }
                isLoaded = true
                loadExistingSelection()
            }
        }
    }

    private func loadExistingSelection() {
        guard let data = SharedDefaults.loadAppSelectionData(),
              let existing = try? JSONDecoder().decode(
                  FamilyActivitySelection.self, from: data
              ) else { return }
        selection = existing
    }

    private func save() {
        saving = true
        errorMessage = nil

        // Persist the new selection first so any subsequent reads
        // from extensions see it.
        if let data = try? JSONEncoder().encode(selection) {
            SharedDefaults.saveAppSelection(data)
        } else {
            errorMessage = "Could not save selection"
            saving = false
            return
        }

        // Re-apply the shield + restart monitoring so iOS starts
        // watching the NEW set. Old monitoring (on the prior
        // selection) is implicitly replaced.
        Task {
            do {
                try await service.stopMonitoring()
                try await service.startMonitoring()
                try await service.applyPermanentShield()
                saving = false
                dismiss()
            } catch {
                errorMessage = "Failed to update monitoring: \(error.localizedDescription)"
                saving = false
            }
        }
    }
}
