//
//  CategoryManagementSheet.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct CategoryManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var db = DatabaseManager.shared
    @State private var newCategoryName: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section("Add Category") {
                    HStack {
                        TextField("New Category Name", text: $newCategoryName)
                            .foregroundColor(.textPrimary)
                        
                        Button("Add") {
                            db.addCategory(name: newCategoryName)
                            newCategoryName = ""
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundColor(.mangaAccent)
                        .fontWeight(.semibold)
                    }
                }
                
                Section("Categories") {
                    ForEach(db.categoriesList) { cat in
                        HStack {
                            Text(cat.name)
                                .foregroundColor(.textPrimary)
                            Spacer()
                            if cat.isSystem {
                                Text("System")
                                    .font(.captionMedium)
                                    .foregroundColor(.textTertiary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let cat = db.categoriesList[index]
                            if !cat.isSystem {
                                db.removeCategory(id: cat.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.mangaAccent)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
