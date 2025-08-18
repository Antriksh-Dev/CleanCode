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

struct RemoteFeed: Codable {
    let items: [RemoteFeedItem]
    
    init(items: [RemoteFeedItem]) {
        self.items = items
    }
    
    func feed() -> [Feed] {
        items.map { remoteFeed in
            Feed(id: remoteFeed.id,
                 description: remoteFeed.description,
                 location: remoteFeed.location,
                 imageURL: remoteFeed.image)
        }
    }
    
    struct RemoteFeedItem: Codable {
        let id: UUID
        let description: String?
        let location: String?
        let image: URL
    }
}

class RemoteFeedLoader {
    let url: URL
    let client: HTTPClient
    
    init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }
    
    func load(completion: @escaping (RemoteFeedLoaderResult) -> Void) {
        client.get(from: url) { result in
            switch result {
            case let .success(data, response):
                guard response.statusCode == 200,
                      let remoteFeed = try? JSONDecoder().decode(RemoteFeed.self, from: data) else {
                    completion(.failure(.invalidData))
                    return
                }
                completion(.success(remoteFeed.feed()))
            case .failure(_):
                completion(.failure(.connectivity))
            }
        }
    }
}

final class RemoteFeedLoaderTests: XCTestCase {

    func test_init_doesNotRequestDataFromURL() {
        let url = URL(string: "https://a-given-url.com")!
        let (client, _) = makeSUT(with: url)
        
        XCTAssertTrue(client.requestedURLs.isEmpty)
    }
    
    func test_load_requestsDataFromURL() {
        let url = URL(string: "https://a-given-url.com")!
        let (client, sut) = makeSUT(with: url)
        
        sut.load { _ in }
        
        XCTAssertEqual(client.requestedURLs, [url])
    }

    func test_load_givesErrorForClientError() {
        let url = URL(string: "https://a-given-url.com")!
        let (client, sut) = makeSUT(with: url)
        
        let error = NSError()
        var receivedResult: RemoteFeedLoaderResult? = nil
        
        sut.load { receivedResult = $0 }
        client.complete(with: error)
        
        XCTAssertEqual(receivedResult, .failure(.connectivity))
    }
    
    func test_load_givesErrorForNon200HTTPResponseWithValidData() {
        let url = URL(string: "https://a-given-url.com")!
        let (client, sut) = makeSUT(with: url)
        
        let samples = [199, 201, 300, 400, 500].enumerated()
        for (index, code) in samples {
            
            var receivedResult: RemoteFeedLoaderResult? = nil
            sut.load { receivedResult = $0 }
            client.complete(with: code, data: validEmptyJSONData(), at: index)
            
            XCTAssertEqual(receivedResult, .failure(.invalidData))
        }
    }
    
    func test_load_givesErrorFor200HTTPResponseWithInvalidData() {
        let url = URL(string: "https://a-given-url.com")!
        let (client, sut) = makeSUT(with: url)
        
        var receivedResult: RemoteFeedLoaderResult? = nil
        sut.load { receivedResult = $0 }
        
        client.complete(with: 200, data: invalidJSONData())
        
        XCTAssertEqual(receivedResult, .failure(.invalidData))
    }
    
    func test_load_givesEmptyFeedFor200HTTPResponseWithEmptyValidData() {
        let url = URL(string: "https://a-given-url.com")!
        let (client, sut) = makeSUT(with: url)
        
        var receivedResult: RemoteFeedLoaderResult? = nil
        sut.load { receivedResult = $0 }
        client.complete(with: 200, data: validEmptyJSONData())
        
        XCTAssertEqual(receivedResult, (.success([])))
    }
    
    func test_load_givesValidFeedFor200HTTPResponseWithValidData() {
        let url = URL(string: "https://a-given-url.com")!
        let (client, sut) = makeSUT(with: url)
        
        var receivedResult: RemoteFeedLoaderResult? = nil
        sut.load { receivedResult = $0 }
        client.complete(with: 200, data: validNonEmptyFeed().jsonData)
        
        XCTAssertEqual(receivedResult, .success(validNonEmptyFeed().models))
    }
    
    // MARK: - Helpers
    
    private func makeSUT(with url: URL) -> (client: HTTPClientSpy, sut: RemoteFeedLoader) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        
        return (client, sut)
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
    
    private class HTTPClientSpy: HTTPClient {
        var requestedURLs = [URL]()
        var completions = [(HTTPClientResult) -> Void]()
        
        func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
            requestedURLs.append(url)
            completions.append(completion)
        }
        
        func complete(with error: Error, at index: Int = 0) {
            completions[index](.failure(error))
        }
        
        func complete(with statusCode: Int, data: Data, at index: Int = 0) {
            let response = HTTPURLResponse(url: requestedURLs[index],
                                           statusCode: statusCode,
                                           httpVersion: nil,
                                           headerFields: nil)!
            completions[index](.success(data, response))
        }
    }
}
