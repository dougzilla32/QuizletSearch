//
//  SetPager.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/29/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit
import Foundation

enum PagerResponse {
    case partial, complete
}

class SetPager {
    let quizletSession = (UIApplication.shared.delegate as! AppDelegate).dataModel.quizletSession
    
    static let DefaultPaginationSize = 30
    static let DefaultPagerPause = Int64(NSEC_PER_SEC/4)
    
    static var firstChanceUsers = Set<String>()  // Users that definitively work with 'searchSetsWithQuery'
    static var secondChanceUsers = Set<String>() // Users that definitively do not work with 'searchSetsWithQuery'

    var paginationSize = DefaultPaginationSize
    var query: String?
    var creator: String?
    var classId: String?
    var pagerPause = DefaultPagerPause
    
    var qsets: [[QSet]?]?
    var qsetsToken = 0
    var resetCounter = 0
    var enabled = true
    
    var userSetsCreator: String?
    var userSetsQSets: [QSet]?
    var classSetsId: String?
    var classSetsQSets: [QSet]?
    
    var loadingPages = Set<Int>()
    var totalPages: Int?
    var totalResults: Int?
    
    init(query: String?, creator: String?, classId: String?) {
        self.query = query
        self.creator = creator
        self.classId = classId
    }
    
    convenience init(query: String?) {
        self.init(query: query, creator: nil, classId: nil)
    }
    
    convenience init(query: String?, creator: String) {
        self.init(query: query, creator: creator, classId: nil)
    }
    
    convenience init(query: String?, classId: String?) {
        self.init(query: query, creator: nil, classId: classId)
    }
    
    func resetAllPages() {
        loadingPages.removeAll()
        resetCounter += 1
        
        if (classId != nil) {
            paginationSize = 0
        }
        else {
            paginationSize = SetPager.DefaultPaginationSize
        }
    }
    
    func reset(query: String?, creator: String?, classId: String?) {
        resetAllPages()
        
        self.query = query
        self.creator = creator
        self.classId = classId
        
        if (userSetsCreator != creator) {
            userSetsCreator = nil
            userSetsQSets = nil
        }
        if (classSetsId != classId) {
            classSetsId = nil
            classSetsQSets = nil
        }
    }
    
    func reset(query: String?) {
        reset(query: query, creator: nil, classId: nil)
    }
    
    func reset(query: String?, creator: String) {
        reset(query: query, creator: creator, classId: nil)
    }
    
    func reset(query: String?, classId: String?) {
        reset(query: query, creator: nil, classId: classId)
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
        return (isEmpty(query) && isEmpty(creator) && isEmpty(classId))
            || (creator != nil && creator!.isEmpty)  // If creator is non-nil and empty then do not run the query
            || (classId != nil && classId!.isEmpty)  // If classId is non-nil and empty then do not run the query
    }
    
    func isEmpty(_ s: String?) -> Bool {
        return s == nil || s!.isEmpty
    }
    
    func isLoading() -> Bool {
        return loadingPages.count > 0
    }
    
    func peekQSetForRow(_ row: Int) -> QSet? {
        if (paginationSize == 0) { return nil }
        let pageIndex = row / paginationSize
        let pageOffset = row % paginationSize
        return qsets?[pageIndex]?[pageOffset]
    }
    
    func getQSetForRow(_ row: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) -> QSet? {
        if (paginationSize == 0) { return nil }
        let pageIndex = row / paginationSize
        let pageOffset = row % paginationSize
        let qset = qsets?[pageIndex]?[pageOffset]
        if (qset == nil || qsetsToken < resetCounter) {
            loadRow(row, completionHandler: completionHandler)
        }
        return qset
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
            self.qsets = nil
            self.qsetsToken = resetCounter
            if (enabled) {
                completionHandler(0..<0, 0, PagerResponse.complete)
            }
            return
        }

        if (qsets != nil && qsetsToken == resetCounter) {
            guard (page <= qsets!.count) else {
                NSLog("Requested page \(page) is greater than the number of pages \(self.qsets!.count)")
                return
            }
            if (qsets![page-1] != nil) {
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
            
            if (self.classId != nil) {
                self.getSetsInClass(page: page, resetToken: resetToken, completionHandler: completionHandler)
            }
            else if (!self.isEmpty(self.creator) && SetPager.firstChanceUsers.contains(self.creator!)) {
                self.searchSetsWithQuery(page: page, resetToken: resetToken, completionHandler: completionHandler, trySecondChanceUser: false)
            }
            else if (!self.isEmpty(self.creator) && SetPager.secondChanceUsers.contains(self.creator!)) {
                self.getAllSetsForUser(page: page, resetToken: resetToken, completionHandler: completionHandler)
            }
            else {
                self.searchSetsWithQuery(page: page, resetToken: resetToken, completionHandler: completionHandler, trySecondChanceUser: true)
            }
        })
    }
    
    func searchSetsWithQuery(page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void, trySecondChanceUser: Bool) {
        
        paginationSize = SetPager.DefaultPaginationSize
        
        self.quizletSession.searchSetsWithQuery(self.query, creator: self.creator, autocomplete: false, imagesOnly: nil, modifiedSince: nil, page: page, perPage: self.paginationSize, allowCellularAccess: true, completionHandler: { (queryResult: QueryResult?, response: URLResponse?, error: Error?) in
            
            trace("SEARCH OUT", self.query, resetToken)
            if (queryResult == nil || resetToken < self.resetCounter) {
                // Cancelled or error - if cancelled do nothing, instead just let the subsequent request fill in the rows
                self.loadingPages.remove(page)
                return
            }
            
            if (queryResult!.totalResults > 0 && !self.isEmpty(self.creator)) {
                SetPager.firstChanceUsers.insert(self.creator!)
            }
            
            if (trySecondChanceUser && queryResult!.totalResults == 0 && !self.isEmpty(self.creator)) {
                self.getAllSetsForUser(page: page, resetToken: resetToken, completionHandler: completionHandler)
            }
            else {
                self.loadPageResult(queryResult!, response: .partial, page: page, resetToken: resetToken, completionHandler: completionHandler)
                
                if (queryResult!.totalResults > 0) {
                    var setIds = [Int64]()
                    for qset in queryResult!.qsets {
                        setIds.append(qset.id)
                    }
                    
                    self.quizletSession.getSetsForIds(setIds, modifiedSince: nil, allowCellularAccess: true, completionHandler: { (qsets: [QSet]?, response: URLResponse?, error: Error?) in
                        if (qsets == nil || resetToken < self.resetCounter) {
                            // Cancelled or error
                            self.loadingPages.remove(page)
                            return
                        }
                        
                        self.loadPageResult(QueryResult(copyFrom: queryResult!, qsets: qsets!), response: .complete, page: page, resetToken: resetToken, completionHandler: completionHandler)
                    })
                }
            }
        })
    }
    
    func getAllSetsForUser(page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        
        if (userSetsCreator == self.creator) {
            trace("CACHED USER SETS")
            self.qsetsResult(userSetsQSets, page: page, resetToken: resetToken, completionHandler: completionHandler)
            return
        }
        
        // Try using the '2.0/users/<username>' query.  For some unexplained reason, the search query will return no results for certain users, where the user query will return all the expected results.
        self.quizletSession.getAllSetsForUser(self.creator!, modifiedSince: nil, allowCellularAccess: true, completionHandler: { (qsetsOpt: [QSet]?, response: URLResponse?, error: Error?) in
            
            // Check for NOT FOUND status code
            let code = (response as? HTTPURLResponse)?.statusCode
            let foundUser = (code != 404 && code != 410)
            if ((qsetsOpt == nil && foundUser) || resetToken < self.resetCounter) {
                // Cancelled or unexpected error
                self.loadingPages.remove(page)
                return
            }
            
            // Found user and qsets
            let qsets = (qsetsOpt != nil) ? qsetsOpt! : []
            self.userSetsCreator = self.creator
            self.userSetsQSets = qsets

            if ((qsets.count > 0 || !foundUser) && self.isEmpty(self.query)) {
                SetPager.secondChanceUsers.insert(self.creator!)
            }
            
            self.qsetsResult(qsets, page: page, resetToken: resetToken, completionHandler: completionHandler)
        })
    }
    
    func getSetsInClass(page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {

        if (classSetsId == self.classId) {
            trace("CACHED CLASS SETS")
            self.qsetsResult(classSetsQSets, page: page, resetToken: resetToken, completionHandler: completionHandler)
            return
        }
        
        self.quizletSession.getSetsInClass(self.classId!, modifiedSince: nil, allowCellularAccess: true, completionHandler: { (qsetsOpt: [QSet]?, response: URLResponse?, error: Error?) in
            
            trace("CLASS SEARCH OUT", self.classId, resetToken)

            // Check for NOT FOUND status code
            let code = (response as? HTTPURLResponse)?.statusCode
            let foundClass = (code != 404 && code != 410)
            if ((qsetsOpt == nil && foundClass) || resetToken < self.resetCounter) {
                self.loadingPages.remove(page)
                // Cancelled or error - if cancelled do nothing, instead just let the subsequent request fill in the rows
                return
            }
            
            // Found class and qsets
            let qsets = (qsetsOpt != nil) ? qsetsOpt! : []
            self.classSetsId = self.classId
            self.classSetsQSets = qsets
            
            self.qsetsResult(qsets, page: page, resetToken: resetToken, completionHandler: completionHandler)
        })
    }
    
    func filterQSets(_ qsets: [QSet]) -> [QSet] {
        if (query == nil || query!.isEmpty) {
            return qsets
        }

        let q = query!.lowercased().decomposeAndNormalize()
        var newQSets: [QSet] = []
        for qset in qsets {
            if (qset.normalizedTitle == nil) {
                qset.normalizedTitle = qset.title.lowercased().decomposeAndNormalize()
            }
            if (qset.normalizedDescription == nil) {
                qset.normalizedDescription = qset.description.lowercased().decomposeAndNormalize()
            }
            if (qset.normalizedCreatedBy == nil) {
                qset.normalizedCreatedBy = qset.createdBy.lowercased().decomposeAndNormalize()
            }
            
            let options: NSString.CompareOptions = [.caseInsensitive, .WhitespaceInsensitiveSearch]
            if (StringWithBoundaries.characterRangesOfUnichars(qset.normalizedTitle!, targetString: q, options: options).count > 0 ||
                StringWithBoundaries.characterRangesOfUnichars(qset.normalizedDescription!, targetString: q, options: options).count > 0 ||
                StringWithBoundaries.characterRangesOfUnichars(qset.normalizedCreatedBy!, targetString: q, options: options).count > 0) {
                    newQSets.append(qset)
            }
            
//            if (qset.title.contains(query!, options: .CaseInsensitiveSearch)
//                || qset.description.contains(query!, options: .CaseInsensitiveSearch)
//                || qset.createdBy.contains(query!, options: .CaseInsensitiveSearch)) {
//                newQSets.append(qset)
//            }
        }
        return newQSets
    }
    
    func qsetsResult(_ qsetsOpt: [QSet]?, page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        let qsets = self.filterQSets(qsetsOpt!)
        
        self.paginationSize = qsets.count
        
        for qset in qsets {
            if (qset.terms.count == 0) {
                // No permission to see the terms and definitions for this set
                qset.terms.append(QTerm(id: 0, term: "🔐", definition: ""))
            }
        }
        
        let queryResult = QueryResult(page: page, totalPages: (qsets.count > 0) ? 1 : 0, totalResults: qsets.count, imageSetCount: 0, qsets: qsets)
        
        self.loadPageResult(queryResult, response: .complete, page: page, resetToken: resetToken, completionHandler: completionHandler)
    }
    
    func loadPageResult(_ result: QueryResult, response: PagerResponse, page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        DispatchQueue.main.async(execute: {
            trace("SEARCH RESULT", self.query, result.qsets.count)
            if (response == .complete) {
                self.loadingPages.remove(page)
            }
            
            guard page > 0 else {
                NSLog("Negative page value: \(page)")
                return
            }
            
            if (self.qsetsToken == resetToken) {
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
            if (self.qsetsToken < resetToken) {
                self.qsets = nil
                self.qsetsToken = resetToken
            }
            
            // If there are no pages then call completionHandler with 'nil'
            if (result.totalPages == 0) {
                self.qsets = nil
                completionHandler(0..<0, result.totalResults, response)
                return
            }
            
            if (self.qsets == nil) {
                let expectedPages = (self.paginationSize == 0) ? 0
                    : (result.totalResults + self.paginationSize - 1) / self.paginationSize
                if (expectedPages != result.totalPages) {
                    NSLog("Expected number of pages \(expectedPages) does not match actual number of pages \(result.totalPages)")
                }
                
                self.qsets = [[QSet]?](repeating: nil, count: result.totalPages)
            }
            
            guard page <= self.qsets!.count else {
                NSLog("Page requested \(page) is greater than the number of pages received \(self.qsets!.count)")
                return
            }
            
            // Handle case where the number of qsets in the result is less than what we expected (test case: search for "hello" and scroll down to page 8 and page 9 or search for "dogs" and scroll to page 7 or so
            // Note: Quizlet page numbering starts from 1 rather than 0
            let remaining = result.totalResults - (result.page - 1) * self.paginationSize
            let expectedNumberOfQSets = Swift.min(remaining, self.paginationSize)
            if (result.qsets.count < expectedNumberOfQSets) {
                // NSLog("Expected \(expectedNumberOfQSets) in page \(result.page) but got \(result.qsets.count)")
                self.qsets![page-1] = result.qsets
                for _ in result.qsets.count..<expectedNumberOfQSets {
                    self.qsets![page-1]!.append(QSet(id: 0, url: "", title: "", description: "", createdBy: "", creatorId: 0, createdDate: 0, modifiedDate: 0, classIds: ""))
                }
            }
            else {
                // Note: Quizlet page numbering starts from 1 rather than 0
                self.qsets![page-1] = result.qsets
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
