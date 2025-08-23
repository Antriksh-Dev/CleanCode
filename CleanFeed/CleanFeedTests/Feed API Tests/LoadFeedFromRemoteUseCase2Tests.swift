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

fileprivate enum HTTPClientResult {
    case success(Data, HTTPURLResponse)
    case failure(Error)
}

fileprivate protocol HTTPClient {
    func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void)
}

fileprivate enum RemoteFeedLoaderError {
    case connectivity
    case invalidData
}

fileprivate enum RemoteFeedLoaderResult {
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
        client.get(from: url) { _ in }
    }
}

final class LoadFeedFromRemoteUseCase2Tests: XCTestCase {

    func test_init_doesNotRequestDataFromURL() {
        let url = URL(string: "https://a-given-url.com")!
        let client = HTTPClientSpy()
        _ = RemoteFeedLoader(url: url, client: client)
        
        XCTAssertTrue(client.receivedMessages.isEmpty)
    }
    
    func test_load_requestsDataFromURL() {
        let url = URL(string: "https://a-given-url.com")!
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        
        sut.load { _ in }
        
        XCTAssertEqual(client.receivedMessages, [.get(url)])
    }
    
    // MARK: - Helpers
    
    private class HTTPClientSpy: HTTPClient {
        enum ReceivedMessage: Equatable {
            case get(URL)
        }
        
        var receivedMessages = [ReceivedMessage]()
        
        func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
            receivedMessages.append(.get(url))
        }
    }
}
