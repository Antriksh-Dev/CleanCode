//
//  CacheFeedUseCaseTests.swift
//  CleanFeedTests
//
//  Created by Antriksh Verma on 8/20/25.
//

/*
 
 Cache Feed Use Case
 
 Data: Feed
 
 Primary course (happy path):
 1. Execute "Save Feed" command with above data.
 2. System deletes old cache feed.
 3. System encodes Feed to be saved.
 4. System timestamps the new cache.
 5. System saves new cache data.
 6. System delivers success message.
 
 Deletion error - error course (sad path):
 1. System delivers error.
 
 Saving error - error course (sad path):
 1. System delivers error.
 
 */

import XCTest

fileprivate enum DeleteCacheResult {
    case success
    case failure(Error)
}

fileprivate protocol FeedStore {
    func deleteCache(completion: @escaping (DeleteCacheResult) -> Void)
}

fileprivate enum SaveFeedResult {
    case success
    case failure(Error)
}

fileprivate class LocalFeedLoader {
    let store: FeedStore
    
    init(store: FeedStore) {
        self.store = store
    }
    
    func save(completion: @escaping (SaveFeedResult) -> Void) {
        store.deleteCache { result in
            switch result {
            case .success:
               break
            case let .failure(deletionError):
                completion(.failure(deletionError))
            }
        }
    }
}

final class CacheFeedUseCaseTests: XCTestCase {

    func test_init_doesNotRequestStoreOnCreation() {
        let (_, store) = makeSUT()
        
        XCTAssertTrue(store.receivedMessages.isEmpty)
    }
    
    func test_save_deletesCachedFeed() {
        let (sut, store) = makeSUT()
        
        sut.save { _ in }
        
        XCTAssertEqual(store.receivedMessages, [.deleteCache])
    }
    
    func test_save_doesNotInsertFeedOnDeletionError() {
        let (sut, store) = makeSUT()
        
        sut.save { _ in }
        store.deleteCompletes(with: deleteCacheError())
        
        XCTAssertEqual(store.receivedMessages, [.deleteCache])
    }
    
    func test_save_deliversErrorOnCacheDeletionError() {
        let (sut, store) = makeSUT()
        expect(sut, toCompleteWith: .failure(deleteCacheError())) {
            store.deleteCompletes(with: deleteCacheError())
        }
    }

    // MARK: - Helpers
    private func makeSUT(file: StaticString = #file, line: UInt = #line) -> (sut: LocalFeedLoader, store: FeedStoreSpy) {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store)
        
        return (sut, store)
    }
    
    private func expect(_ sut: LocalFeedLoader,
                        toCompleteWith expectedResult: SaveFeedResult,
                        when action: () -> Void,
                        file: StaticString = #file,
                        line: UInt = #line) {
        let expectation = expectation(description: "wait for save completion")
        sut.save { receivedResult in
            switch (receivedResult, expectedResult) {
            case (.success, .success):
                break
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
    
    private func deleteCacheError() -> Error {
        NSError(domain: "Delete cache error", code: 0)
    }
    
    private class FeedStoreSpy: FeedStore {
        enum ReceivedMessage {
            case deleteCache
        }
        
        var receivedMessages = [ReceivedMessage]()
        var deleteCompletions = [(DeleteCacheResult) -> Void]()
        
        func deleteCache(completion: @escaping (DeleteCacheResult) -> Void) {
            receivedMessages.append(.deleteCache)
            deleteCompletions.append(completion)
        }
        
        func deleteCompletes(with error: Error, at index: Int = 0) {
            deleteCompletions[index](.failure(error))
        }
    }
}
