//
//  Feed.swift
//  CleanFeed
//
//  Created by Antriksh Verma on 8/18/25.
//

import Foundation

struct Feed {
    private let id: UUID
    private let description: String?
    private let location: String?
    private let imageURL: URL
    
    init(id: UUID, description: String?, location: String?, imageURL: URL) {
        self.id = id
        self.description = description
        self.location = location
        self.imageURL = imageURL
    }
}
