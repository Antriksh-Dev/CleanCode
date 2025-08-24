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

fileprivate enum SaveFeedResult {
    case success
    case failure(Error)
}

fileprivate class LocalFeedLoader: FeedLoader {
    let store: FeedStore
    
    init(store: FeedStore) {
        self.store = store
    }
    
    func load(completion: @escaping (LoadFeedResult) -> Void) {
        
    }
    
    func save(_ feed: [LocalFeed], timeStamp: Date, completion: @escaping (SaveFeedResult) -> Void) {
        
    }
}

final class LocalFeedLoaderTests: XCTestCase {

    // MARK: - Cache Feed Use Case Tests
    func test_init_doesNotRequestDeleteCachedFeedOnCreation() {
        let (sut, store) = makeSUT()
        
        XCTAssertTrue(store.receivedMessages.isEmpty)
    }
    
    // MARK: - Load Feed From Cache Use Case Tests
    func test_init_doesNotRequestRetrieveCachedFeedOnCreation() {
        let (sut, store) = makeSUT()
        
        XCTAssertTrue(store.receivedMessages.isEmpty)
    }
    
    // MARK: - Validate Cache Use Case Tests
    
    
    // MARK: - Helpers
    private func makeSUT(file: StaticString = #file, line: UInt = #line) -> (sut: LocalFeedLoader, store: FeedStoreSpy) {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store)
        
        trackForMemoryLeak(instance: store, file: file, line: line)
        trackForMemoryLeak(instance: sut, file: file, line: line)
        
        return (sut, store)
    }
    
    private func trackForMemoryLeak(instance: AnyObject, file: StaticString = #file, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
    }
    
    private class FeedStoreSpy: FeedStore {
        enum ReceivedMessage {
            case deleteCachedFeed
            case insertFeedCache(feed: [LocalFeed], timeStamp: Date)
            case retrieveCache
        }
        
        var receivedMessages = [ReceivedMessage]()
        
        func deleteCachedFeed(completion: @escaping (DeleteCacheResult) -> Void) {
            
        }
        
        func insertFeedCache(_ feed: [LocalFeed], timeStamp: Date, completion: @escaping (InsertCacheResult) -> Void) {
            
        }
        
        func retrieveCachedFeed(completion: @escaping (RetrieveCacheResult) -> Void) {
            
        }
    }
}
