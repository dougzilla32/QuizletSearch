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
        "Include Header", "Label Cell",
        "Exclude Header", "Label Cell",
        "Result Header", "Result Cell"]
    
    func id() -> String {
        return QueryRowType.Identifier[rawValue]
    }
    
    func canEdit() -> Bool {
        switch (self) {
        case .UserCell, .ClassCell, .IncludeCell, .ExcludeCell, .ResultCell:
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
    
    init(/* queryData: Query */) {
        // loadFromDataModel(queryData)
    }
    
    // MARK: - Search
    
    func indexPathToPagerIndex(indexPath: NSIndexPath!) -> PagerIndex? {
        if (indexPath == nil) {
            return nil
        }
        
        if (resultRowForIndexPath(indexPath) != nil) {
            abort()
        }
        else {
            switch (rowTypes[indexPath.section][indexPath.row]) {
            case .QueryCell:
                return PagerIndex(type: .Query, index: 0)
            case .UserCell:
                return PagerIndex(type: .Username, index: indexPath.row - UsernameOffset)
            case .ClassCell:
                return PagerIndex(type: .Class, index: indexPath.row - ClassOffset())
            case .IncludeCell:
                return PagerIndex(type: .IncludedSets, index: 0)
            case .ExcludeCell:
                abort()
            default:
                abort()
            }
        }
    }
    
    // MARK: - Table datasource
    
    func cellIdentifierForPath(indexPath: NSIndexPath) -> String {
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
            cellIdentifier = rowTypes[indexPath.section][indexPath.row].id()
        }
        return cellIdentifier
    }
    
    func rowTypeForPath(indexPath: NSIndexPath) -> QueryRowType {
        return rowTypes[indexPath.section][indexPath.row]
    }
    
    func rowItemForPath(indexPath: NSIndexPath) -> String {
        return rowItems[indexPath.section][indexPath.row]
    }
    
    func topmostPathForType(type: QueryRowType) -> NSIndexPath? {
        var indexPath: NSIndexPath? = nil

        switch (type) {
        case .ResultHeader:
            indexPath = NSIndexPath(forRow: rowTypes[1].count - 1, inSection: ResultsSection)
        default:
            outerLoop:
            for s in 0..<rowTypes.count {
                for r in 0..<rowTypes[s].count {
                    if (rowTypes[s][r] == type) {
                        indexPath = NSIndexPath(forRow: r, inSection: s)
                        break outerLoop
                    }
                }
            }
        }
        
        return indexPath
    }
    
    func pathForResultHeader() -> NSIndexPath {
        return topmostPathForType(QueryRowType.ResultHeader)!
    }
    
    func numberOfRowsInSection(section: Int) -> Int {
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
    
    func canEditRowAtIndexPath(indexPath: NSIndexPath) -> Bool {
        if (resultRowForIndexPath(indexPath) != nil) {
            return true
        }
        else {
            return rowTypeForPath(indexPath).canEdit()
        }
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
//        return totalResults == nil || row >= totalResults!
        return false
    }
    
    func isPaddingRow(row: Int) -> Bool {
        let t = pagers.totalResults
        return row > rowTypes[1].count + (t != nil ? t! : 0)
    }

    // MARK: - Usernames (Creators)
    
    func insertNewUser(name: String) -> NSIndexPath {
        let insertIndex = 0
        let path = NSIndexPath(forRow: insertIndex + UsernameOffset, inSection: ResultsSection)
        insertAtIndexPath(path, type: .UserCell, item: name)
        pagers.usernamePagers.insert(SetPager(query: pagers.queryPager?.query, creator: name), atIndex: insertIndex)
        return path
    }
    
    func updateUser(var name: String!, atIndexPath indexPath: NSIndexPath) {
        assert(indexPath.section == ResultsSection)
        if (name == nil) {
            name = ""
        }

        let pager = pagers.usernamePagers[indexPath.row - UsernameOffset]
        pager.reset(query: pagers.queryPager?.query, creator: name)
        rowItems[indexPath.section][indexPath.row] = name
    }
    
    func updateAndSortUser(var name: String!, var atIndexPath indexPath: NSIndexPath) -> NSIndexPath {
        assert(indexPath.section == ResultsSection)
        if (name == nil) {
            name = ""
        }
        
        let query = pagers.queryPager?.query
        
        let oldIndex = indexPath.row - UsernameOffset
        var newIndex = insertionSortIndexForUser(name, atIndex: oldIndex, list: pagers.usernamePagers)
        if (oldIndex != newIndex) {
            let pager = pagers.usernamePagers.removeAtIndex(oldIndex)
            rowItems[indexPath.section].removeAtIndex(oldIndex + UsernameOffset)

            if (newIndex > oldIndex) {
                newIndex--
            }

            pagers.usernamePagers.insert(pager, atIndex: newIndex)
            rowItems[indexPath.section].insert(name, atIndex: newIndex + UsernameOffset)

            indexPath = NSIndexPath(forRow: newIndex + UsernameOffset, inSection: indexPath.section)
        }
        else {
            pagers.usernamePagers[oldIndex].reset(query: query, creator: name)
            rowItems[indexPath.section][indexPath.row] = name
        }
        return indexPath
    }
    
    func deleteUsernamePagerAtIndexPath(indexPath: NSIndexPath) {
        assert(indexPath.section == ResultsSection)
        pagers.usernamePagers.removeAtIndex(indexPath.row - UsernameOffset)
    }
    
    let UsernameOffset = 1 // Subtract 1 for User Header
    
    func insertionSortIndexForUser(item: String, atIndex: Int, list: [SetPager]) -> Int {
        for i in 0..<list.count {
            if (i != atIndex && item <= list[i].creator) {
                return (item == list[i].creator) ? atIndex : i
            }
        }
        return list.count
    }
    
    // MARK: - Classes
    
    func insertNewClass(id: String) -> NSIndexPath {
        let insertIndex = 0
        let path = NSIndexPath(forRow: insertIndex + ClassOffset(), inSection: ResultsSection)
        insertAtIndexPath(path, type: .ClassCell, item: id)
        pagers.classPagers.insert(SetPager(query: pagers.queryPager?.query, classId: id), atIndex: insertIndex)
        return path
    }
    
    func updateClass(var name: String!, atIndexPath indexPath: NSIndexPath) {
        assert(indexPath.section == ResultsSection)
        if (name == nil) {
            name = ""
        }
        
        let pager = pagers.classPagers[indexPath.row - ClassOffset()]
        pager.reset(query: pagers.queryPager?.query, classId: name)
        rowItems[indexPath.section][indexPath.row] = name
    }
    
    func updateAndSortClass(var name: String!, var atIndexPath indexPath: NSIndexPath) -> NSIndexPath {
        assert(indexPath.section == ResultsSection)
        if (name == nil) {
            name = ""
        }
        
        let query = pagers.queryPager?.query
        
        let oldIndex = indexPath.row - ClassOffset()
        var newIndex = insertionSortIndexForClass(name, atIndex: oldIndex, list: pagers.classPagers)
        if (oldIndex != newIndex) {
            let pager = pagers.classPagers.removeAtIndex(oldIndex)
            rowItems[indexPath.section].removeAtIndex(oldIndex + ClassOffset())
            
            if (newIndex > oldIndex) {
                newIndex--
            }
            
            pagers.classPagers.insert(pager, atIndex: newIndex)
            rowItems[indexPath.section].insert(name, atIndex: newIndex + ClassOffset())
            
            indexPath = NSIndexPath(forRow: newIndex + ClassOffset(), inSection: indexPath.section)
        }
        else {
            pagers.classPagers[oldIndex].reset(query: query, classId: name)
            rowItems[indexPath.section][indexPath.row] = name
        }
        return indexPath
    }
    
    func deleteClassPagerAtIndexPath(indexPath: NSIndexPath) {
        assert(indexPath.section == ResultsSection)
        pagers.classPagers.removeAtIndex(indexPath.row - ClassOffset())
    }
    
    func ClassOffset() -> Int {
        return pagers.usernamePagers.count + 2
    }
    
    func insertionSortIndexForClass(item: String, atIndex: Int, list: [SetPager]) -> Int {
        for i in 0..<list.count {
            if (i != atIndex && item <= list[i].classId) {
                return (item == list[i].classId) ? atIndex : i
            }
        }
        return list.count
    }
    
    // MARK: - Row types and items
    
    func insertAtIndexPath(path: NSIndexPath, type: QueryRowType, item: String) {
        rowTypes[path.section].insert(type, atIndex: path.row)
        rowItems[path.section].insert(item, atIndex: path.row)
    }
    
    func deleteAtIndexPath(path: NSIndexPath) {
        rowTypes[path.section].removeAtIndex(path.row)
        rowItems[path.section].removeAtIndex(path.row)
    }
    
    func reloadData() {
        let Q = QuerySection
        let R = ResultsSection
        
        rowTypes = [[],[]]
        rowItems = [[],[]]
        
        add(Q, .QueryHeader)
        // add(Q, .QueryCell)

        add(R, .UserHeader)
        for pager in pagers.usernamePagers {
            add(R, .UserCell, pager.creator!)
        }
        
        add(R, .ClassHeader)
        for pager in pagers.classPagers {
            add(R, .ClassCell, pager.classId!)
        }
        
        if (includedSets.count > 0) {
            add(R, .IncludeHeader)
            for set in includedSets {
                add(R, .IncludeCell, set)
            }
        }

        if (excludedSets.count > 0) {
            add(R, .ExcludeHeader)
            for set in excludedSets {
                add(R, .ExcludeCell, set)
            }
        }
        
        add(R, .ResultHeader)
    }
    
    func add(section: Int, _ type: QueryRowType, _ rowItem: String = "") {
        rowTypes[section].append(type)
        rowItems[section].append(rowItem)
    }
    
    // MARK: - Load and Save
    
    func loadFromDataModel(q: Query) {
        type = q.type
        title = q.title
        
        pagers.queryPager = q.query.isEmpty ? nil : SetPager(query: q.query)

        // With Swift string: let usernames = q.creators.characters.split{$0 == ","}.map(String.init)
        // Using NSString for now because Swift strings are slow
        let usernames = (q.creators as NSString).componentsSeparatedByString(sep)
        pagers.usernamePagers.removeAll()
        for name in usernames {
            pagers.usernamePagers.append(SetPager(query: q.query, creator: name))
        }
        
        let classIds = (q.classes as NSString).componentsSeparatedByString(sep)
        pagers.classPagers.removeAll()
        for id in classIds {
            pagers.classPagers.append(SetPager(query: q.query, classId: id))
        }
        
        includedSets = (q.includedSets as NSString).componentsSeparatedByString(sep)
        excludedSets = (q.excludedSets as NSString).componentsSeparatedByString(sep)
    }
    
    func saveToDataModel(q: Query) {
        if (q.type != type) {
            q.type = type
        }
        if (q.title != title) {
            q.title = title
        }
        
        let query = (pagers.queryPager?.query != nil) ? pagers.queryPager!.query! : ""
        if (q.query != query) {
            q.query = query
        }
        
        var usernames = [String]()
        for pager in pagers.usernamePagers {
            usernames.append(pager.creator!)
        }
        let creators = usernames.joinWithSeparator(sep)
        if (q.creators != creators) {
            q.creators = creators
        }
        
        var ids = [String]()
        for pager in pagers.classPagers {
            ids.append(pager.classId!)
        }
        let classIds = ids.joinWithSeparator(sep)
        if (q.classes != classIds) {
            q.classes = classIds
        }
        
        let includedIds = includedSets.joinWithSeparator(sep)
        if (q.includedSets != includedIds) {
            q.includedSets = includedIds
        }
        
        let excludedIds = excludedSets.joinWithSeparator(sep)
        if (q.excludedSets != excludedIds) {
            q.excludedSets = excludedIds
        }
        
        // @NSManaged var user: User
        // @NSManaged var sets: NSSet
    }
}
