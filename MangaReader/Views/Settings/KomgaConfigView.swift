//
//  KomgaConfigView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct KomgaConfigView: View {
    @StateObject private var viewModel = KomgaViewModel()
    
    public init() {}
    
    public var body: some View {
        Form {
            Section("Komga Server Details") {
                TextField("Server URL (e.g. https://komga.example.com)", text: $viewModel.serverURLString)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                
                TextField("Username or Email", text: $viewModel.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                SecureField("Password or API Key", text: $viewModel.password)
            }
            
            Section {
                Button(action: { viewModel.testAndSaveConnection() }) {
                    HStack {
                        if viewModel.isTestingConnection {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        }
                        Text(viewModel.isConnected ? "Update Connection" : "Connect & Test")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(viewModel.serverURLString.isEmpty || viewModel.isTestingConnection)
                
                if let status = viewModel.connectionStatus {
                    Text(status)
                        .font(.captionMedium)
                        .foregroundColor(viewModel.isConnected ? .mangaGreen : .mangaAccent)
                }
                
                if viewModel.isConnected {
                    Button("Disconnect Server", role: .destructive) {
                        viewModel.disconnect()
                    }
                }
            }
            
            Section("About Komga Integration") {
                Text("Komga is a free and open source comics/manga media server. Connecting your personal server allows you to stream and synchronize your entire comic library natively inside MangaReader.")
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
            }
        }
        .navigationTitle("Komga Server")
        .navigationBarTitleDisplayMode(.inline)
    }
}
