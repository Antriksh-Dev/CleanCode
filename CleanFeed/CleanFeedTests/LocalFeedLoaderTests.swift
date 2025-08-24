//
//  LocalFeedLoaderTests.swift
//  CleanFeedTests
//
//  Created by Antriksh Verma on 8/24/25.
//

import XCTest

// Feed Feature
fileprivate struct Feed {
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

fileprivate enum LoadFeedResult {
    case success([Feed])
    case failure(Error)
}

fileprivate protocol FeedLoader {
    func load(completion: @escaping (LoadFeedResult) -> Void)
}

// Feed Persistence
fileprivate struct LocalFeed {
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

fileprivate enum DeleteCacheResult {
    case success
    case failure(Error)
}

fileprivate enum InsertCacheResult {
    case success
    case failute(Error)
}

fileprivate enum RetrieveCacheResult {
    case empty
    case found(feed: [LocalFeed], timeStamp: Date)
    case failure(Error)
}

fileprivate protocol FeedStore {
    func deleteCachedFeed(completion: @escaping (DeleteCacheResult) -> Void)
    func insertFeedCache(_ feed: [LocalFeed], timeStamp: Date, completion: @escaping (InsertCacheResult) -> Void)
    func retrieveCachedFeed(completion: @escaping (RetrieveCacheResult) -> Void)
}

fileprivate class LocalFeedLoader: FeedLoader {
    let client: FeedStore
    
    init(client: FeedStore) {
        self.client = client
    }
    
    func load(completion: @escaping (LoadFeedResult) -> Void) {
        
    }
}

final class LocalFeedLoaderTests: XCTestCase {


}
