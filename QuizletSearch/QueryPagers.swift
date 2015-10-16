//
//  QueryPagers.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/16/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import Foundation

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
}

class QueryPagers: QSetPager {
    var query: SetPager?
    
    var usernames: [SetPager] = []
    var classes: [SetPager] = []
    var includedSets: SetPager?
    // var excludedSets: [QSet] = []
    
    var allPagers = [SetPager]()
    
    init(queryInfo q: QueryInfo) {
        if (q.usernames.count > 0) {
            for username in q.usernames {
                usernames.append(SetPager(query: q.query, creator: username, isSearchAssist: q.isSearchAssist))
            }
        }
        else {
            query = SetPager(query: q.query, creator: nil, isSearchAssist:  q.isSearchAssist)
        }
        
        if (q.classes.count > 0) {
            classes = []
            for classId in q.classes {
                // TODO: append class query pager
                // classes!.append()
            }
        }
        
        // TODO: create query for all the ids of the included sets'
        
        resetAllPagers()
    }
    
    func update(queryInfo q: QueryInfo) {
        if (q.usernames.count > 0) {
            for i in 0..<q.usernames.count {
                if (i < usernames.count) {
                    usernames[i].resetQuery(query: q.query, creator: q.usernames[i], isSearchAssist: q.isSearchAssist)
                }
                else {
                    usernames.append(SetPager(query: q.query, creator: q.usernames[i], isSearchAssist: q.isSearchAssist))
                }
            }
            
            query = nil
            if (usernames.count > q.usernames.count) {
                usernames.removeRange(q.usernames.count ..< usernames.count)
            }
        }
        else {
            if (query != nil) {
                query?.resetQuery(query: q.query, creator: nil, isSearchAssist: q.isSearchAssist)
            }
            else {
                query = SetPager(query: q.query, creator: nil, isSearchAssist: q.isSearchAssist)
            }
        }
        
        if (q.classes.count > 0) {
            for i in 0..<q.classes.count {
                // TODO: create or reset class query pager
                if (i < classes.count) {
                    // classes[i].resetQuery(q.classes[i])
                }
                else {
                    // classes[i].append(SetPager())
                }
            }
            
            if (classes.count > q.usernames.count) {
                classes.removeRange(q.classes.count ..< classes.count)
            }
        }
        
        if (q.includedSets.count > 0) {
            // TODO: create or reset query for all the ids of the included sets
            if (includedSets != nil) {
                // includedSets?.resetQuery()
            }
            else {
                // includedSets = SetPager()
            }
        }
        
        resetAllPagers()
    }
    
    func resetAllPagers() {
        var all = [SetPager]()
        if (query != nil) {
            all.append(query!)
        }
        all += usernames
        all += classes
        if (includedSets != nil) {
            all.append(includedSets!)
        }
        allPagers = all
    }
    
    func loadFirstPages(completionHandler completionHandler: (pageLoaded: Int?, response: PagerResponse) -> Void) {
        for pager in allPagers {
            pager.loadPage(1, completionHandler: completionHandler)
        }
    }
    
    func isLoading() -> Bool {
        for pager in allPagers {
            if (pager.isLoading()) {
                return true
            }
        }
        return false
    }
    
    func peekQSetForRow(row: Int) -> QSet? {
        var index = 0
        for pager in allPagers {
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
        for pager in allPagers {
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
    
    var totalResults: Int? {
        var totalResults = 0
        var stillLoadingTotals = false
        for pager in allPagers {
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
