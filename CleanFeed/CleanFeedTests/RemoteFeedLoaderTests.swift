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
 1. System execute "Load Feed" command with above data
 2. System downloads data from the URL
 3. System validates the downloaded data
 4. System creates Feed models using valid data
 5. System delivers Feed of the user
 
 Invalid Data - error course (sad path):
 1. System delivers invalid data error
 
 No Connectivity - error course (sad path):
 1. System delivers connectivity error
 
*/

import XCTest

final class RemoteFeedLoaderTests: XCTestCase {


}
