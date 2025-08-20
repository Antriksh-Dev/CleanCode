//
//  RemoteFeedLoaderTests.swift
//  CleanFeedTests
//
//  Created by Antriksh Verma on 8/18/25.
//

/*
 
 Load Feed From Remote Use Case
 
 Data: URL
 
 Primary course (happy path):
 1. Execute 'Load Feed' command with the above data.
 2. System downloads data from the URL.
 3. System validates the downloaded data.
 4. System creates 'Feed' models using the validated data.
 5. System delivers Feed of the user.
 
 Invalid path - error course (sad path):
 1. System delivers invalid data path.
 
 No connectivity - error course (sad path):
 1. System delivers connectivity error.
 
 */

import XCTest
import CleanFeed

enum HTTPClientResult {
    case success(Data, HTTPURLResponse)
    case failure(Error)
}

protocol HTTPClient {
    func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void)
}

enum RemoteFeedLoaderError: Error {
    case connectivity
    case invalidData
}

enum RemoteFeedLoaderResult: Equatable {
    case success([Feed])
    case failure(RemoteFeedLoaderError)
}

struct RemoteFeedRoot: Codable {
    let items: [RemoteFeed]
    
    init(items: [RemoteFeed]) {
        self.items = items
    }
    
    func feed() -> [Feed] {
        items.map { remoteFeed in
            Feed(id: remoteFeed.id,
                 description: remoteFeed.description,
                 location: remoteFeed.location,
                 imageURL: remoteFeed.imageURL)
        }
    }
    
    struct RemoteFeed: Codable {
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
}

class RemoteFeedMapper {
    static let OK_200 = 200
    
    static func map(data: Data, response: HTTPURLResponse) -> LoadFeedResult {
        guard response.statusCode == OK_200,
              let remoteFeedRoot = try? JSONDecoder().decode(RemoteFeedRoot.self, from: data) else {
            return .failure(RemoteFeedLoaderError.invalidData)
        }
        
        return .success(remoteFeedRoot.feed())
    }
}

class RemoteFeedLoader: FeedLoader {
    let url: URL
    let client: HTTPClient
    
    init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }
    
    func load(completion: @escaping (LoadFeedResult) -> Void) {
        client.get(from: url) { [weak self] result in
            guard let _ = self else { return }
            
            switch result {
            case let .success(data, response):
                completion(RemoteFeedMapper.map(data: data, response: response))
            case .failure(_):
                completion(.failure(RemoteFeedLoaderError.connectivity))
            }
        }
    }
}

final class RemoteFeedLoaderTests: XCTestCase {

    func test_init_doesNotRequestDataFromURL() {
        let (client, _) = makeSUT()
        
        XCTAssertTrue(client.requestedURLs.isEmpty)
    }
    
    func test_load_requestsDataFromURL() {
        let url = URL(string: "https://a-given-url.com")!
        let (client, sut) = makeSUT(with: url)
        
        sut.load { _ in }
        
        XCTAssertEqual(client.requestedURLs, [url])
    }
    
    func test_loadTwice_requestsDataFromURLTwice() {
        let url = URL(string: "https://a-given-url.com")!
        let (client, sut) = makeSUT(with: url)
        
        sut.load { _ in }
        sut.load { _ in }
        
        XCTAssertEqual(client.requestedURLs, [url, url])
    }

    func test_load_deliversErrorForClientError() {
        let (client, sut) = makeSUT()
        
        expect(sut, toCompleteWithResult: .failure(RemoteFeedLoaderError.connectivity)) {
            client.complete(withError: anyError())
        }
    }
    
    func test_load_deliversErrorForNon200HTTPResponseWithValidJSONData() {
        let (client, sut) = makeSUT()
        
        let samples = [199, 201, 300, 400, 500].enumerated()
        samples.forEach { index, code in
            expect(sut, toCompleteWithResult: .failure(RemoteFeedLoaderError.invalidData)) {
                client.complete(withStatusCode: code, data: validEmptyJSONData(), at: index)
            }
        }
    }
    
    func test_load_deliversErrorFor200HTTPResponseWithInvalidJSONData() {
        let (client, sut) = makeSUT()
        
        expect(sut, toCompleteWithResult: .failure(RemoteFeedLoaderError.invalidData)) {
            client.complete(withStatusCode: 200, data: invalidJSONData())
        }
    }
    
    func test_load_deliversEmptyFeedFor200HTTPResponseWithValidEmptyJSONData() {
        let (client, sut) = makeSUT()
        
        expect(sut, toCompleteWithResult: .success([])) {
            client.complete(withStatusCode: 200, data: validEmptyJSONData())
        }
    }
    
    func test_load_deliversValidFeedFor200HTTPResponseWithValidJSONData() {
        let (client, sut) = makeSUT()
        
        expect(sut, toCompleteWithResult: .success(validNonEmptyFeed().models)) {
            client.complete(withStatusCode: 200, data: validNonEmptyFeed().jsonData)
        }
    }
    
    func test_load_doesNotDeliverResultAfterSUTHasBeenDeallocated() {
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
    
    private func makeSUT(with url: URL = URL(string: "https://a-url.com")!,
                         file: StaticString = #file,
                         line: UInt = #line) -> (client: HTTPClientSpy, sut: RemoteFeedLoader) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        
        trackForMemoryLeak(instance: client, file: file, line: line)
        trackForMemoryLeak(instance: sut, file: file, line: line)
        
        return (client, sut)
    }
    
    func trackForMemoryLeak(instance: AnyObject, file: StaticString = #file, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak", file: file, line: line)
        }
    }
    
    func anyError() -> Error {
        NSError()
    }
    
    func invalidJSONData() -> Data {
        "Invalid Data".data(using: .utf8)!
    }
    
    func validEmptyJSONData() -> Data {
        let jsonString = "{ \"items\" : [] }"
        let data = jsonString.data(using: .utf8)!
        return data
    }
    
    func validNonEmptyFeed() -> (jsonData: Data, models: [Feed]) {
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
        
        return (jsonData, models)
    }
    
    func expect(_ sut: RemoteFeedLoader,
                toCompleteWithResult expectedResult: LoadFeedResult,
                when action: () -> Void,
                file: StaticString = #file,
                line: UInt = #line) {
        
        let expectation = expectation(description: "wait for load completion")
        
        sut.load { receivedResult in
            switch (receivedResult, expectedResult) {
            case let (.success(receivedFeed), .success(expectedFeed)):
                XCTAssertEqual(receivedFeed, expectedFeed, file: file, line: line)
            case let (.failure(receivedError as RemoteFeedLoaderError), .failure( expectedError as RemoteFeedLoaderError)):
                XCTAssertEqual(receivedError, expectedError, file: file, line: line)
            default:
                XCTFail("Expected result: \(expectedResult) but received: \(receivedResult)", file: file, line: line)
            }
            
            expectation.fulfill()
        }
        
        action()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    private class HTTPClientSpy: HTTPClient {
        var messages = [(url: URL, completion: (HTTPClientResult) -> Void)]()
        var requestedURLs : [URL] {
            messages.map { $0.url }
        }
        
        func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
            messages.append((url: url, completion: completion))
        }
        
        func complete(withError error: Error, at index: Int = 0) {
            messages[index].completion(.failure(error))
        }
        
        func complete(withStatusCode code: Int, data: Data, at index: Int = 0) {
            let response = HTTPURLResponse(url: requestedURLs[index],
                                           statusCode: code,
                                           httpVersion: nil,
                                           headerFields: nil)!
            messages[index].completion(.success(data, response))
        }
    }
}
