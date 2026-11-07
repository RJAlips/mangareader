//
//  ReaderSettingsSheet.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct ReaderSettingsSheet: View {
    @ObservedObject public var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Reading Direction") {
                    Picker("Mode", selection: Binding(
                        get: { viewModel.readingMode },
                        set: { viewModel.updateReadingMode($0) }
                    )) {
                        ForEach(ReadingMode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                        }
                    }
                }
                
                Section("Background Color") {
                    Picker("Background", selection: Binding(
                        get: { viewModel.settings.backgroundColor },
                        set: {
                            var s = viewModel.settings
                            s.backgroundColor = $0
                            viewModel.updateSettings(s)
                        }
                    )) {
                        ForEach(ReaderBackgroundColor.allCases) { bg in
                            Text(bg.rawValue).tag(bg)
                        }
                    }
                }
                
                Section("Image Scaling") {
                    Picker("Scale", selection: Binding(
                        get: { viewModel.settings.imageScale },
                        set: {
                            var s = viewModel.settings
                            s.imageScale = $0
                            viewModel.updateSettings(s)
                        }
                    )) {
                        ForEach(ImageScaleType.allCases) { scale in
                            Text(scale.rawValue).tag(scale)
                        }
                    }
                }
                
                Section("Reader Brightness") {
                    HStack {
                        Image(systemName: "sun.min")
                            .foregroundColor(.textTertiary)
                        Slider(value: $viewModel.brightness, in: 0.2...1.0)
                            .accentColor(.mangaAccent)
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.mangaAccent)
                    }
                }
                
                Section("Preferences") {
                    Toggle("Keep Screen Awake", isOn: Binding(
                        get: { viewModel.settings.keepScreenAwake },
                        set: {
                            var s = viewModel.settings
                            s.keepScreenAwake = $0
                            viewModel.updateSettings(s)
                        }
                    ))
                    
                    Toggle("Show Page Counter", isOn: Binding(
                        get: { viewModel.settings.showPageNumber },
                        set: {
                            var s = viewModel.settings
                            s.showPageNumber = $0
                            viewModel.updateSettings(s)
                        }
                    ))
                }
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.mangaAccent)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
