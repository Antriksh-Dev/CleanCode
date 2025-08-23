//
//  LoadFeedFromCacheUseCaseTests.swift
//  CleanFeedTests
//
//  Created by Antriksh Verma on 8/24/25.
//

import XCTest

fileprivate struct LocalFeed {
    let id: UUID
    let description: String?
    let location: String?
    let imageURL: URL
}

fileprivate struct Feed {
    let id: UUID
    let description: String?
    let location: String?
    let imageURL: URL
}

fileprivate enum RetrieveCacheResult {
    case success([LocalFeed])
    case failure(Error)
}

fileprivate protocol FeedStore {
    func retrieve(completion: @escaping (RetrieveCacheResult) -> Void)
}

fileprivate enum LocalFeedLoaderResult {
    case success([Feed])
    case failure(Error)
}

fileprivate class LocalFeedLoader {
    let store: FeedStore
    
    init(store: FeedStore) {
        self.store = store
    }
    
    func load(completion: @escaping (LocalFeedLoaderResult) -> Void) {
        store.retrieve { _ in }
    }
}

final class LoadFeedFromCacheUseCaseTests: XCTestCase {

    func test_init_doesNotRetrieveFeed() {
        let store = FeedStoreSpy()
        _ = LocalFeedLoader(store: store)
        
        XCTAssertEqual(store.receivedMessages, [])
    }
    
    func test_load_requestsFeedRetrieval() {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store)
        
        sut.load { _ in }
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    // MARK: - Helpers
    
    private class FeedStoreSpy: FeedStore {
        enum ReceivedMessage {
            case retrieve
        }
        
        var receivedMessages = [ReceivedMessage]()
        
        func retrieve(completion: @escaping (RetrieveCacheResult) -> Void) {
            receivedMessages.append(.retrieve)
        }
    }
}
