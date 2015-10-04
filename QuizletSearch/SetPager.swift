//
//  SetPager.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/29/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit
import Foundation

class SetPager {
    let quizletSession = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel.quizletSession    

    let paginationSize = 30
    let query: String?
    let creator: String?
    var totalResults: Int?
    
    var qsets: [[QSet]?]?
    var loadingPages = Set<Int>()
    
    init(query: String?, creator: String?) {
        self.query = query
        self.creator = creator
    }
    
    func getQSetForRow(row: Int) -> QSet? {
        let pageIndex = row / paginationSize
        let pageOffset = row % paginationSize
        // TODO: fatal error: Array index out of range (when scrolling after searching for "dogs")
        return qsets?[pageIndex]?[pageOffset]
    }
    
    func loadRow(row: Int, completionHandler: (pageLoaded: Int?) -> Void) {
        let page = row / paginationSize + 1
        loadPage(page, completionHandler: completionHandler)
    }
    
    func loadPage(page: Int, completionHandler: (pageLoaded: Int?) -> Void) {
        guard (page > 0) else {
            NSLog("Page number is zero or less")
            return
        }
        if (qsets != nil) {
            guard (page <= qsets!.count) else {
                NSLog("Requested page \(page) is greater than the number of pages \(self.qsets!.count)")
                return
            }
            if (qsets![page-1] != nil) {
                NSLog("Page \(page) alread loaded")
                return
            }
        }

        if (loadingPages.contains(page)) {
            return
        }
        loadingPages.insert(page)
        
        quizletSession.searchSetsWithQuery(query, creator: creator, imagesOnly: nil, modifiedSince: nil, page: page, perPage: paginationSize, allowCellularAccess: true, completionHandler: { (result: QueryResult?) in
            
            dispatch_async(dispatch_get_main_queue(), {
                guard page > 0 else {
                    NSLog("Negative page value: \(page)")
                    abort()
                }
                guard result != nil else {
                    completionHandler(pageLoaded: nil)
                    return
                }
                if (result!.page != page) {
                    NSLog("Expected page number \(page) does not match actual page number \(result!.page)")
                }
                
                if (self.qsets == nil) {
                    let expectedPages = (result!.totalResults + self.paginationSize - 1) / self.paginationSize
                    if (expectedPages != result!.totalPages) {
                        NSLog("Expected number of pages \(expectedPages) does not match actual number of pages \(result!.totalPages)")
                    }
                    
                    self.qsets = [[QSet]?](count: result!.totalPages, repeatedValue: nil)
                }
                
                guard page <= self.qsets!.count else {
                    NSLog("Page \(page) is greater than the number of pages \(self.qsets!.count)")
                    return
                }
                
                // TODO: handle case where the number of qsets in the result is less than what we expected (test case: search for "hello" and scroll down to page 8 and page 9
                self.qsets![page-1] = result!.qsets
                self.totalResults = result!.totalResults
                self.loadingPages.remove(page)
                
                completionHandler(pageLoaded: page)
            })
        })
    }
}