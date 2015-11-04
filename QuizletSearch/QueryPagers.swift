//
//  QueryPagers.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/16/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class PagerIndex {
    enum PagerType {
        case Query, Username, Class, IncludedSets, End
    }
    
    var type = PagerType.Query
    var index = 0
    
    init() { }
    
    init(type: PagerType, index: Int) {
        self.type = type
        self.index = index
    }
    
    func advance() {
        switch (type) {
        case .Query:
            type = .Username
        case .Username:
            type = .Class
        case .Class:
            type = .IncludedSets
        case .IncludedSets:
            type = .End
        default:
            type = .End
        }
        index = 0
    }
}

class QueryPagers: SequenceType {
    let MinTotalResultsHighWaterMark = 10
    let MaxTotalResults = 300
    
    let quizletSession = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel.quizletSession
    
    var queryPager: SetPager?
    var usernamePagers: [SetPager] = []
    var classPagers: [SetPager] = []
    var includedSetsPager: SetPager?
    // var excludedSets: [QSet] = []

    var totalResults: Int?
    var totalResultsNoMax: Int?
    
    // Do not allow the number of total results to shrink, because deleting rows is slow
    var totalResultsHighWaterMark: Int?
    
    func updateTotals() {
        var total = 0
        var stillLoading = false
        for pager in self {
            if let t = pager.totalResults {
                total += t
            }
            else {
                stillLoading = true
            }
        }
        totalResults = (stillLoading && total == 0) ? nil : min(total, MaxTotalResults)
        totalResultsNoMax = (stillLoading && total == 0) ? nil : total
        totalResultsHighWaterMark = max(totalResults, totalResultsHighWaterMark, MinTotalResultsHighWaterMark)
    }
    
    init() { }
    
    // MARK: - Query
    
    func executeSearch(pagerIndex: PagerIndex?, completionHandler: (affectedResults: Range<Int>?, totalResults: Int?, response: PagerResponse) -> Void) {
        
        // Cancel previous queries
        quizletSession.cancelQueryTasks()
        
        updateQuery()
        
        updateDuplicates(pagerIndex: pagerIndex)
        
        if (isEmpty()) {
            self.updateTotals()
            completionHandler(affectedResults: nil, totalResults: totalResults, response: PagerResponse.Last)
        }
        else {
            loadFirstPages(completionHandler: completionHandler)
        }
    }
    
    func updateQuery() {
        let query = queryPager?.query

        for pager in self {
            pager.updateQuery(query)
        }
        
        let b = hasUserOrClass()
        trace("updateEnabled", !b)
        queryPager?.updateEnabled(!b)
    }
    
    func hasUserOrClass() -> Bool {
        for p in usernamePagers {
            if (p.creator != nil && !p.creator!.isEmpty) {
                return true
            }
        }
        for p in classPagers {
            if (p.classId != nil && !p.classId!.isEmpty) {
                return true
            }
        }
        return false
    }
    
    func isEmpty() -> Bool {
        return (queryPager == nil && usernamePagers.count == 0 && classPagers.count == 0 && includedSetsPager == nil)
    }
    
    func updateDuplicates(pagerIndex pagerIndex: PagerIndex?) {
        do {
            var duplicates = Set<String>()
            for p in usernamePagers {
                if (p.creator == nil || p.creator!.isEmpty) {
                    continue
                }
                let dup = duplicates.contains(p.creator!)
                p.updateEnabled(!dup)
                if (!dup) {
                    duplicates.insert(p.creator!)
                }
            }
        }
        do {
            var duplicates = Set<String>()
            for p in classPagers {
                if (p.classId == nil || p.classId!.isEmpty) {
                    continue
                }
                let dup = duplicates.contains(p.classId!)
                p.updateEnabled(!dup)
                if (!dup) {
                    duplicates.insert(p.classId!)
                }
            }
        }
    }
    
    /* Use this slower generate() function for testing purposes if the more complex generate() function is suspected of causing problems.
    func generate() -> AnyGenerator<SetPager> {
        var index = 0
        var all = [SetPager]()
        if (queryPager != nil) {
            all.append(queryPager!)
        }
        all += usernamePagers
        all += classPagers
        if (includedSetsPager != nil) {
            all.append(includedSetsPager!)
        }
        return anyGenerator {
            return (index < all.count) ? all[index++] : nil
        }
    }
    */

    func generate() -> AnyGenerator<SetPager> {
        let index = PagerIndex()
        return anyGenerator {
            Restart:
                while (true) {
                    switch (index.type) {
                    case .Query:
                        index.advance()
                        if (self.queryPager == nil) {
                            continue Restart
                        }
                        return self.queryPager
                    case .Username:
                        if (index.index == self.usernamePagers.count) {
                            index.advance()
                            continue Restart
                        }
                        return self.usernamePagers[index.index++]
                    case .Class:
                        if (index.index == self.classPagers.count) {
                            index.advance()
                            continue Restart
                        }
                        return self.classPagers[index.index++]
                    case .IncludedSets:
                        index.advance()
                        if (self.includedSetsPager == nil) {
                            return nil
                        }
                        return self.includedSetsPager
                    case .End:
                        return nil
                    }
            }
        }
    }
    
    func loadComplete(pager: SetPager, affectedRows: Range<Int>?, totalResults: Int?, response: PagerResponse, completionHandler: (affectedRows: Range<Int>, totalResults: Int?, response: PagerResponse) -> Void) {
        self.updateTotals()
        
        var t = 0
        for p in self {
            if (p === pager) {
                break
            }
            t += (p.totalResults != nil) ? p.totalResults! : 0
        }
        if (t >= MaxTotalResults) {
            return
        }
        
        var r = (affectedRows!.startIndex + t)..<(affectedRows!.endIndex + t)
        if (r.startIndex >= MaxTotalResults) {
            return
        }
        r.endIndex = min(r.endIndex, MaxTotalResults)

        completionHandler(
            affectedRows: r,
            totalResults: self.totalResults,
            response: response)
    }
    
    func loadFirstPages(completionHandler completionHandler: (affectedRows: Range<Int>, totalResults: Int?, response: PagerResponse) -> Void) {
        for pager in self {
            pager.loadPage(1, completionHandler: { (affectedRows: Range<Int>?, totalResults: Int?, response: PagerResponse) -> Void in
                self.loadComplete(pager, affectedRows: affectedRows, totalResults: totalResults, response: response, completionHandler: completionHandler)
            })
        }
    }
    
    func isLoading() -> Bool {
        var index = 0
        for pager in self {
            if (pager.isLoading()) {
                return true
            }
            if let t = pager.totalResults {
                index += t
                if (index >= MaxTotalResults) {
                    break
                }
            }
        }
        return false
    }
    
    func peekQSetForRow(row: Int) -> QSet? {
        if (row >= MaxTotalResults) {
            return nil
        }

        var index = 0
        for pager in self {
            if let t = pager.totalResults {
                if case index..<index+t = row {
                    return pager.peekQSetForRow(row-index)
                }
                else {
                    index += t
                }
            }
        }
        return nil
    }
    
    func getQSetForRow(row: Int, completionHandler: (affectedResults: Range<Int>?, totalResults: Int?, response: PagerResponse) -> Void) -> QSet? {
        if (row >= MaxTotalResults) {
            return nil
        }

        var index = 0
        for pager in self {
            if let t = pager.totalResults {
                if case index..<index+t = row {
                    return pager.getQSetForRow(row-index, completionHandler: { (affectedRows: Range<Int>?, totalResults: Int?, response: PagerResponse) -> Void in
                        self.loadComplete(pager, affectedRows: affectedRows, totalResults: totalResults, response: response, completionHandler: completionHandler)
                    })
                }
                else {
                    index += t
                }
            }
        }
        return nil
    }
}
