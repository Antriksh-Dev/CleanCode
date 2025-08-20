//
//  RemoteFeedLoader.swift
//  CleanFeed
//
//  Created by Antriksh Verma on 8/20/25.
//

import Foundation

public class RemoteFeedLoader: FeedLoader {
    private let url: URL
    private let client: HTTPClient
    
    
    public enum Error: Swift.Error {
        case connectivity
        case invalidData
    }

    public init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }
    
    public func load(completion: @escaping (LoadFeedResult) -> Void) {
        client.get(from: url) { [weak self] result in
            guard let _ = self else { return }
            
            switch result {
            case let .success(data, response):
                completion(RemoteFeedMapper.map(data: data, response: response))
            case .failure(_):
                completion(.failure(Error.connectivity))
            }
        }
    }
}
