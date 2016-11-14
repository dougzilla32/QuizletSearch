//
//  QueryResult.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/29/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import Foundation

class QueryResult<Element> {
    let page: Int
    let totalPages: Int
    let totalResults: Int
//    let imageSetCount: Int
    let items: [Element]
    
    init(page: Int, totalPages: Int, totalResults: Int, /* imageSetCount: Int, */ items: [Element]) {
        self.page = page
        self.totalPages = totalPages
        self.totalResults = totalResults
//        self.imageSetCount = imageSetCount
        self.items = items
    }
    
    init(copyFrom: QueryResult<Element>, items: [Element]) {
        self.page = copyFrom.page
        self.totalPages = copyFrom.totalPages
        self.totalResults = copyFrom.totalResults
//        self.imageSetCount = copyFrom.imageSetCount
        self.items = items
    }
    
    init(jsonAny: Any, itemsFromJSON: (_ json: NSDictionary) -> Array<Element>?) throws {
        if let json = jsonAny as? NSDictionary,
            let page = json["page"] as? Int,
            let totalPages = json["total_pages"] as? Int,
            let totalResults = json["total_results"] as? Int,
//            let imageSetCount = json["image_set_count"] as? Int,
            let items = itemsFromJSON(json) {
                self.page = page
                self.totalPages = totalPages
                self.totalResults = totalResults
//                self.imageSetCount = imageSetCount
                self.items = items
        }
        else {
            self.page = 0
            self.totalPages = 0
            self.totalResults = 0
//            self.imageSetCount = 0
            self.items = [Element]()
            throw UnexpectedResponse()
        }
    }
}
