//
//  FeedLoader.swift
//  CleanFeed
//
//  Created by Antriksh Verma on 8/18/25.
//

import Foundation

enum LoadFeedResult {
    case success([Feed])
    case failure(Error)
}

protocol FeedLoader {
    func loadFeed(completion: @escaping (LoadFeedResult) -> Void)
}
