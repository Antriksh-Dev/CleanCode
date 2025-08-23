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
 
 Insertion error - error course (sad path):
 1. System delivers error.
 
 */

import XCTest

fileprivate enum DeleteCacheResult {
    case success
    case failure(Error)
}

fileprivate enum InsertFeedResult {
    case success
    case failure(Error)
}

fileprivate protocol FeedStore {
    func deleteCache(completion: @escaping (DeleteCacheResult) -> Void)
    func insert(completion: @escaping (InsertFeedResult) -> Void)
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
        store.deleteCache { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success:
                strongSelf.store.insert { [weak self] result in
                    guard let _ = self else { return }
                    switch result {
                    case .success:
                        completion(.success)
                    case let .failure(insertionError):
                        completion(.failure(insertionError))
                    }
                }
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
    
    func test_save_deliversErrorOnFeedInsertionError() {
        let (sut, store) = makeSUT()
        expect(sut, toCompleteWith: .failure(insertFeedError())) {
            store.deleteCompletesSuccessfully()
            store.insertComplete(with: insertFeedError())
        }
    }

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
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak", file: file, line: line)
        }
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
    
    private func insertFeedError() -> Error {
        NSError(domain: "Insert feed errr", code: 0)
    }
    
    private class FeedStoreSpy: FeedStore {
        enum ReceivedMessage {
            case deleteCache
            case insertFeed
        }
        
        var receivedMessages = [ReceivedMessage]()
        var deleteCompletions = [(DeleteCacheResult) -> Void]()
        var insertCompletions = [(InsertFeedResult) -> Void]()
        
        func deleteCache(completion: @escaping (DeleteCacheResult) -> Void) {
            receivedMessages.append(.deleteCache)
            deleteCompletions.append(completion)
        }
        
        func insert(completion: @escaping (InsertFeedResult) -> Void) {
            receivedMessages.append(.insertFeed)
            insertCompletions.append(completion)
        }
        
        func deleteCompletes(with error: Error, at index: Int = 0) {
            deleteCompletions[index](.failure(error))
        }
        
        func deleteCompletesSuccessfully(at index: Int = 0) {
            deleteCompletions[index](.success)
        }
        
        func insertComplete(with error: Error, at index: Int = 0) {
            insertCompletions[index](.failure(error))
        }
    }
}
