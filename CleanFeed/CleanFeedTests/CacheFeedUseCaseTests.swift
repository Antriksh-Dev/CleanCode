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

final class CacheFeedUseCaseTests: XCTestCase {

}
