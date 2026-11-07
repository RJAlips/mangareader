//
//  KomgaViewModel.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

@MainActor
public final class KomgaViewModel: ObservableObject {
    @Published public var serverURLString: String = ""
    @Published public var username: String = ""
    @Published public var password: String = ""
    @Published public private(set) var isTestingConnection: Bool = false
    @Published public private(set) var connectionStatus: String? = nil
    @Published public private(set) var isConnected: Bool = false
    
    private let sourceManager = SourceManager.shared
    private let komgaKey = "komga_server_credentials"
    
    public init() {
        if let komga = sourceManager.sources.first(where: { $0.manifest.id == "com.mangareader.source.komga" }) as? KomgaSource,
           let url = komga.serverURL {
            self.serverURLString = url.absoluteString
            self.isConnected = true
        }
    }
    
    public func testAndSaveConnection() {
        guard let url = URL(string: serverURLString.trimmingCharacters(in: .whitespaces)) else {
            connectionStatus = "Invalid URL"
            return
        }
        
        isTestingConnection = true
        connectionStatus = "Connecting..."
        
        let komga = KomgaSource(serverURL: url, username: username, password: password)
        
        Task {
            let healthy = await komga.checkHealth()
            self.isTestingConnection = false
            if healthy {
                self.connectionStatus = "Connected successfully!"
                self.isConnected = true
                self.sourceManager.register(source: komga)
                if !self.sourceManager.isSourceEnabled(komga.manifest.id) {
                    self.sourceManager.toggleSource(komga.manifest.id)
                }
            } else {
                self.connectionStatus = "Connection failed. Please check URL and credentials."
                self.isConnected = false
            }
        }
    }
    
    public func disconnect() {
        serverURLString = ""
        username = ""
        password = ""
        isConnected = false
        connectionStatus = nil
    }
}
