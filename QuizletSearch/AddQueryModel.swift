//
//  AddQueryModel.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/10/15.
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

fileprivate func <= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l <= r
  default:
    return !(rhs < lhs)
  }
}


enum QueryRowType: Int {
    case
    queryHeader, queryCell,
    userHeader, userCell,
    classHeader, classCell,
    includeHeader, includeCell,
    excludeHeader, excludeCell,
    resultHeader, resultCell
    
    static let Identifier = [
        "Query Header", "Query Cell",
        "User Header", "Text Input Cell",
        "Class Header", "Text Input Cell",
        "Include Header", "Label Cell",
        "Exclude Header", "Label Cell",
        "Result Header", "Result Cell"]
    
    func id() -> String {
        return QueryRowType.Identifier[rawValue]
    }
    
    func canEdit() -> Bool {
        switch (self) {
        case .userCell, .classCell, .includeCell, .excludeCell, .resultCell:
            return true
        default:
            return false
        }
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
    let sep = ","
    var type: String = ""
    var title: String = ""
    
    var pagers = QueryPagers()
    var includedSets = [String]()
    var excludedSets = [String]()
    
    var rowTypes: [[QueryRowType]] = [[],[]]
    var rowItems: [[String]] = [[],[]]
    
    // MARK: - Search
    
    func indexPathToPagerIndex(_ indexPath: IndexPath!) -> PagerIndex? {
        if (indexPath == nil) {
            return nil
        }
        
        if (resultRowForIndexPath(indexPath) != nil) {
            abort()
        }
        else {
            switch (rowTypes[indexPath.section][indexPath.row]) {
            case .queryCell:
                return PagerIndex(type: .query, index: 0)
            case .userCell:
                return PagerIndex(type: .username, index: indexPath.row - UsernameOffset)
            case .classCell:
                return PagerIndex(type: .class, index: indexPath.row - ClassOffset())
            case .includeCell:
                return PagerIndex(type: .includedSets, index: 0)
            case .excludeCell:
                abort()
            default:
                abort()
            }
        }
    }
    
    // MARK: - Table datasource
    
    func cellIdentifierForPath(_ indexPath: IndexPath) -> String {
        var cellIdentifier: String
        if let _ = resultRowForIndexPath(indexPath) {
//            if (isPaddingRow(resultRow)) {
//                cellIdentifier = "Empty Cell"
//            }
//            else {
//                // Use zero height cell for empty qsets.  We insert empty qsets if the Quitlet paging query returns fewer pages than expected (this happens occasionally).
//                let qset = pagers.peekQSetForRow(resultRow)
//                if (qset != nil && qset!.title.isEmpty && qset!.createdBy.isEmpty && qset!.description.isEmpty) {
//                    cellIdentifier = "Empty Cell"
//                }
//                else if (qset != nil && qset!.terms.count == 0) {
//                    cellIdentifier = "Search Assist Cell"
//                }
//                else {
//                    cellIdentifier = "Result Cell"
//                }
//            }
            cellIdentifier = "Result Cell"
        }
        else {
            cellIdentifier = rowTypes[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row].id()
        }
        return cellIdentifier
    }
    
    func rowTypeForPath(_ indexPath: IndexPath) -> QueryRowType {
        return rowTypes[indexPath.section][indexPath.row]
    }
    
    func rowItemForPath(_ indexPath: IndexPath) -> String {
        return rowItems[indexPath.section][indexPath.row]
    }
    
    func topmostPathForType(_ type: QueryRowType) -> IndexPath? {
        var indexPath: IndexPath? = nil

        switch (type) {
        case .resultHeader:
            indexPath = IndexPath(row: rowTypes[1].count - 1, section: ResultsSection)
        default:
            outerLoop:
            for s in 0..<rowTypes.count {
                for r in 0..<rowTypes[s].count {
                    if (rowTypes[s][r] == type) {
                        indexPath = IndexPath(row: r, section: s)
                        break outerLoop
                    }
                }
            }
        }
        
        return indexPath
    }
    
    func pathForResultHeader() -> IndexPath {
        return topmostPathForType(QueryRowType.resultHeader)!
    }
    
    func numberOfRowsInSection(_ section: Int) -> Int {
        var numRows = rowTypes[section].count
        if (section == ResultsSection) {
            if let t = pagers.totalResultsHighWaterMark {
                numRows += t
            }
//            else if (pagers!.isLoading()) {
//                // Activity Indicator row
//                numRows++                
//            }
        }
        return numRows
    }
    
    func numberOfResultRows() -> Int {
        var numRows = rowTypes[ResultsSection].count
        if let t = pagers.totalResults {
            numRows += t
        }
        return numRows
    }
    
    func canEditRowAtIndexPath(_ indexPath: IndexPath) -> Bool {
        if (resultRowForIndexPath(indexPath) != nil) {
            return true
        }
        else {
            return rowTypeForPath(indexPath).canEdit()
        }
    }
    
    func isHeaderAtPath(_ indexPath: IndexPath) -> Bool {
        return (cellIdentifierForPath(indexPath) as NSString).hasSuffix(" Header")
    }
    
    func resultRowForIndexPath(_ indexPath: IndexPath) -> Int? {
        return (indexPath.section == ResultsSection && indexPath.row >= rowTypes[indexPath.section].count)
            ? indexPath.row - rowTypes[indexPath.section].count
            : nil
    }

    func isActivityIndicatorRow(_ row: Int) -> Bool {
//        return totalResults == nil || row >= totalResults!
        return false
    }
    
    func isPaddingRow(_ row: Int) -> Bool {
        let t = pagers.totalResults
        return row > rowTypes[1].count + (t ?? 0)
    }

    // MARK: - Usernames (Creators)
    
    func insertNewUser(_ name: String) -> IndexPath {
        let insertIndex = 0
        let path = IndexPath(row: insertIndex + UsernameOffset, section: ResultsSection)
        insertAtIndexPath(path, type: .userCell, item: name)
        pagers.usernamePagers.insert(SetPager(query: pagers.queryPager?.query, creator: name), at: insertIndex)
        return path
    }
    
    func updateUser(_ name: String?, atIndexPath indexPath: IndexPath) {
        assert(indexPath.section == ResultsSection)
        let username = (name != nil) ? name! : ""
        
        let pager = pagers.usernamePagers[indexPath.row - UsernameOffset]
        pager.reset(query: pagers.queryPager?.query, creator: username)
        rowItems[indexPath.section][indexPath.row] = username
    }
    
    func updateAndSortUser(_ name: String?, atIndexPath indexPath: IndexPath) -> IndexPath {
        assert((indexPath as NSIndexPath).section == ResultsSection)
        let username = (name != nil) ? name! : ""
        
        let query = pagers.queryPager?.query
        let oldIndex = indexPath.row - UsernameOffset
        var newIndex = insertionSortIndexForUser(username, atIndex: oldIndex, list: pagers.usernamePagers)
        var newIndexPath: IndexPath

        if (oldIndex != newIndex) {
            let pager = pagers.usernamePagers.remove(at: oldIndex)
            rowItems[indexPath.section].remove(at: oldIndex + UsernameOffset)

            if (newIndex > oldIndex) {
                newIndex -= 1
            }

            pagers.usernamePagers.insert(pager, at: newIndex)
            rowItems[indexPath.section].insert(username, at: newIndex + UsernameOffset)

            newIndexPath = IndexPath(row: newIndex + UsernameOffset, section: indexPath.section)
        }
        else {
            pagers.usernamePagers[oldIndex].reset(query: query, creator: username)
            rowItems[indexPath.section][indexPath.row] = username
            newIndexPath = indexPath
        }
        
        return newIndexPath
    }
    
    func deleteUsernamePagerAtIndexPath(_ indexPath: IndexPath) {
        assert(indexPath.section == ResultsSection)
        pagers.usernamePagers.remove(at: indexPath.row - UsernameOffset)
    }
    
    let UsernameOffset = 1 // Subtract 1 for User Header
    
    func insertionSortIndexForUser(_ item: String, atIndex: Int, list: [SetPager]) -> Int {
        for i in 0..<list.count {
            if (i != atIndex && item <= list[i].creator) {
                return (item == list[i].creator) ? atIndex : i
            }
        }
        return list.count
    }
    
    // MARK: - Classes
    
    func insertNewClass(_ id: String) -> IndexPath {
        let insertIndex = 0
        let path = IndexPath(row: insertIndex + ClassOffset(), section: ResultsSection)
        insertAtIndexPath(path, type: .classCell, item: id)
        pagers.classPagers.insert(SetPager(query: pagers.queryPager?.query, classId: id), at: insertIndex)
        return path
    }
    
    func updateClass(_ name: String?, atIndexPath indexPath: IndexPath) {
        assert(indexPath.section == ResultsSection)
        let username = (name != nil) ? name! : ""
        
        let pager = pagers.classPagers[indexPath.row - ClassOffset()]
        pager.reset(query: pagers.queryPager?.query, classId: username)
        rowItems[indexPath.section][indexPath.row] = username
    }
    
    func updateAndSortClass(_ name: String?, atIndexPath indexPath: IndexPath) -> IndexPath {
        assert(indexPath.section == ResultsSection)
        let username = (name != nil) ? name! : ""
        
        let query = pagers.queryPager?.query
        
        let oldIndex = indexPath.row - ClassOffset()
        var newIndex = insertionSortIndexForClass(username, atIndex: oldIndex, list: pagers.classPagers)
        let newIndexPath: IndexPath
        
        if (oldIndex != newIndex) {
            let pager = pagers.classPagers.remove(at: oldIndex)
            rowItems[indexPath.section].remove(at: oldIndex + ClassOffset())
            
            if (newIndex > oldIndex) {
                newIndex -= 1
            }
            
            pagers.classPagers.insert(pager, at: newIndex)
            rowItems[indexPath.section].insert(username, at: newIndex + ClassOffset())
            
            newIndexPath = IndexPath(row: newIndex + ClassOffset(), section: indexPath.section)
        }
        else {
            pagers.classPagers[oldIndex].reset(query: query, classId: name)
            rowItems[indexPath.section][indexPath.row] = username
            
            newIndexPath = indexPath
        }
        return newIndexPath
    }
    
    func deleteClassPagerAtIndexPath(_ indexPath: IndexPath) {
        assert(indexPath.section == ResultsSection)
        pagers.classPagers.remove(at: indexPath.row - ClassOffset())
    }
    
    func ClassOffset() -> Int {
        return pagers.usernamePagers.count + 2
    }
    
    func insertionSortIndexForClass(_ item: String, atIndex: Int, list: [SetPager]) -> Int {
        for i in 0..<list.count {
            if (i != atIndex && item <= list[i].classId) {
                return (item == list[i].classId) ? atIndex : i
            }
        }
        return list.count
    }
    
    // MARK: - Row types and items
    
    func insertAtIndexPath(_ path: IndexPath, type: QueryRowType, item: String) {
        rowTypes[path.section].insert(type, at: path.row)
        rowItems[path.section].insert(item, at: path.row)
    }
    
    func deleteAtIndexPath(_ path: IndexPath) {
        rowTypes[path.section].remove(at: path.row)
        rowItems[path.section].remove(at: path.row)
    }
    
    func reloadData() {
        let Q = QuerySection
        let R = ResultsSection
        
        rowTypes = [[],[]]
        rowItems = [[],[]]
        
        add(Q, .queryHeader)
        // add(Q, .QueryCell)

        add(R, .userHeader)
        for pager in pagers.usernamePagers {
            add(R, .userCell, pager.creator!)
        }
        
        add(R, .classHeader)
        for pager in pagers.classPagers {
            add(R, .classCell, pager.classId!)
        }
        
        if (includedSets.count > 0) {
            add(R, .includeHeader)
            for set in includedSets {
                add(R, .includeCell, set)
            }
        }

        if (excludedSets.count > 0) {
            add(R, .excludeHeader)
            for set in excludedSets {
                add(R, .excludeCell, set)
            }
        }
        
        add(R, .resultHeader)
    }
    
    func add(_ section: Int, _ type: QueryRowType, _ rowItem: String = "") {
        rowTypes[section].append(type)
        rowItems[section].append(rowItem)
    }
    
    // MARK: - Load and Save
    
    func loadFromQuery(_ q: Query!) {
        if (q == nil) {
            // Initial UI values are ok for a new query, so no need to load an empty query
            return
        }
        
        type = q.type
        title = q.title
        
        pagers.loadFromQuery(q)
    }
    
    func saveToQuery(_ q: Query) -> Bool {
        var modified = false
        if (q.type != type) {
            modified = true
            q.type = type
        }
        if (q.title != title) {
            modified = true
            q.title = title
        }
        
        if (pagers.saveToQuery(q)) {
            modified = true
        }

        let includedIds = includedSets.joined(separator: sep)
        if (q.includedSets != includedIds) {
            modified = true
            q.includedSets = includedIds
        }
        
        let excludedIds = excludedSets.joined(separator: sep)
        if (q.excludedSets != excludedIds) {
            modified = true
            q.excludedSets = excludedIds
        }
        
        // @NSManaged var user: User
        // @NSManaged var sets: NSSet
        
        return modified
    }
}
