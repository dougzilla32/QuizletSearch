//
//  QueryResult.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/29/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import Foundation

class QueryResult {
    let page: Int
    let totalPages: Int
    let totalResults: Int
    let imageSetCount: Int
    let qsets: [QSet]
    
    init(copyFrom: QueryResult, qsets: [QSet]) {
        self.page = copyFrom.page
        self.totalPages = copyFrom.totalPages
        self.totalResults = copyFrom.totalResults
        self.imageSetCount = copyFrom.imageSetCount
        self.qsets = qsets
    }
    
    init(jsonAny: AnyObject) throws {
        if let json = jsonAny as? NSDictionary,
            page = json["page"] as? Int,
            totalPages = json["total_pages"] as? Int,
            totalResults = json["total_results"] as? Int,
            imageSetCount = json["image_set_count"] as? Int,
            jsonSets = json["sets"] as? Array<NSDictionary>,
            qsets = QSet.setsFromJSON(jsonSets) {
                self.page = page
                self.totalPages = totalPages
                self.totalResults = totalResults
                self.imageSetCount = imageSetCount
                self.qsets = qsets
        }
        else {
            self.page = 0
            self.totalPages = 0
            self.totalResults = 0
            self.imageSetCount = 0
            self.qsets = [QSet]()
            throw UnexpectedResponse()
        }
    }
}