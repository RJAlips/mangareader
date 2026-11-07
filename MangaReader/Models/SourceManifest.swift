//
//  SourceManifest.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public struct SourceManifest: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var version: String
    public var lang: String
    public var iconURL: URL?
    public var isEnabled: Bool
    public var isNsfw: Bool
    public var supportsLatest: Bool
    public var supportsSearch: Bool
    public var sourceDescription: String?
    
    public init(
        id: String,
        name: String,
        version: String = "1.0.0",
        lang: String = "EN",
        iconURL: URL? = nil,
        isEnabled: Bool = true,
        isNsfw: Bool = false,
        supportsLatest: Bool = true,
        supportsSearch: Bool = true,
        sourceDescription: String? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.lang = lang
        self.iconURL = iconURL
        self.isEnabled = isEnabled
        self.isNsfw = isNsfw
        self.supportsLatest = supportsLatest
        self.supportsSearch = supportsSearch
        self.sourceDescription = sourceDescription
    }
}
