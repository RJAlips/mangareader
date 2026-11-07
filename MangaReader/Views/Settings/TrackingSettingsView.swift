//
//  TrackingSettingsView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct TrackingSettingsView: View {
    @ObservedObject private var trackerManager = TrackerManager.shared
    @State private var anilistToken: String = ""
    @State private var malToken: String = ""
    @State private var statusMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        Form {
            // AniList Section
            Section("AniList") {
                if trackerManager.anilist.isLoggedIn {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.mangaGreen)
                        Text("Connected to AniList")
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Button("Log Out") {
                            trackerManager.anilist.logout()
                        }
                        .foregroundColor(.mangaAccent)
                    }
                } else {
                    SecureField("Paste AniList OAuth Token", text: $anilistToken)
                    Button("Connect AniList") {
                        Task {
                            try? await trackerManager.anilist.login(token: anilistToken)
                            anilistToken = ""
                        }
                    }
                    .disabled(anilistToken.isEmpty)
                    .foregroundColor(.mangaAccent)
                    .fontWeight(.semibold)
                }
            }
            
            // MyAnimeList Section
            Section("MyAnimeList") {
                if trackerManager.myanimelist.isLoggedIn {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.mangaGreen)
                        Text("Connected to MyAnimeList")
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Button("Log Out") {
                            trackerManager.myanimelist.logout()
                        }
                        .foregroundColor(.mangaAccent)
                    }
                } else {
                    SecureField("Paste MAL Access Token", text: $malToken)
                    Button("Connect MyAnimeList") {
                        Task {
                            try? await trackerManager.myanimelist.login(token: malToken)
                            malToken = ""
                        }
                    }
                    .disabled(malToken.isEmpty)
                    .foregroundColor(.mangaAccent)
                    .fontWeight(.semibold)
                }
            }
            
            Section("Security Note") {
                Text("All authentication tokens and credentials are securely stored using Apple's iOS Keychain and are never logged or transmitted to third-party analytics.")
                    .font(.captionMedium)
                    .foregroundColor(.textSecondary)
            }
        }
        .navigationTitle("Tracking Services")
        .navigationBarTitleDisplayMode(.inline)
    }
}
