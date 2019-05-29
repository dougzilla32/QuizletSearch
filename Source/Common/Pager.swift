//
//  Pager.swift
//  QuizletSearch
//
//  Created by Doug on 11/13/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import UIKit

class PagerConstants {
    static var DefaultPaginationSize = 30
    static let DefaultPagerPause = Int64(NSEC_PER_SEC/4)
}

class Pager<Element> {
    let quizletSession = (UIApplication.shared.delegate as! AppDelegate).dataModel.quizletSession

    var query: String?
    
    var paginationSize = PagerConstants.DefaultPaginationSize
    var pagerPause = PagerConstants.DefaultPagerPause
    var resetCounter = 0
    var enabled = true

    var items: [[Element]?]?
    var itemsToken = 0
    
    var loadingPages = Set<Int>()
    var totalPages: Int?
    var totalResults: Int?
    
    init(query: String?) {
        self.query = query
    }
    
    func resetAllPages() {
        loadingPages.removeAll()
        resetCounter += 1
        paginationSize = PagerConstants.DefaultPaginationSize
    }
    
    func reset(query: String?) {
        resetAllPages()
        
        self.query = query
    }

    func peekItemForRow(_ row: Int) -> Element? {
        if (paginationSize == 0) { return nil }
        let pageIndex = row / paginationSize
        let pageOffset = row % paginationSize
        return items?[pageIndex]?[pageOffset]
    }
    
    func getItemForRow(_ row: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) -> Element? {
        if (paginationSize == 0) { return nil }
        let pageIndex = row / paginationSize
        let pageOffset = row % paginationSize
        let item = items?[pageIndex]?[pageOffset]
        if (item == nil || itemsToken < resetCounter) {
            loadRow(row, completionHandler: completionHandler)
        }
        return item
    }
    
    func updateQuery(_ query: String?) {
        if (self.query != query) {
            self.query = query
            resetAllPages()
        }
    }
    
    func updateEnabled(_ enabled: Bool) {
        if (self.enabled != enabled) {
            self.enabled = enabled
            resetAllPages()
        }
    }
    
    func isEmptyQuery() -> Bool {
        return isEmpty(query)
    }

    func isEmpty(_ s: String?) -> Bool {
        return s == nil || s!.isEmpty
    }
    
    func isLoading() -> Bool {
        return loadingPages.count > 0
    }
    
    func loadRow(_ row: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        let page = row / paginationSize + 1
        loadPage(page, completionHandler: completionHandler)
    }

    func loadPage(_ page: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        guard (page > 0) else {
            NSLog("Page number is zero or less")
            return
        }
        
        if (!enabled || isEmptyQuery()) {
            self.totalPages = 0
            self.totalResults = 0
            self.items = nil
            self.itemsToken = resetCounter
            if (enabled) {
                completionHandler(0..<0, 0, PagerResponse.complete)
            }
            return
        }
        
        if (items != nil && itemsToken == resetCounter) {
            guard (page <= items!.count) else {
                NSLog("Requested page \(page) is greater than the number of pages \(self.items!.count)")
                return
            }
            if (items![page-1] != nil) {
                NSLog("Page \(page) already loaded")
                return
            }
        }
        
        if (loadingPages.contains(page)) {
            return
        }
        loadingPages.insert(page)
        
        let resetToken = self.resetCounter
        let q = self.query
        
        trace("SEARCH IN", self.query, q, resetToken)
        // Insert a delay so that keyboard response on the iPhone is better
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(pagerPause) / Double(NSEC_PER_SEC), execute: {
            
            if (resetToken < self.resetCounter) {
                self.loadingPages.remove(page)
                trace("SEARCH CANCEL", self.query, q, resetToken)
                return
            }
            trace("SEARCH GO", self.query, q, resetToken)
            
            self.invokeQuery(page: page, resetToken: resetToken, completionHandler: completionHandler)
        })
    }
    
    // Subclasses must override this function
    func invokeQuery(page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
    }
    
    // Subclasses may override this function
    func filterItems(_ items: [Element]) -> [Element] {
        return items
    }
    
    // Subclasses may override this function
    func validateItem(_ item: Element) {
    }

    func itemsResult(_ itemsOpt: [Element]?, page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        let items = self.filterItems(itemsOpt!)
        
        self.paginationSize = items.count
        
        for item in items {
            validateItem(item)
        }
        
        let queryResult = QueryResult<Element>(page: page, totalPages: (items.count > 0) ? 1 : 0, totalResults: items.count, /* imageSetCount: 0, */ items: items)
        
        self.loadPageResult(queryResult, response: .complete, page: page, resetToken: resetToken, completionHandler: completionHandler)
    }
    
    // Subclasses must override this function
    func emptyItem() -> Element! {
        return nil
    }
    
    func loadPageResult(_ result: QueryResult<Element>, response: PagerResponse, page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        DispatchQueue.main.async(execute: {
            trace("SEARCH RESULT", self.query, result.items.count)
            if (response == .complete) {
                self.loadingPages.remove(page)
            }
            
            guard page > 0 else {
                NSLog("Negative page value: \(page)")
                return
            }
            
            if (self.itemsToken == resetToken) {
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
            
            // Check if 'result.page' is consistent
            if (result.page != page) {
                NSLog("Expected page number \(page) does not match actual page number \(result.page)")
            }
            
            // Clear the previous search assist results
            if (self.itemsToken < resetToken) {
                self.items = nil
                self.itemsToken = resetToken
            }
            
            // If there are no pages then call completionHandler with 'nil'
            if (result.totalPages == 0) {
                self.items = nil
                completionHandler(0..<0, result.totalResults, response)
                return
            }
            
            if (self.items == nil) {
                let expectedPages = (self.paginationSize == 0) ? 0
                    : (result.totalResults + self.paginationSize - 1) / self.paginationSize
                if (expectedPages != result.totalPages) {
                    NSLog("Expected number of pages \(expectedPages) does not match actual number of pages \(result.totalPages)")
                }
                
                self.items = [[Element]?](repeating: nil, count: result.totalPages)
            }
            
            guard page <= self.items!.count else {
                NSLog("Page requested \(page) is greater than the number of pages received \(self.items!.count)")
                return
            }
            
            // Handle case where the number of qsets in the result is less than what we expected (test case: search for "hello" and scroll down to page 8 and page 9 or search for "dogs" and scroll to page 7 or so
            // Note: Quizlet page numbering starts from 1 rather than 0
            let remaining = result.totalResults - (result.page - 1) * self.paginationSize
            let expectedNumberOfQSets = Swift.min(remaining, self.paginationSize)
            if (result.items.count < expectedNumberOfQSets) {
                // NSLog("Expected \(expectedNumberOfQSets) in page \(result.page) but got \(result.qsets.count)")
                self.items![page-1] = result.items
                for _ in result.items.count..<expectedNumberOfQSets {
                    self.items![page-1]!.append(self.emptyItem())
                }
            }
            else {
                // Note: Quizlet page numbering starts from 1 rather than 0
                self.items![page-1] = result.items
            }
            
            let start = (page-1) * self.paginationSize
            let end = start + Swift.min(self.paginationSize, self.totalResults! - start)
            completionHandler(
                start..<end,
                self.totalResults!,
                response)
        })
    }
}
