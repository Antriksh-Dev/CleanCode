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

fileprivate struct Feed: Equatable {
    let id: UUID
    let description: String?
    let location: String?
    let imageURL: URL
}

fileprivate enum RetrieveCacheResult {
    case empty
    case found([LocalFeed])
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
        store.retrieve { [weak self] result in
            guard let _ = self else { return }
            switch result {
            case .empty:
                completion(.success([]))
            case .found:
                break
            case let .failure(error):
                completion(.failure(error))
            }
        }
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
    
    func test_load_deliversErrorOnRetrievalError() {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store)
        expect(sut, toCompleteWith: .failure(retrievalError())) {
            store.retrieveCompletes(with: retrievalError())
        }
    }
    
    func test_load_deliversNoFeedForEmptyCache() {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store)
        expect(sut, toCompleteWith: .success([])) {
            store.retrieveCompletesWithEmptyCache()
        }
    }
    
    // MARK: - Helpers
    private func expect(_ sut: LocalFeedLoader,
                        toCompleteWith expectedResult: LocalFeedLoaderResult,
                        action: () -> Void,
                        file: StaticString = #file,
                        line: UInt = #line) {
        let expectation = expectation(description: "wait for load completion")
        sut.load { receivedResult in
            switch (receivedResult, expectedResult) {
            case let (.success(receivedFeed), .success(expectedFeed)):
                XCTAssertEqual(receivedFeed, expectedFeed, file: file, line: line)
            case let (.failure(receivedError as NSError), .failure(expectedError as NSError)):
                XCTAssertEqual(receivedError, expectedError, file: file, line: line)
            default:
                XCTFail("Expected result \(expectedResult) but received \(receivedResult)", file: file, line: line)
            }
            
            expectation.fulfill()
        }
        action()
        wait(for: [expectation], timeout: 1.0)
    }
    
    private func retrievalError() -> Error {
        NSError(domain: "Retrieval error", code: 0)
    }
    
    private class FeedStoreSpy: FeedStore {
        enum ReceivedMessage {
            case retrieve
        }
        
        var receivedMessages = [ReceivedMessage]()
        var retrievalCompletions = [(RetrieveCacheResult) -> Void]()
        
        func retrieve(completion: @escaping (RetrieveCacheResult) -> Void) {
            receivedMessages.append(.retrieve)
            retrievalCompletions.append(completion)
        }
        
        func retrieveCompletes(with error: Error, at index: Int = 0) {
            retrievalCompletions[index](.failure(error))
        }
        
        func retrieveCompletesWithEmptyCache(at index: Int = 0) {
            retrievalCompletions[index](.empty)
        }
    }
}
