//
//  Person.swift
//  Cheq
//
//  Person model for bill splitting
//

import Foundation

struct Person: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

