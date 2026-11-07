//
//  MainTabView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public enum AppTab: String, CaseIterable, Identifiable {
    case home = "Discover"
    case library = "Library"
    case browse = "Browse"
    case downloads = "Downloads"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .home: return "sparkles"
        case .library: return "books.vertical.fill"
        case .browse: return "safari.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: AppTab = .home
    
    public init() {}
    
    public var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad Sidebar Split View Layout
                NavigationSplitView {
                    List(AppTab.allCases, selection: $selectedTab) { tab in
                        NavigationLink(value: tab) {
                            Label(tab.rawValue, systemImage: tab.iconName)
                                .font(.bodyEmphasized)
                        }
                    }
                    .listStyle(SidebarListStyle())
                    .navigationTitle("MangaReader")
                } detail: {
                    tabContent(for: selectedTab)
                }
            } else {
                // iPhone Native Tab Bar Layout
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem {
                            Label(AppTab.home.rawValue, systemImage: AppTab.home.iconName)
                        }
                        .tag(AppTab.home)
                    
                    LibraryView()
                        .tabItem {
                            Label(AppTab.library.rawValue, systemImage: AppTab.library.iconName)
                        }
                        .tag(AppTab.library)
                    
                    BrowseView()
                        .tabItem {
                            Label(AppTab.browse.rawValue, systemImage: AppTab.browse.iconName)
                        }
                        .tag(AppTab.browse)
                    
                    DownloadsView()
                        .tabItem {
                            Label(AppTab.downloads.rawValue, systemImage: AppTab.downloads.iconName)
                        }
                        .tag(AppTab.downloads)
                    
                    SettingsView()
                        .tabItem {
                            Label(AppTab.settings.rawValue, systemImage: AppTab.settings.iconName)
                        }
                        .tag(AppTab.settings)
                }
            }
        }
        .tint(.mangaAccent)
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .library:
            LibraryView()
        case .browse:
            BrowseView()
        case .downloads:
            DownloadsView()
        case .settings:
            SettingsView()
        }
    }
}
