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
            case let .success(_, response):
                guard response.statusCode == 200 else {
                    completion(.failure(.invalidData))
                    return
                }
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
            client.complete(with: code, data: validData(), at: index)
            
            XCTAssertEqual(receivedResult, .failure(.invalidData))
        }
    }
    
    // MARK: - Helpers
    
    private func makeSUT(with url: URL) -> (client: HTTPClientSpy, sut: RemoteFeedLoader) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        
        return (client, sut)
    }
    
    func validData() -> Data {
        let jsonString = "{ \"items\" : [] }"
        let data = jsonString.data(using: .utf8)!
        return data
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
