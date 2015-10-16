//
//  AddQueryModel.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/10/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

enum QueryRowType: Int {
    case
    QueryHeader, QueryCell,
    UserHeader, UserCell,
    ClassHeader, ClassCell,
    IncludeHeader, IncludeCell,
    ExcludeHeader, ExcludeCell,
    ResultHeader, ResultCell
    
    static let Identifier = [
        "Query Header", "Query Cell",
        "User Header", "Text Input Cell",
        "Class Header", "Text Input Cell",
        "Include Header", "Include Cell",
        "Exclude Header", "Exclude Cell",
        "Result Header", "Result Cell"]
    
    func id() -> String {
        return QueryRowType.Identifier[rawValue]
    }
}

// TODO: Quizlet classes
//func ==(lhs: QuizletClass, rhs: QuizletClass) -> Bool {
//    return lhs.id == rhs.id && lhs.title == rhs.title
//}
//
//class QuizletClass: Equatable {
//    let id: String
//    let title: String
//    
//    init(id: String, title: String) {
//        self.id = id
//        self.title = title
//    }
//    
//    convenience init() {
//        self.init(id: "", title: "")
//    }
//}

class AddQueryModel {
    let quizletSession = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel.quizletSession
    
    let QueryLabelSection = 0
    let ResultsSection = 1
    
    let sep = ","
    var type: String = ""
    var title: String = ""
    
    var query = QueryInfo()
    var pagers: QueryPagers?
    var mostRecentQuery: QueryInfo?
    var totalResults: Int? {
        return pagers?.totalResults
    }
    
    var rowTypes: [[QueryRowType]] = [[],[]]
    var rowItems: [[String]] = [[],[]]

    func executeQuery(completionHandler completionHandler: (pageLoaded: Int?, response: PagerResponse) -> Void) {
        if (mostRecentQuery == query) {
            return
        }
        mostRecentQuery = QueryInfo(qinfo: query)
        
        // Cancel previous queries
        quizletSession.cancelQueryTasks()
        
        if (query.isEmpty()) {
            pagers = nil
            completionHandler(pageLoaded: nil, response: PagerResponse.Last)
            return
        }
        
        if (pagers != nil) {
            pagers!.update(queryInfo: query)
        }
        else {
            pagers = QueryPagers(queryInfo: query)
        }
        pagers!.loadFirstPages(completionHandler: completionHandler)
    }
    
    func cellIdentifierForPath(indexPath: NSIndexPath) -> String {
        var cellIdentifier: String
        if let resultRow = resultRowForIndexPath(indexPath) {
            if (isActivityIndicatorRow(resultRow)) {
                cellIdentifier = "Activity Cell"
            }
            else {
                // Use zero height cell for empty qsets.  We insert empty qsets if the Quitlet paging query returns fewer pages than expected (this happens occasionally).
                let qset = pagers?.peekQSetForRow(resultRow)
                if (qset != nil && qset!.title.isEmpty && qset!.createdBy.isEmpty && qset!.description.isEmpty) {
                    cellIdentifier = "Empty Cell"
                }
                else if (query.isSearchAssist) {
                    cellIdentifier = "Search Assist Cell"
                }
                else {
                    cellIdentifier = "Result Cell"
                }
            }
        }
        else {
            cellIdentifier = rowTypes[indexPath.section][indexPath.row].id()
        }
        return cellIdentifier
    }
    
    func rowItemForPath(indexPath: NSIndexPath) -> String {
        return rowItems[indexPath.section][indexPath.row]
    }
    
    func resultHeaderPath() -> NSIndexPath {
        return NSIndexPath(forRow: rowTypes[1].count - 1, inSection: 1)
    }
    
    func numberOfRowsInSection(section: Int) -> Int {
        var numRows = rowTypes[section].count
        if (section == ResultsSection && pagers != nil) {
            if let t = pagers?.totalResults {
                numRows += t
            }
            else if (pagers!.isLoading()) {
                // Activity Indicator row
                numRows++                
            }
        }
        return numRows
    }
    
    func isHeaderAtPath(indexPath: NSIndexPath) -> Bool {
        return (cellIdentifierForPath(indexPath) as NSString).hasSuffix(" Header")
    }
    
    func resultRowForIndexPath(indexPath: NSIndexPath) -> Int? {
        return (indexPath.section == ResultsSection && indexPath.row >= rowTypes[indexPath.section].count)
            ? indexPath.row - rowTypes[indexPath.section].count
            : nil
    }

    func isActivityIndicatorRow(row: Int) -> Bool {
        return totalResults == nil || row >= totalResults!
    }
    
    func appendUser(name: String) -> NSIndexPath {
        query.usernames.append(name)

        let path = NSIndexPath(forRow: query.usernames.count, inSection: 1)
        insertAtPath(path, type: .UserCell, item: name)
        return path
    }
    
    func appendClass(id: String) -> NSIndexPath {
        query.classes.append(id)

        let path = NSIndexPath(forRow: query.usernames.count + query.classes.count + 1, inSection: 1)
        insertAtPath(path, type: .ClassCell, item: id)
        return path
    }
    
    func insertAtPath(path: NSIndexPath, type: QueryRowType, item: String) {
        rowTypes[path.section].insert(type, atIndex: path.row)
        rowItems[path.section].insert(item, atIndex: path.row)
    }
    
    func reloadData() {
        let Q = 0
        let R = 1
        
        rowTypes = [[],[]]
        rowItems = [[],[]]
        
        add(Q, .QueryHeader)
        // add(Q, .QueryCell)

        add(R, .UserHeader)
        for name in query.usernames {
            add(R, .UserCell, name)
        }
        
        add(R, .ClassHeader)
        for id in query.classes {
            add(R, .ClassCell, id)
        }
        
        if (query.includedSets.count > 0) {
            add(R, .IncludeHeader)
            for set in query.includedSets {
                add(R, .IncludeCell, set)
            }
        }

        if (query.excludedSets.count > 0) {
            add(R, .ExcludeHeader)
            for set in query.excludedSets {
                add(R, .ExcludeCell, set)
            }
        }
        
        add(R, .ResultHeader)
    }
    
    func add(section: Int, _ type: QueryRowType, _ rowItem: String = "") {
        rowTypes[section].append(type)
        rowItems[section].append(rowItem)
    }
    
    func loadFromDataModel(q: Query) {
        type = q.type
        title = q.title
        query.query = q.query

        query.usernames = q.creators.characters.split{$0 == ","}.map(String.init)
        
        var classIds = (q.classes as NSString).componentsSeparatedByString(sep)
        // TODO: load QuizletClasses using the Quizlet API
        
        var includedIds = (q.includedSets as NSString).componentsSeparatedByString(sep)
        var excludedIds = (q.excludedSets as NSString).componentsSeparatedByString(sep)
        // TODO: load QuizletSets for the included and excluded ids using the Quizlet API
    }
    
    func saveToDataModel(q: Query) {
        if (q.type != type) {
            q.type = type
        }
        if (q.title != title) {
            q.title = title
        }
        if (q.query != query.query) {
            q.query = query.query
        }
        
        let creators = query.usernames.joinWithSeparator(sep)
        if (q.creators != creators) {
            q.creators = creators
        }
        
        var ids = [String]()
        for cls in query.classes {
            ids.append(cls)
        }
        let classIds = ids.joinWithSeparator(sep)
        if (q.classes != classIds) {
            q.classes = classIds
        }
        
        ids = []
        for set in query.includedSets {
            ids.append(set)
        }
        let includedIds = ids.joinWithSeparator(sep)
        if (q.includedSets != includedIds) {
            q.includedSets = includedIds
        }
        
        ids = []
        for set in query.excludedSets {
            ids.append(set)
        }
        let excludedIds = ids.joinWithSeparator(sep)
        if (q.excludedSets != excludedIds) {
            q.excludedSets = excludedIds
        }
        
        // @NSManaged var user: User
        // @NSManaged var sets: NSSet
    }
}
