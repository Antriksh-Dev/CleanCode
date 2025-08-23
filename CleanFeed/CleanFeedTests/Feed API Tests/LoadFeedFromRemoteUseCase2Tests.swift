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

fileprivate enum RemoteFeedLoaderError: Error, Equatable {
    case connectivity
    case invalidData
}

fileprivate enum RemoteFeedLoaderResult: Equatable {
    case success([Feed])
    case failure(RemoteFeedLoaderError)
}

fileprivate class RemoteFeedLoader: FeedLoader {
    private let url: URL
    private let client: HTTPClient
    
    init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }
    
    func load(completion: @escaping (LoadFeedResult) -> Void) {
        client.get(from: url) { [weak self] result in
            guard self != nil else { return }
            switch result {
            case let .success(data, response):
                completion(RemoteFeedMapper.map(data: data, response: response))
            case .failure:
                completion(.failure(RemoteFeedLoaderError.connectivity))
            }
        }
    }
}

fileprivate struct RemoteFeed: Codable {
    let id: UUID
    let description: String?
    let location: String?
    let imageURL: URL
    
    enum CodingKeys: String, CodingKey {
        case id
        case description
        case location
        case imageURL = "image"
    }
}

fileprivate struct RemoteFeedRoot: Codable {
    let items: [RemoteFeed]
}

fileprivate class RemoteFeedMapper {
    static func map (data: Data, response: HTTPURLResponse) -> LoadFeedResult {
        guard response.statusCode == 200,
              let remoteFeedRoot = try? JSONDecoder().decode(RemoteFeedRoot.self, from: data) else {
            return .failure(RemoteFeedLoaderError.invalidData)
        }
        
        return .success(remoteFeedRoot.items.feedModels())
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
        expect(sut, toCompleteWith: .failure(.connectivity)) {
            client.complete(withError: anyError())
        }
    }
    
    func test_load_deliversErrorForNon200HTTPResponseAndValidJSONData() {
        let (sut, client) = makeSUT()
        let samples = [199, 201, 300, 400, 500].enumerated()
        samples.forEach { index, code in
            expect(sut, toCompleteWith: .failure(.invalidData)) {
                client.complete(withData: validEmptyJSONData(), responseStatusCode: code, at: index)
            }
        }
    }
    
    func test_load_deliversErrorFor200HTTPResponseAndInvalidJSONData() {
        let (sut, client) = makeSUT()
        expect(sut, toCompleteWith: .failure(.invalidData)) {
            client.complete(withData: invalidJSONData(), responseStatusCode: 200)
        }
    }
    
    func test_load_deliversEmptyFeedFor200HTTPResponseAndValidEmptyJSONData() {
        let (sut, client) = makeSUT()
        expect(sut, toCompleteWith: .success([])) {
            client.complete(withData: validEmptyJSONData(), responseStatusCode: 200)
        }
    }
    
    func test_load_deliversNonEmptyFeedFor200HTTPResponseAndValidJSONData() {
        let (sut, client) = makeSUT()
        expect(sut, toCompleteWith: .success(validNonEmptyFeed().models)) {
            client.complete(withData: validNonEmptyFeed().jsonData, responseStatusCode: 200)
        }
    }
    
    func test_load_deliversNoResultWhenSUTHasBeenDeallocated() {
        let url = URL(string: "https://a-given-url.com")!
        let client = HTTPClientSpy()
        var sut: RemoteFeedLoader? = RemoteFeedLoader(url: url, client: client)
        var receivedResult: LoadFeedResult? = nil
        
        sut?.load { receivedResult = $0 }
        sut = nil
        client.complete(withError: anyError())
        
        XCTAssertNil(receivedResult)
    }
    
    // MARK: - Helpers
    private func makeSUT(url: URL = URL(string: "https://a-url.com")!,
                         file: StaticString = #file,
                         line: UInt = #line) -> (sut: RemoteFeedLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        
        trackForMemoryLeak(instance: client, file: file, line: line)
        trackForMemoryLeak(instance: sut, file: file, line: line)
        
        return (sut, client)
    }
    
    private func trackForMemoryLeak(instance: AnyObject, file: StaticString = #file, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.",
                         file: file,
                         line: line)
        }
    }
    
    private func expect(_ sut: RemoteFeedLoader,
                        toCompleteWith expectedResult: RemoteFeedLoaderResult,
                        when action: () -> Void,
                        file: StaticString = #file,
                        line: UInt = #line) {
        let expectation = expectation(description: "wait for load completion.")
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
    
    private func anyError() -> Error {
        NSError(domain: "Any error", code: 0)
    }
    
    private func invalidJSONData() -> Data {
        "invalid json".data(using: .utf8)!
    }
    
    private func validEmptyJSONData() -> Data {
        let jsonString = "{ \"items\" : [] }"
        return jsonString.data(using: .utf8)!
    }
    
    private func validNonEmptyFeed() -> (models: [Feed], jsonData: Data) {
        let feedItem1 = Feed(id: UUID(uuidString: "73A7F70C-75DA-4C2E-B5A3-EED40DC53AA6")!,
                             description: "Description 1",
                             location: "Location 1",
                             imageURL: URL(string: "https://url-1.com")!)
        let feedItem2 = Feed(id: UUID(uuidString: "BA298A85-6275-48D3-8315-9C8F7C1CD109")!,
                             description: nil,
                             location: "Location 2",
                             imageURL: URL(string: "https://url-2.com")!)
        let feedItem3 = Feed(id: UUID(uuidString: "5A0D45B3-8E26-4385-8C5D-213E160A5E3C")!,
                             description: "Description 3",
                             location: nil,
                             imageURL: URL(string: "https://url-3.com")!)
        let feedItem4 = Feed(id: UUID(uuidString: "FF0ECFE2-2879-403F-8DBE-A83B4010B340")!,
                             description: nil,
                             location: nil,
                             imageURL: URL(string: "https://url-4.com")!)
        
        let jsonString = """
            {
                "items": [
                    {
                        "id": "73A7F70C-75DA-4C2E-B5A3-EED40DC53AA6",
                        "description": "Description 1",
                        "location": "Location 1",
                        "image": "https://url-1.com",
                    },
                    {
                        "id": "BA298A85-6275-48D3-8315-9C8F7C1CD109",
                        "location": "Location 2",
                        "image": "https://url-2.com",
                    },
                    {
                        "id": "5A0D45B3-8E26-4385-8C5D-213E160A5E3C",
                        "description": "Description 3",
                        "image": "https://url-3.com",
                    },
                    {
                        "id": "FF0ECFE2-2879-403F-8DBE-A83B4010B340",
                        "image": "https://url-4.com",
                    },
                ]
            }
            """
        
        let jsonData = jsonString.data(using: .utf8)!
        let models = [feedItem1, feedItem2, feedItem3, feedItem4]
        
        return (models, jsonData)
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
        
        func complete(withData data: Data, responseStatusCode code: Int, at index: Int = 0) {
            let response = HTTPURLResponse(url: URL(string: "https://any-url.com")!,
                                           statusCode: code,
                                           httpVersion: nil,
                                           headerFields: nil)!
            getCompletions[index](.success(data, response))
        }
    }
}

extension Array where Element == RemoteFeed {
    func feedModels() -> [Feed] {
        map { Feed(id: $0.id, description: $0.description, location: $0.location, imageURL: $0.imageURL) }
    }
}
