import SwiftUI

struct SyncConflictView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Sync Conflicts")
                    .font(.headline)
                Spacer()
                Button("Dismiss") {
                    viewModel.dismissSyncConflicts()
                }
            }
            .padding()

            Divider()

            if viewModel.syncConflicts.isEmpty {
                ContentUnavailableView("No Conflicts", systemImage: "checkmark.circle")
                    .padding()
            } else {
                List(viewModel.syncConflicts) { conflict in
                    conflictRow(conflict)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 300)
    }

    @ViewBuilder
    private func conflictRow(_ conflict: SyncConflict) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(conflict.skillName)
                .font(.headline)

            Text(conflictDescription(conflict))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let localDate = conflict.localModificationDate,
               let remoteDate = conflict.remoteModificationDate {
                HStack(spacing: 16) {
                    Label("Local: \(localDate.formatted(.dateTime))", systemImage: "laptopcomputer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Remote: \(remoteDate.formatted(.dateTime))", systemImage: "cloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if conflict.reason == .bothModified {
                HStack(spacing: 12) {
                    Button("Keep Local") {
                        Task {
                            await viewModel.resolveConflict(conflict, resolution: .keepLocal)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Keep Remote") {
                        Task {
                            await viewModel.resolveConflict(conflict, resolution: .keepRemote)
                        }
                    }
                    .buttonStyle(.bordered)

                    if viewModel.isResolvingConflict {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func conflictDescription(_ conflict: SyncConflict) -> String {
        switch conflict.reason {
        case .deletedRemotelyButModifiedLocally:
            return "Deleted on another device but modified locally. Local copy was kept."
        case .deletedLocallyButModifiedRemotely:
            return "Deleted locally but modified on another device. Remote copy was kept."
        case .bothModified:
            return "Modified on both this device and another device. Choose which version to keep."
        case .enabledStateConflict:
            return "Enabled/disabled state was changed on both devices. Local state was applied."
        }
    }
}
