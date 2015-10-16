//
//  SetPager.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/29/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit
import Foundation

protocol QSetPager {
    var totalResults: Int? { get }
    
    func isLoading() -> Bool
    
    func peekQSetForRow(row: Int) -> QSet?

    func getQSetForRow(row: Int, completionHandler: (pageLoaded: Int?, response: PagerResponse) -> Void) -> QSet?
}

enum PagerResponse {
    case First, Last
}

class SetPager: QSetPager {
    let quizletSession = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel.quizletSession

    let paginationSize = 30
    var query: String?
    var creator: String?

    var qsets: [[QSet]?]?
    var prevQSets: [[QSet]?]?
    var isSearchAssist: Bool
    
    var loadingPages = Set<Int>()
    var totalPages: Int?
    var totalResults: Int?
    var validateTotals = true
    
    init(query: String?, creator: String?, isSearchAssist: Bool) {
        self.query = query
        self.creator = creator
        self.isSearchAssist = isSearchAssist
    }
    
    func resetQuery(query query: String?, creator: String?, isSearchAssist: Bool) {
        loadingPages.removeAll()
        
        self.query = query
        self.creator = creator
        self.isSearchAssist = isSearchAssist

        prevQSets = qsets
        qsets = nil
        validateTotals = false
    }
    
    func isLoading() -> Bool {
        return loadingPages.count > 0
    }
    
    func peekQSetForRow(row: Int) -> QSet? {
        let pageIndex = row / paginationSize
        let pageOffset = row % paginationSize
        var qset = qsets?[pageIndex]?[pageOffset]
        if (qset == nil) {
            qset = prevQSets?[pageIndex]?[pageOffset]
        }
        return qset
    }
    
    func getQSetForRow(row: Int, completionHandler: (pageLoaded: Int?, response: PagerResponse) -> Void) -> QSet? {
        let pageIndex = row / paginationSize
        let pageOffset = row % paginationSize
        var qset = qsets?[pageIndex]?[pageOffset]
        if (qset == nil) {
            loadRow(row, completionHandler: completionHandler)
            qset = prevQSets?[pageIndex]?[pageOffset]
        }
        return qset
    }
    
    func loadRow(row: Int, completionHandler: (pageLoaded: Int?, response: PagerResponse) -> Void) {
        let page = row / paginationSize + 1
        loadPage(page, completionHandler: completionHandler)
    }
    
    func loadPage(page: Int, completionHandler: (pageLoaded: Int?, response: PagerResponse) -> Void) {
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
        
        quizletSession.searchSetsWithQuery(query, creator: creator, autocomplete: isSearchAssist, imagesOnly: nil, modifiedSince: nil, page: page, perPage: paginationSize, allowCellularAccess: true, completionHandler: { (var queryResult: QueryResult?) in
            
            if (queryResult == nil) {
                // Cancelled or error
                return
            }

            if (!self.isSearchAssist && queryResult!.totalResults > 0) {
                var setIds = [Int64]()
                for qset in queryResult!.qsets {
                    setIds.append(qset.id)
                }
                
                self.quizletSession.getSetsForIds(setIds, modifiedSince: nil, allowCellularAccess: true, completionHandler: { (qsets: [QSet]?) in
                    if (qsets == nil) {
                        // Cancelled or error
                        return
                    }
                    
                    queryResult = QueryResult(copyFrom: queryResult!, qsets: qsets!)
                    self.loadPageResult(queryResult, response: .First /* .Last */, page: page, completionHandler: completionHandler)
                })
            }
            else {
                self.loadPageResult(queryResult, response: .First /* .Last */, page: page, completionHandler: completionHandler)
            }
            
            // It is possible to display sets in the table as soon as we get a response from searchSetsWithQuery but before the terms are available via getSetsForIds.  This is desirable if getSetsForIds is slow. To get this behavior, change .First to .Last in the call to loadPageResult above and uncomment the following line.
            // self.loadPageResult(queryResult, response: .First, page: page, completionHandler: completionHandler)
        })
    }
    
    func loadPageResult(queryResult: QueryResult?, response: PagerResponse, page: Int, completionHandler: (pageLoaded: Int?, response: PagerResponse) -> Void) {
        dispatch_async(dispatch_get_main_queue(), {
            if (response == .First) {
                self.loadingPages.remove(page)
            }
            
            guard page > 0 else {
                NSLog("Negative page value: \(page)")
                return
            }
            guard let result = queryResult else {
                completionHandler(pageLoaded: nil, response: response)
                return
            }
            
            if (self.validateTotals) {
                // Check if 'result.totalPages' is consistent
                if (self.totalPages != nil && self.totalPages != result.totalPages) {
                    NSLog("Total number of pages changed from \(self.totalPages!) to \(result.totalPages) in page \(result.page)")
                }
                
                // Check if 'result.totalResults' is consistent
                if (self.totalResults != nil && self.totalResults != result.totalResults) {
                    NSLog("Total number of results changed from \(self.totalResults!) to \(result.totalResults) in page \(result.page)")
                }
            }
            
            self.totalPages = result.totalPages
            self.totalResults = result.totalResults
            self.validateTotals = true

            // Check if 'result.page' is consistent
            if (result.page != page) {
                NSLog("Expected page number \(page) does not match actual page number \(result.page)")
            }
            
            // Clear the previous search assist results
            self.prevQSets = nil
            
            // If there are no pages then call completionHandler with 'nil'
            if (result.totalPages == 0) {
                self.qsets = nil
                completionHandler(pageLoaded: nil, response: response)
                return
            }
            
            if (self.qsets == nil) {
                let expectedPages = (result.totalResults + self.paginationSize - 1) / self.paginationSize
                if (expectedPages != result.totalPages) {
                    NSLog("Expected number of pages \(expectedPages) does not match actual number of pages \(result.totalPages)")
                }
                
                self.qsets = [[QSet]?](count: result.totalPages, repeatedValue: nil)
            }
            
            guard page <= self.qsets!.count else {
                NSLog("Page requested \(page) is greater than the number of pages received \(self.qsets!.count)")
                return
            }
            
            // Handle case where the number of qsets in the result is less than what we expected (test case: search for "hello" and scroll down to page 8 and page 9 or search for "dogs" and scroll to page 7 or so
            // Note: Quizlet page numbering starts from 1 rather than 0
            let remaining = result.totalResults - (result.page - 1) * self.paginationSize
            let expectedNumberOfQSets = min(remaining, self.paginationSize)
            if (result.qsets.count != expectedNumberOfQSets) {
                // NSLog("Expected \(expectedNumberOfQSets) in page \(result.page) but got \(result.qsets.count)")
                self.qsets![page-1] = result.qsets
                for _ in result.qsets.count...expectedNumberOfQSets {
                    self.qsets![page-1]!.append(QSet(id: 0, url: "", title: "", description: "", createdBy: "", creatorId: 0, createdDate: 0, modifiedDate: 0))
                }
            }
            else {
                // Note: Quizlet page numbering starts from 1 rather than 0
                self.qsets![page-1] = result.qsets
            }
            
            completionHandler(pageLoaded: page, response: response)
        })
    }
}