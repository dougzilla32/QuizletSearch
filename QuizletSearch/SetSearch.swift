//
//  SetSearch.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/16/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}


class SetSearchIndex {
    enum PagerType {
        case query, username, `class`, includedSets, end
    }
    
    var type = PagerType.query
    var index = 0
    
    init() { }
    
    init(type: PagerType, index: Int) {
        self.type = type
        self.index = index
    }
    
    func advance() {
        switch (type) {
        case .query:
            type = .username
        case .username:
            type = .class
        case .class:
            type = .includedSets
        case .includedSets:
            type = .end
        default:
            type = .end
        }
        index = 0
    }
}

class SetSearch: Sequence {
    let MaxTermCount = 5000
    let MaxCharacters = 1000000
    
    let sep = ","
    let MinTotalResultsHighWaterMark = 10
    let MaxTotalResults = 300
    
    let quizletSession = (UIApplication.shared.delegate as! AppDelegate).dataModel.quizletSession
    
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
        totalResults = (stillLoading && total == 0) ? nil : Swift.min(total, MaxTotalResults)
        totalResultsNoMax = (stillLoading && total == 0) ? nil : total
        totalResultsHighWaterMark = Swift.max(totalResults ?? 0, totalResultsHighWaterMark ?? 0, MinTotalResultsHighWaterMark)
    }
    
    init() {
        SetPager.firstChanceUsers.removeAll()
        SetPager.secondChanceUsers.removeAll()
    }
    
    convenience init(query: Query) {
        self.init()
        
        loadFromQuery(query)
    }
    
    func loadFromQuery(_ q: Query) {
        queryPager = q.query.isEmpty ? nil : SetPager(query: q.query)
        
        // With Swift string: let usernames = q.creators.characters.split{$0 == ","}.map(String.init)
        // Using NSString for now because Swift strings are slow
        if (!q.creators.isEmpty) {
            queryPager?.enabled = false
            
            let usernames = (q.creators as NSString).components(separatedBy: sep)
            usernamePagers.removeAll()
            for name in usernames {
                usernamePagers.append(SetPager(query: q.query, creator: name))
            }
        }
        
        if (!q.classes.isEmpty) {
            let classIds = (q.classes as NSString).components(separatedBy: sep)
            classPagers.removeAll()
            for id in classIds {
                classPagers.append(SetPager(query: q.query, classId: id))
            }
        }
        
        // includedSetsPager = SetPager(includedSets: (q.includedSets as NSString).componentsSeparatedByString(sep))
        // excludedSets = (q.excludedSets as NSString).componentsSeparatedByString(sep)
    }
    
    // TODO: FIX ME -- not working correctly with "query=hi" and "username=dougzilla32", runs the "hi" query separately
    // Also, before fixing test that the MaxTermLimit is working correctly
    func saveToQuery(_ q: Query) -> Bool {
        var modified = false
        let query = (queryPager?.query != nil) ? queryPager!.query! : ""
        if (q.query != query) {
            modified = true
            q.query = query
        }
        
        var usernames = [String]()
        for pager in usernamePagers {
            usernames.append(pager.creator!)
        }
        usernames.sort()
        
        let creators = usernames.joined(separator: sep)
        if (q.creators != creators) {
            modified = true
            q.creators = creators
        }
        
        var ids = [String]()
        for pager in classPagers {
            ids.append(pager.classId!)
        }
        ids.sort()
        
        let classIds = ids.joined(separator: sep)
        if (q.classes != classIds) {
            modified = true
            q.classes = classIds
        }
        
        return modified
    }
    
    // MARK: - Query
    
    func executeFullSearch(completionHandler: @escaping ([QSet]?, Int) -> Void) {
        trace("executeFullSearch START")
        
        // Cancel previous queries
        quizletSession.cancelQueryTasks()
        
        updateQuery()
        
        let generator = makeIterator()
        let qsets = [QSet]()
        loadNextPage(currentPager: generator.next(), currentPageNumber: 1, generator: generator, qsets: qsets, termCount: 0, completionHandler: completionHandler)
    }
    
    func loadNextPage(currentPager currentPagerParam: SetPager!, currentPageNumber currentPageNumberParam: Int, generator: AnyIterator<SetPager>, qsets qsetsParam: [QSet], termCount termCountParam: Int, completionHandler: @escaping ([QSet]?, Int) -> Void) {

        var currentPager: SetPager! = currentPagerParam
        var currentPageNumber = currentPageNumberParam
        var qsets = qsetsParam
        var termCount = termCountParam
        
        if (currentPager == nil) {
            trace("executeFullSearch COMPLETE qsets.count:", qsets.count, "termCount:", termCount)
            completionHandler(qsets, termCount)
            return
        }
        
        if (!currentPager.enabled) {
            self.loadNextPage(currentPager: generator.next(), currentPageNumber: 1, generator: generator, qsets: qsets, termCount: termCount, completionHandler: completionHandler)
            return
        }
        
        trace("loadNextPage",
            "query:", currentPager.query ?? "nil",
            "creator:", currentPager.creator ?? "nil",
            "classId:", currentPager.classId ?? "nil")
        
        currentPager.pagerPause = Int64(NSEC_PER_SEC/10000)
        
        currentPager.loadPage(currentPageNumber, completionHandler: { (affectedRows: CountableRange<Int>?, totalResults: Int?, response: PagerResponse) -> Void in
            
            if (response != .complete) {
                return
            }
            
            let newQSets = currentPager.items?[currentPageNumber-1]
            currentPager.items?[currentPageNumber-1] = nil
            
            if (newQSets != nil) {
                for s in newQSets! {
                    if (termCount + s.terms.count > self.MaxTermCount) {
                        trace("executeFullSearch MAXED qsets.count:", qsets.count, "termCount:", termCount, "MaxTermCount:", self.MaxTermCount)
                        completionHandler(qsets, termCount)
                        return
                    }
                    qsets.append(s)
                    termCount += s.terms.count
                }
            }
            
            if (newQSets == nil || currentPageNumber >= currentPager.totalPages) {
                currentPager = generator.next()
                currentPageNumber = 1
            }
            else {
                currentPageNumber += 1
            }
            
            self.loadNextPage(currentPager: currentPager, currentPageNumber: currentPageNumber, generator: generator, qsets: qsets, termCount: termCount, completionHandler: completionHandler)
        })
    }
    
    func executeSearch(_ pagerIndex: SetSearchIndex?, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        
        // Cancel previous queries
        quizletSession.cancelQueryTasks()
        
        updateQuery()
        
        updateDuplicates(pagerIndex: pagerIndex)
        
        if (isEmpty()) {
            self.updateTotals()
            completionHandler(nil, totalResults, PagerResponse.complete)
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
    
    func updateDuplicates(pagerIndex: SetSearchIndex?) {
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

    func makeIterator() -> AnyIterator<SetPager> {
        let index = SetSearchIndex()
        return AnyIterator {
            Restart:
                while (true) {
                    switch (index.type) {
                    case .query:
                        index.advance()
                        if (self.queryPager == nil) {
                            continue Restart
                        }
                        return self.queryPager
                    case .username:
                        if (index.index == self.usernamePagers.count) {
                            index.advance()
                            continue Restart
                        }
                        let pager = self.usernamePagers[index.index]
                        index.index += 1
                        return pager
                    case .class:
                        if (index.index == self.classPagers.count) {
                            index.advance()
                            continue Restart
                        }
                        let pager = self.classPagers[index.index]
                        index.index += 1
                        return pager
                    case .includedSets:
                        index.advance()
                        if (self.includedSetsPager == nil) {
                            return nil
                        }
                        return self.includedSetsPager
                    case .end:
                        return nil
                    }
            }
        }
    }
    
    func loadComplete(_ pager: SetPager, affectedRows: CountableRange<Int>?, totalResults: Int?, response: PagerResponse, completionHandler: (_ affectedRows: CountableRange<Int>, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        self.updateTotals()
        
        var t = 0
        for p in self {
            if (p === pager) {
                break
            }
            t += p.totalResults ?? 0
        }
        if (t >= MaxTotalResults) {
            return
        }
        
        var r: CountableRange = (affectedRows!.lowerBound + t)..<(affectedRows!.upperBound + t)
        if (r.lowerBound >= MaxTotalResults) {
            return
        }
        r = r.clamped(to: 0..<Swift.min(r.upperBound, MaxTotalResults))

        completionHandler(
            r,
            self.totalResults,
            response)
    }
    
    func loadFirstPages(completionHandler: @escaping (_ affectedRows: CountableRange<Int>, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        for pager in self {
            pager.pagerPause = PagerConstants.DefaultPagerPause
            
            pager.loadPage(1, completionHandler: { (affectedRows: CountableRange<Int>?, totalResults: Int?, response: PagerResponse) -> Void in
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
    
    func peekQSetForRow(_ row: Int) -> QSet? {
        if (row >= MaxTotalResults) {
            return nil
        }

        var index = 0
        for pager in self {
            if let t = pager.totalResults {
                if case index..<index+t = row {
                    return pager.peekItemForRow(row-index)
                }
                else {
                    index += t
                }
            }
        }
        return nil
    }
    
    func getQSetForRow(_ row: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) -> QSet? {
        if (row >= MaxTotalResults) {
            return nil
        }

        var index = 0
        for pager in self {
            if let t = pager.totalResults {
                if case index..<index+t = row {
                    return pager.getItemForRow(row-index, completionHandler: { (affectedRows: CountableRange<Int>?, totalResults: Int?, response: PagerResponse) -> Void in
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
