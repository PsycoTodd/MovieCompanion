import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var libraryViewModel: MovieLibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var urlText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://drive.google.com/uc?export=download&id=...", text: $urlText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                } header: {
                    Text("Google Drive Manifest URL")
                } footer: {
                    Text("Paste the direct download URL of your manifest.json file. The manifest should be a JSON array: [{\"name\": \"Movie_EN.srt\", \"url\": \"...\"}, ...]")
                }

                if libraryViewModel.isLoadingRemote {
                    Section {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Loading subtitles…")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let error = libraryViewModel.remoteError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    } header: {
                        Text("Error")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        libraryViewModel.setManifestURL(urlText.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                urlText = libraryViewModel.manifestURL
            }
        }
    }
}
