//
//  SourceManifest.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public struct SourceManifest: Identifiable, Codable, Hashable, Equatable {
    public var id: String
    public var name: String
    public var version: String
    public var versionCode: Int
    public var lang: String
    public var baseURL: String
    public var iconURL: URL?
    public var repoURL: String?
    public var isEnabled: Bool
    public var isNsfw: Bool
    public var supportsLatest: Bool
    public var supportsSearch: Bool
    public var sourceDescription: String?
    
    public init(
        id: String,
        name: String,
        version: String = "1.0.0",
        versionCode: Int = 1,
        lang: String = "EN",
        baseURL: String = "",
        iconURL: URL? = nil,
        repoURL: String? = nil,
        isEnabled: Bool = true,
        isNsfw: Bool = false,
        supportsLatest: Bool = true,
        supportsSearch: Bool = true,
        sourceDescription: String? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.versionCode = versionCode
        self.lang = lang
        self.baseURL = baseURL
        self.iconURL = iconURL
        self.repoURL = repoURL
        self.isEnabled = isEnabled
        self.isNsfw = isNsfw
        self.supportsLatest = supportsLatest
        self.supportsSearch = supportsSearch
        self.sourceDescription = sourceDescription
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case version
        case versionCode
        case code
        case lang
        case languages
        case baseURL
        case baseUrl
        case iconURL
        case icon
        case repoURL
        case isEnabled
        case isNsfw
        case nsfw
        case supportsLatest
        case supportsSearch
        case sourceDescription
        case description
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "Unknown Source"
        
        // Flexible version: can be String or Int
        if let verStr = try? container.decode(String.self, forKey: .version) {
            self.version = verStr
        } else if let verInt = try? container.decode(Int.self, forKey: .version) {
            self.version = "\(verInt).0.0"
        } else {
            self.version = "1.0.0"
        }
        
        // Flexible versionCode / code
        if let code = try? container.decode(Int.self, forKey: .versionCode) {
            self.versionCode = code
        } else if let code = try? container.decode(Int.self, forKey: .code) {
            self.versionCode = code
        } else if let verInt = try? container.decode(Int.self, forKey: .version) {
            self.versionCode = verInt
        } else {
            self.versionCode = 1
        }
        
        // Flexible lang: String or [String]
        if let lStr = try? container.decode(String.self, forKey: .lang) {
            self.lang = lStr
        } else if let langs = try? container.decode([String].self, forKey: .languages), let first = langs.first {
            self.lang = first
        } else {
            self.lang = "EN"
        }
        
        // Flexible baseURL / baseUrl
        if let base = try? container.decode(String.self, forKey: .baseURL) {
            self.baseURL = base
        } else if let base = try? container.decode(String.self, forKey: .baseUrl) {
            self.baseURL = base
        } else {
            self.baseURL = ""
        }
        
        // Flexible iconURL / icon
        if let icon = try? container.decode(URL.self, forKey: .iconURL) {
            self.iconURL = icon
        } else if let iconStr = try? container.decode(String.self, forKey: .iconURL) {
            self.iconURL = URL(string: iconStr)
        } else if let iconStr = try? container.decode(String.self, forKey: .icon) {
            self.iconURL = URL(string: iconStr)
        } else {
            self.iconURL = nil
        }
        
        self.repoURL = try? container.decodeIfPresent(String.self, forKey: .repoURL)
        self.isEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? true
        
        // Flexible nsfw: Bool or Int (0/1)
        if let nsfwBool = try? container.decode(Bool.self, forKey: .isNsfw) {
            self.isNsfw = nsfwBool
        } else if let nsfwInt = try? container.decode(Int.self, forKey: .nsfw) {
            self.isNsfw = nsfwInt > 0
        } else if let nsfwBool = try? container.decode(Bool.self, forKey: .nsfw) {
            self.isNsfw = nsfwBool
        } else {
            self.isNsfw = false
        }
        
        self.supportsLatest = (try? container.decodeIfPresent(Bool.self, forKey: .supportsLatest)) ?? true
        self.supportsSearch = (try? container.decodeIfPresent(Bool.self, forKey: .supportsSearch)) ?? true
        
        if let desc = try? container.decodeIfPresent(String.self, forKey: .sourceDescription) {
            self.sourceDescription = desc
        } else if let desc = try? container.decodeIfPresent(String.self, forKey: .description) {
            self.sourceDescription = desc
        } else {
            self.sourceDescription = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(version, forKey: .version)
        try container.encode(versionCode, forKey: .versionCode)
        try container.encode(lang, forKey: .lang)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encodeIfPresent(iconURL, forKey: .iconURL)
        try container.encodeIfPresent(repoURL, forKey: .repoURL)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(isNsfw, forKey: .isNsfw)
        try container.encode(supportsLatest, forKey: .supportsLatest)
        try container.encode(supportsSearch, forKey: .supportsSearch)
        try container.encodeIfPresent(sourceDescription, forKey: .sourceDescription)
    }
}
