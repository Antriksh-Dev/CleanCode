//
//  FeedLoader.swift
//  CleanFeed
//
//  Created by Antriksh Verma on 8/18/25.
//

import Foundation

public enum LoadFeedResult {
    case success([Feed])
    case failure(Error)
}

public protocol FeedLoader {
    func load(completion: @escaping (LoadFeedResult) -> Void)
}
