//
//  LoadFeedFromRemoteUseCase2Tests.swift
//  CleanFeedTests
//
//  Created by Antriksh Verma on 8/22/25.
//

/*
 
 Load Feed From Remote Use Case
 
 Data: URL
 
 Primary course (happy path):
 1. Execute 'Load Feed' command with the above data.
 2. System downloads data from the url.
 3. System validates the downloaded data.
 4. System creates 'Feed' models using the validated data.
 5. System delivers Feed to the user.
 
 Invalid data - error course (sad path):
 1. System delivers invalid data error.
 
 No connectivity - error course (sad path):
 1. System delivers connectivity error.
 */

import XCTest

fileprivate struct Feed: Equatable {
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

fileprivate enum HTTPClientResult {
    case success(Data, HTTPURLResponse)
    case failure(Error)
}

fileprivate protocol HTTPClient {
    func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void)
}

fileprivate enum RemoteFeedLoaderError: Equatable {
    case connectivity
    case invalidData
}

fileprivate enum RemoteFeedLoaderResult: Equatable {
    case success([Feed])
    case failure(RemoteFeedLoaderError)
}

fileprivate class RemoteFeedLoader {
    private let url: URL
    private let client: HTTPClient
    
    init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }
    
    func load(completion: @escaping (RemoteFeedLoaderResult) -> Void) {
        client.get(from: url) { [unowned self] result in
            completion(.failure(.connectivity))
        }
    }
}

final class LoadFeedFromRemoteUseCase2Tests: XCTestCase {

    func test_init_doesNotRequestDataFromURL() {
        let (_, client) = makeSUT()
        
        XCTAssertTrue(client.receivedMessages.isEmpty)
    }
    
    func test_load_requestsDataFromURL() {
        let url = URL(string: "https://a-given-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut.load { _ in }
        
        XCTAssertEqual(client.receivedMessages, [.get(url)])
    }
    
    func test_loadTwice_requestsDataFromURLTwice() {
        let url = URL(string: "https://a-given-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut.load { _ in }
        sut.load { _ in }
        
        XCTAssertEqual(client.receivedMessages, [.get(url), .get(url)])
    }
    
    func test_load_deliversErrorOnClientError() {
        let (sut, client) = makeSUT()
        var receivedResult = [RemoteFeedLoaderResult]()
        
        let expectation = expectation(description: "Wait for load completion.")
        sut.load { result in
            receivedResult.append(result)
            expectation.fulfill()
        }
        
        client.complete(withError: anyError())
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedResult, [.failure(.connectivity)])
    }
    
    // MARK: - Helpers
    private func makeSUT(url: URL = URL(string: "https://a-url.com")!,
                         file: StaticString = #file,
                         line: UInt = #line) -> (sut: RemoteFeedLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        
        trackForMemoryLeak(instance: client)
        trackForMemoryLeak(instance: sut)
        
        return (sut, client)
    }
    
    private func trackForMemoryLeak(instance: AnyObject) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.")
        }
    }
    
    func anyError() -> Error {
        NSError(domain: "Any error", code: 0)
    }
    
    private class HTTPClientSpy: HTTPClient {
        enum ReceivedMessage: Equatable {
            case get(URL)
        }
        
        var receivedMessages = [ReceivedMessage]()
        var getCompletions = [(HTTPClientResult) -> Void]()
        
        func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
            receivedMessages.append(.get(url))
            getCompletions.append(completion)
        }
        
        func complete(withError error: Error, at index: Int = 0) {
            getCompletions[index](.failure(error))
        }
    }
}
