//
//  RemoteFeedMapper.swift
//  CleanFeed
//
//  Created by Antriksh Verma on 8/20/25.
//

import Foundation

struct RemoteFeed: Codable {
    let id: UUID
    let description: String?
    let location: String?
    let imageURL: URL
    
    enum CodingKeys: String, CodingKey {
        case id
        case description
        case location
        case imageURL = "image"
    }
}

struct RemoteFeedRoot: Codable {
    let items: [RemoteFeed]
    
    init(items: [RemoteFeed]) {
        self.items = items
    }
    
    var feed: [Feed] {
        items.map { remoteFeed in
            Feed(id: remoteFeed.id,
                 description: remoteFeed.description,
                 location: remoteFeed.location,
                 imageURL: remoteFeed.imageURL)
        }
    }
}

class RemoteFeedMapper {
    private static var OK_200: Int { 200 }
    
    static func map(data: Data, response: HTTPURLResponse) -> LoadFeedResult {
        guard response.statusCode == OK_200,
              let remoteFeedRoot = try? JSONDecoder().decode(RemoteFeedRoot.self, from: data) else {
            return .failure(RemoteFeedLoader.Error.invalidData)
        }
        
        return .success(remoteFeedRoot.feed)
    }
}
