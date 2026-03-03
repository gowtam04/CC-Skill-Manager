import SwiftUI

struct EditorView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                if let skill = viewModel.selectedSkill {
                    Text("Editing: \(skill.name)/SKILL.md")
                        .font(.headline)
                }
                Spacer()
                Button("Cancel") {
                    viewModel.cancelEditing()
                }
                Button("Save") {
                    Task {
                        await viewModel.saveEditing()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Editor
            TextEditor(text: $viewModel.editorContent)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .padding(4)
        }
        .alert("File Modified Externally", isPresented: $viewModel.isShowingExternalModificationWarning) {
            Button("Overwrite", role: .destructive) {
                Task { await viewModel.forceSaveEditing() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This file has been modified outside the editor since it was loaded. Do you want to overwrite the changes?")
        }
    }
}
