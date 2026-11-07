//
//  CategoryItem.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public struct CategoryItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var sortOrder: Int
    public var isSystem: Bool
    
    public init(id: UUID = UUID(), name: String, sortOrder: Int = 0, isSystem: Bool = false) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.isSystem = isSystem
    }
    
    public static let defaultCategories: [CategoryItem] = [
        CategoryItem(name: "All", sortOrder: 0, isSystem: true),
        CategoryItem(name: "Reading", sortOrder: 1, isSystem: true),
        CategoryItem(name: "Plan to Read", sortOrder: 2, isSystem: true),
        CategoryItem(name: "Completed", sortOrder: 3, isSystem: true),
        CategoryItem(name: "On Hold", sortOrder: 4, isSystem: true),
        CategoryItem(name: "Dropped", sortOrder: 5, isSystem: true)
    ]
}
