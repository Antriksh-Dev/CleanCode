//
//  FeedLoader.swift
//  CleanCode
//
//  Created by Antriksh Verma on 8/8/25.
//

import Foundation

enum LoadFeedResult {
    case success([Feed])
    case failure(Error)
}

protocol FeedLoader {
    func load(completion: @escaping (LoadFeedResult) -> Void)
}
