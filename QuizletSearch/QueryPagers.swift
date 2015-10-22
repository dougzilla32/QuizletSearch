//
//  QueryPagers.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/16/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

/*
func ==(lhs: QueryInfo, rhs: QueryInfo) -> Bool {
    return lhs.query == rhs.query
        && lhs.isSearchAssist == rhs.isSearchAssist
        && lhs.usernames == rhs.usernames
        && lhs.classes == rhs.classes
        && lhs.includedSets == rhs.includedSets
        && lhs.excludedSets == rhs.excludedSets
}

class QueryInfo: Equatable {
    var query: String = ""
    var isSearchAssist = false
    
    var usernames: [String] = []
    var classes: [String] = []
    var includedSets: [String] = []
    var excludedSets: [String] = []
    
    init() { }
    
    init(qinfo: QueryInfo) {
        self.query = qinfo.query
        self.isSearchAssist = qinfo.isSearchAssist
        self.usernames = qinfo.usernames
        self.classes = qinfo.classes
        self.includedSets = qinfo.includedSets
        self.excludedSets = qinfo.excludedSets
    }
    
    func isEmpty() -> Bool {
        return (query.isEmpty && usernames.count == 0 && classes.count == 0 && includedSets.count == 0)
    }
    
    func uniqueInfo() -> QueryInfo {
        let uniqueInfo = QueryInfo()
        uniqueInfo.usernames = makeUnique(usernames)
        uniqueInfo.classes = makeUnique(classes)
        uniqueInfo.includedSets = makeUnique(includedSets)
        uniqueInfo.excludedSets = makeUnique(excludedSets)
        return uniqueInfo
    }
    
    func makeUnique(list: [String]) -> [String] {
        var set = Set<String>()
        var uniqueList = [String]()
        for item in list {
            if (!set.contains(item)) {
                uniqueList.append(item)
                set.insert(item)
            }
        }
        return uniqueList
    }
}

struct AllPagers : SequenceType
{
    let pagers: QueryPagers
    
    init(pagers: QueryPagers)
    {
        self.pagers = pagers
    }

}
*/

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
//    var isSearchAssist = false
    
    var usernamePagers: [SetPager] = []
    var classPagers: [SetPager] = []
    var includedSetsPager: SetPager?
    // var excludedSets: [QSet] = []
    
    init() { }
    
    // MARK: - Query
    
    func executeSearch(pagerIndex: PagerIndex?, isSearchAssist: Bool, completionHandler: (pageLoaded: Int?, response: PagerResponse) -> Void) {
        
        // Cancel previous queries
        quizletSession.cancelQueryTasks()

//        self.isSearchAssist = isSearchAssist
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
    
    /*
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
    
    /*
    init(queryInfo: QueryInfo) {
        let q = queryInfo.uniqueInfo()
        
        if (q.usernames.count > 0) {
            for username in q.usernames {
                usernamePagers.append(SetPager(query: q.query, creator: username, isSearchAssist: q.isSearchAssist))
            }
        }
        else {
            queryPager = SetPager(query: q.query, creator: nil, isSearchAssist:  q.isSearchAssist)
        }
        
        if (q.classes.count > 0) {
            classPagers = []
            for classId in q.classes {
                // TODO: append class query pager
                // classPagers!.append()
            }
        }
        
        // TODO: create query for all the ids of the included sets'
        
        resetAllPagers()
    }
    
    func update(queryInfo queryInfo: QueryInfo) {
        let q = queryInfo.uniqueInfo()
        
        for i in 0..<q.usernames.count {
            if (i < usernamePagers.count) {
                usernamePagers[i].resetQuery(query: q.query, creator: q.usernames[i], isSearchAssist: q.isSearchAssist)
            }
            else {
                usernamePagers.append(SetPager(query: q.query, creator: q.usernames[i], isSearchAssist: q.isSearchAssist))
            }
        }
        if (usernamePagers.count > q.usernames.count) {
            usernamePagers.removeRange(q.usernames.count ..< usernamePagers.count)
        }
        
        if (usernamePagers.count > 0) {
            queryPager = nil
        }
        else {
            if (queryPager != nil) {
                queryPager?.resetQuery(query: q.query, creator: nil, isSearchAssist: q.isSearchAssist)
            }
            else {
                queryPager = SetPager(query: q.query, creator: nil, isSearchAssist: q.isSearchAssist)
            }
        }
        
        if (q.classes.count > 0) {
            for i in 0..<q.classes.count {
                // TODO: create or reset class query pager
                if (i < classPagers.count) {
                    // classes[i].resetQuery(q.classes[i])
                }
                else {
                    // classes[i].append(SetPager())
                }
            }
            
            if (classPagers.count > q.classes.count) {
                classPagers.removeRange(q.classes.count ..< classPagers.count)
            }
        }
        
        if (q.includedSets.count > 0) {
            // TODO: create or reset query for all the ids of the included sets
            if (includedSetsPager != nil) {
                // includedSetsPager?.resetQuery()
            }
            else {
                // includedSetsPager = SetPager()
            }
        }
        
        resetAllPagers()
    }

    func resetAllPagers() {
        var all = [SetPager]()
        if (queryPager != nil) {
            all.append(queryPager!)
        }
        all += usernamePagers
        all += classPagers
        if (includedSetsPager != nil) {
            all.append(includedSetsPager!)
        }
        allPagers = all
    }
    */
    
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
