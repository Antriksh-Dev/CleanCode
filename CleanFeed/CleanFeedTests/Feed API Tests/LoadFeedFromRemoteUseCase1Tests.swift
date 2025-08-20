//
//  LoadFeedFromRemoteUseCase1Tests.swift
//  CleanFeedTests
//
//  Created by Antriksh Verma on 8/20/25.
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

fileprivate class RemoteFeed: Codable {
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
    
    init(id: UUID, description: String?, location: String?, imageURL: URL) {
        self.id = id
        self.description = description
        self.location = location
        self.imageURL = imageURL
    }
}

fileprivate class RemoteFeedRoot: Codable {
    private let items: [RemoteFeed]
    
    var feed: [Feed] {
        items.map { remoteFeed in
            Feed(id: remoteFeed.id,
                 description: remoteFeed.description,
                 location: remoteFeed.location,
                 imageURL: remoteFeed.imageURL)
        }
    }
}

fileprivate class RemoteFeedMapper {
    static var OK_200: Int { 200 }
    
    static func map(data: Data, response: HTTPURLResponse) -> LoadFeedResult {
        guard response.statusCode == OK_200,
              let remoteFeedRoot = try? JSONDecoder().decode(RemoteFeedRoot.self, from: data) else {
            return .failure(RemoteFeedLoader.Error.invalidData)
        }
        
        return .success(remoteFeedRoot.feed)
    }
}

fileprivate class RemoteFeedLoader: FeedLoader {
    let url: URL
    let client: HTTPClient
    
    enum Error: Swift.Error {
        case connectivity
        case invalidData
    }
    
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
            case .failure:
                completion(.failure(Error.connectivity))
            }
        }
    }
}

final class LoadFeedFromRemoteUseCase1Tests: XCTestCase {

    func test_init_doesNotRequestDataFromURL() {
        let (client, _) = makeSUT()
        
        XCTAssertTrue(client.requestedURLs.isEmpty)
    }
    
    func test_load_requestsDataFromURL() {
        let url = URL(string: "https://a-given-url.com")!
        let (client, sut) = makeSUT(url: url)
        
        sut.load { _ in }
        
        XCTAssertEqual(client.requestedURLs, [url])
    }
    
    func test_loadTwice_requestsDataFromURLTwice() {
        let url = URL(string: "https://a-given-url.com")!
        let (client, sut) = makeSUT(url: url)
        
        sut.load { _ in }
        sut.load { _ in }
        
        XCTAssertEqual(client.requestedURLs, [url, url])
    }
    
    func test_load_deliversErrorForClientError() {
        let (client, sut) = makeSUT()
        expect(sut, toCompleteWithResult: .failure(RemoteFeedLoader.Error.connectivity)) {
            client.complete(withError: anyError())
        }
    }
    
    func test_load_deliversErrorForNon200HTTPResponseAndValidJSONData() {
        let (client, sut) = makeSUT()
        let samples = [199, 201, 300, 400, 500].enumerated()
        samples.forEach { index, code in
            expect(sut, toCompleteWithResult: LoadFeedResult.failure(RemoteFeedLoader.Error.invalidData)) {
                client.complete(withStatusCode: code, data: validEmptyJSONData(), at: index)
            }
        }
    }
    
    func test_load_deliversErrorFor200HTTPResponseAndInvalidJSONData() {
        let (client, sut) = makeSUT()
        expect(sut, toCompleteWithResult: LoadFeedResult.failure(RemoteFeedLoader.Error.invalidData)) {
            client.complete(withStatusCode: 200, data: invalidJSONData())
        }
    }
    
    func test_load_deliversEmptyFeedFor200HTTPResponseAndValidEmptyJSONData() {
        let (client, sut) = makeSUT()
        expect(sut, toCompleteWithResult: LoadFeedResult.success([])) {
            client.complete(withStatusCode: 200, data: validEmptyJSONData())
        }
    }
    
    func test_load_deliversValidFeedFor200HTTPResponseAndValidJSONData() {
        let (client, sut) = makeSUT()
        expect(sut, toCompleteWithResult: LoadFeedResult.success(validFeed().models)) {
            client.complete(withStatusCode: 200, data: validFeed().jsonData)
        }
    }
    
    // MARK: - Helpers
    
    private func makeSUT(url: URL = URL(string: "https://a-url.com")!,
                         file: StaticString = #file,
                         line: UInt = #line) -> (client: HTTPClientSpy, sut: RemoteFeedLoader) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        
        trackForMemoryLeak(instance: client, file: file, line: line)
        trackForMemoryLeak(instance: sut, file: file, line: line)
        
        return (client, sut)
    }
    
    private func trackForMemoryLeak(instance: AnyObject, file: StaticString = #file, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
    }
    
    private func anyError() -> Error {
        NSError(domain: "can't reach server", code: 0, userInfo: nil)
    }
    
    private func invalidJSONData() -> Data {
        "invalid json data".data(using: .utf8)!
    }
    
    private func validEmptyJSONData() -> Data {
        let jsonString = "{ \"items\" : [] }"
        return jsonString.data(using: .utf8)!
    }
    
    private func validFeed() -> (jsonData: Data, models: [Feed]) {
        let jsonString = """
        {
            "items" : [
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
        
        let feed1 = Feed(id: UUID(uuidString: "73A7F70C-75DA-4C2E-B5A3-EED40DC53AA6")!,
                         description: "Description 1",
                         location: "Location 1",
                         imageURL: URL(string: "https://url-1.com")!)
        let feed2 = Feed(id: UUID(uuidString: "BA298A85-6275-48D3-8315-9C8F7C1CD109")!,
                         description: nil,
                         location: "Location 2",
                         imageURL: URL(string: "https://url-2.com")!)
        let feed3 = Feed(id: UUID(uuidString: "5A0D45B3-8E26-4385-8C5D-213E160A5E3C")!,
                         description: "Description 3",
                         location: nil,
                         imageURL: URL(string: "https://url-3.com")!)
        let feed4 = Feed(id: UUID(uuidString: "FF0ECFE2-2879-403F-8DBE-A83B4010B340")!,
                         description: nil,
                         location: nil,
                         imageURL: URL(string: "https://url-4.com")!)
        
        let jsonData = jsonString.data(using: .utf8)!
        let models = [feed1, feed2, feed3, feed4]
        
        return (jsonData, models)
    }
    
    private func expect(_ sut: RemoteFeedLoader,
                        toCompleteWithResult expectedResult: LoadFeedResult,
                        for action: () -> Void,
                        file: StaticString = #file,
                        line: UInt = #line) {
        let expectation = expectation(description: "wait load to complete")
        sut.load { receivedResult in
            switch (receivedResult, expectedResult) {
            case let (.success(receivedFeed), .success(expectedFeed)):
                XCTAssertEqual(receivedFeed, expectedFeed, file: file, line: line)
            case let (.failure(receivedError as RemoteFeedLoader.Error) , .failure(expectedError as RemoteFeedLoader.Error)):
                XCTAssertEqual(receivedError, expectedError, file: file, line: line)
            default:
                XCTFail("Expected result \(expectedResult) but received \(receivedResult)", file: file, line: line)
            }
            
            expectation.fulfill()
        }
        
        action()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    private class HTTPClientSpy: HTTPClient {
        var messages = [(url: URL, completion: (HTTPClientResult) -> Void)]()
        var requestedURLs: [URL] {
            messages.map { $0.url }
        }
        
        func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
            messages.append((url, completion))
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
