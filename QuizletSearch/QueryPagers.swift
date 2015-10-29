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

class QueryPagers: QSetPager, SequenceType {
    let quizletSession = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel.quizletSession
    
    var queryPager: SetPager?
    var usernamePagers: [SetPager] = []
    var classPagers: [SetPager] = []
    var includedSetsPager: SetPager?
    // var excludedSets: [QSet] = []

    var totalResults: Int?
    
    // Do not allow the number of total results to shrink when doing search assist, because deleting rows is slow
    var isSearchAssist = false
    var totalResultsMax: Int?
    var totalResultRows: Int?
    
//    var paddingRowsMin: Int = 5 {
//        didSet {
//            if (paddingRowsMin > 0) {
//                totalResultRows = max(totalResultRows != nil ? totalResultRows! : 0, paddingRowsMin)
//            }
//        }
//    }
    
    func resetPadding() {
        isSearchAssist = false
        totalResultsMax = nil
        totalResultRows = totalResults
    }
    
    func updateTotals() {
        // totalResults - total number of results
        do {
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
            totalResults = (stillLoading && total == 0) ? nil : total
        }
        
        // totalResultRows - max of the total number of results that has been hit during a search assist session
        do {
            var total = totalResults
            if (isSearchAssist) {
                if (total != nil && totalResultsMax == nil) {
                    totalResultsMax = total
                }
                else if (total != nil && totalResultsMax != nil) {
                    totalResultsMax = max(total!, totalResultsMax!)
                    total = totalResultsMax!
                }
            }
            totalResultRows = total
//            totalResultRows = (paddingRowsMin > 0)
//                ? max(total != nil ? total! : 0, paddingRowsMin)
//                : total
        }
    }
    
    init() { }
    
    // MARK: - Query
    
    func executeSearch(pagerIndex: PagerIndex?, isSearchAssist: Bool, completionHandler: (affectedResults: Range<Int>?, totalResults: Int?, response: PagerResponse) -> Void) {
        
        // Cancel previous queries
        quizletSession.cancelQueryTasks()
        
        self.isSearchAssist = isSearchAssist
        if (!isSearchAssist) {
            totalResultsMax = nil
        }

        if (pagerIndex != nil && pagerIndex!.type == .Query) {
            changeQuery(isSearchAssist)
        }
        else {
            changeSearchAssist(isSearchAssist)
        }
        
//        updateDuplicates(pagerIndex: pagerIndex)
        
        if (isEmpty()) {
            self.updateTotals()
            completionHandler(affectedResults: nil, totalResults: nil, response: PagerResponse.Last)
        }
        else {
            loadFirstPages(completionHandler: completionHandler)
        }
    }
    
    func isEmpty() -> Bool {
        return (queryPager == nil && usernamePagers.count == 0 && classPagers.count == 0 && includedSetsPager == nil)
    }
    
    func changeQuery(isSearchAssist: Bool) {
        let query = queryPager?.query
        for pager in self {
            pager.changeQuery(query, isSearchAssist: isSearchAssist)
        }
    }
    
    func changeSearchAssist(isSearchAssist: Bool) {
        for pager in self {
            pager.changeSearchAssist(isSearchAssist)
        }
    }
    
    /*
    func updateDuplicates(pagerIndex pagerIndex: PagerIndex?) {
        markDuplicates(usernamePagers, type: .Username, pagerIndex: pagerIndex)
        markDuplicates(classPagers, type: .Class, pagerIndex: pagerIndex)
    }
    
    func markDuplicates(pagerList: [SetPager], type: PagerIndex.PagerType, pagerIndex: PagerIndex?) {
        var activePagers: [String: Int] = [:]
        for i in 0..<pagerList.count {
            let pager = pagerList[i]
            let id: String
            switch (type) {
            case .Username:
                id = pager.creator!
            case .Class:
                id = pager.classId!
            case .Query, .IncludedSets, .End:
                abort()
            }
            let activeIndex = activePagers[id]
            if (activeIndex == nil) {
                activePagers[id] = i
                pager.isDuplicate = false
            }
            else if (pagerIndex != nil && pagerIndex!.type == type && pagerIndex!.index == activeIndex!) {
                // Swap duplicates so that 'pagerIndex' is the one marked as a duplicate
                pagerList[activeIndex!].isDuplicate = true
                activePagers[id] = i
                pager.isDuplicate = false
            }
            else {
                pager.isDuplicate = true
            }
        }
    }
    */
    
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
                        if (index.index == self.usernamePagers.count /* || self.usernamePagers[index.index].isDuplicate */) {
                            index.advance()
                            continue Restart
                        }
                        return self.usernamePagers[index.index++]
                    case .Class:
                        if (index.index == self.classPagers.count /* || self.classPagers[index.index].isDuplicate */) {
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

        completionHandler(
            affectedRows: (affectedRows!.startIndex + t)...(affectedRows!.endIndex + t),
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
        for pager in self {
            if (pager.isLoading()) {
                return true
            }
        }
        return false
    }
    
    func peekQSetForRow(row: Int) -> QSet? {
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
    
    func isSearchAssistForRow(row: Int) -> Bool? {
        var index = 0
        for pager in self {
            if let t = pager.totalResults {
                if case index..<index+t = row {
                    return pager.isSearchAssist
                }
                else {
                    index += t
                }
            }
        }
        return nil
    }
}
