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
    
    init() { }
    
    // MARK: - Query
    
    func executeSearch(pagerIndex: PagerIndex?, isSearchAssist: Bool, completionHandler: (pageLoaded: Int?, response: PagerResponse) -> Void) {
        
        // Cancel previous queries
        quizletSession.cancelQueryTasks()

        if (pagerIndex != nil && pagerIndex!.type == .Query) {
            changeQuery(isSearchAssist)
        }
        else {
            changeSearchAssist(isSearchAssist)
        }
        
//        updateDuplicates(pagerIndex: pagerIndex)
        
        if (isEmpty()) {
            completionHandler(pageLoaded: nil, response: PagerResponse.Last)
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
    
    func loadFirstPages(completionHandler completionHandler: (pageLoaded: Int?, response: PagerResponse) -> Void) {
        for pager in self {
            // if (!pager.firstPageActive()) {
                pager.loadPage(1, completionHandler: completionHandler)
            // }
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
    
    func getQSetForRow(row: Int, completionHandler: (pageLoaded: Int?, response: PagerResponse) -> Void) -> QSet? {
        var index = 0
        for pager in self {
            if let t = pager.totalResults {
                if case index..<index+t = row {
                    return pager.getQSetForRow(row-index, completionHandler: completionHandler)
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
    
    var totalResults: Int? {
        var totalResults = 0
        var stillLoadingTotals = false
        for pager in self {
            if let t = pager.totalResults {
                totalResults += t
            }
            else {
                stillLoadingTotals = true
            }
        }
        
        return (stillLoadingTotals && totalResults == 0) ? nil : totalResults
    }
}
