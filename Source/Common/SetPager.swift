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

class SetPager: Pager<QSet> {
    static var firstChanceUsers = Set<String>()  // Users that definitively work with 'searchSetsWithQuery'
    static var secondChanceUsers = Set<String>() // Users that definitively do not work with 'searchSetsWithQuery'

    var creator: String?
    var classId: String?
    
    var userSetsCreator: String?
    var userSetsQSets: [QSet]?
    var classSetsId: String?
    var classSetsQSets: [QSet]?
    
    init(query: String?, creator: String?, classId: String?) {
        super.init(query: query)
        self.creator = creator
        self.classId = classId
    }
    
    convenience override init(query: String?) {
        self.init(query: query, creator: nil, classId: nil)
    }
    
    convenience init(query: String?, creator: String) {
        self.init(query: query, creator: creator, classId: nil)
    }
    
    convenience init(query: String?, classId: String?) {
        self.init(query: query, creator: nil, classId: classId)
    }
    
    override func resetAllPages() {
        super.resetAllPages()

        if (classId != nil) {
            paginationSize = 0
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
    
    override func reset(query: String?) {
        reset(query: query, creator: nil, classId: nil)
    }
    
    func reset(query: String?, creator: String) {
        reset(query: query, creator: creator, classId: nil)
    }
    
    func reset(query: String?, classId: String?) {
        reset(query: query, creator: nil, classId: classId)
    }
    
    override func isEmptyQuery() -> Bool {
        return (isEmpty(query) && isEmpty(creator) && isEmpty(classId))
            || (creator != nil && creator!.isEmpty)  // If creator is non-nil and empty then do not run the query
            || (classId != nil && classId!.isEmpty)  // If classId is non-nil and empty then do not run the query
    }
    
    func searchSetsWithQuery(page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void, trySecondChanceUser: Bool) {
        
        paginationSize = PagerConstants.DefaultPaginationSize
        
        self.quizletSession.searchSetsWithQuery(self.query, creator: self.creator, autocomplete: false, imagesOnly: nil, modifiedSince: nil, page: page, perPage: self.paginationSize, allowCellularAccess: true, completionHandler: { (queryResult: QueryResult<QSet>?, response: URLResponse?, error: Error?) in
            
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
                    for qset in queryResult!.items {
                        setIds.append(qset.id)
                    }
                    
                    self.quizletSession.getSetsForIds(setIds, modifiedSince: nil, allowCellularAccess: true, completionHandler: { (qsets: [QSet]?, response: URLResponse?, error: Error?) in
                        if (qsets == nil || resetToken < self.resetCounter) {
                            // Cancelled or error
                            self.loadingPages.remove(page)
                            return
                        }
                        
                        self.loadPageResult(QueryResult<QSet>(copyFrom: queryResult!, items: qsets!), response: .complete, page: page, resetToken: resetToken, completionHandler: completionHandler)
                    })
                }
            }
        })
    }
    
    func getAllSetsForUser(page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        
        if (userSetsCreator == self.creator) {
            trace("CACHED USER SETS")
            self.itemsResult(userSetsQSets, page: page, resetToken: resetToken, completionHandler: completionHandler)
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
            
            self.itemsResult(qsets, page: page, resetToken: resetToken, completionHandler: completionHandler)
        })
    }
    
    func getSetsInClass(page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {

        if (classSetsId == self.classId) {
            trace("CACHED CLASS SETS")
            self.itemsResult(classSetsQSets, page: page, resetToken: resetToken, completionHandler: completionHandler)
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
            
            self.itemsResult(qsets, page: page, resetToken: resetToken, completionHandler: completionHandler)
        })
    }
    
    override func invokeQuery(page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
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
    }
    
    override func filterItems(_ items: [QSet]) -> [QSet] {
        if (query == nil || query!.isEmpty) {
            return items
        }

        let q = query!.lowercased().decomposeAndNormalize()
        var newQSets: [QSet] = []
        for qset in items {
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
    
    override func validateItem(_ item: QSet) {
        if (item.terms.count == 0) {
            // No permission to see the terms and definitions for this set
            item.terms.append(QTerm(id: 0, term: "🔐", definition: ""))
        }
    }
    
    override func emptyItem() -> QSet {
        return QSet(id: 0, url: "", title: "", description: "", createdBy: "", creatorId: 0, createdDate: 0, modifiedDate: 0, classIds: "")
    }
}
