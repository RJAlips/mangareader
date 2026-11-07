//
//  BackupRestoreView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import UniformTypeIdentifiers

public struct BackupRestoreView: View {
    @ObservedObject public var viewModel: SettingsViewModel
    @State private var showFilePicker = false
    @State private var showShareSheet = false
    
    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Form {
            Section("Backup Library") {
                Text("Export all manga records, custom categories, reading history, and reader preferences to a portable JSON backup.")
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
                
                Button(action: {
                    viewModel.exportBackup()
                    if viewModel.backupFileURL != nil {
                        showShareSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Create & Export Backup")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.mangaAccent)
                }
            }
            
            Section("Restore Library") {
                Text("Restore your library, categories, and progress from an existing MangaReader backup file.")
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
                
                Button(action: { showFilePicker = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Restore from Backup File")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.mangaBlue)
                }
            }
            
            if let msg = viewModel.restoreMessage {
                Section {
                    Text(msg)
                        .font(.bodyMedium)
                        .foregroundColor(.mangaGreen)
                }
            }
        }
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.importBackup(from: url)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let fileURL = viewModel.backupFileURL {
                ShareSheet(activityItems: [fileURL])
            }
        }
    }
}

public struct ShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
