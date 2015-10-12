//
//  AddQueryModel.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/10/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import Foundation

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
        "User Header", "User Cell",
        "Class Header", "Class Cell",
        "Include Header", "Include Cell",
        "Exclude Header", "Exclude Cell",
        "Result Header", "Result Cell"]
    
    func id() -> String {
        return QueryRowType.Identifier[rawValue]
    }
}

class QuizletClass {
    let id: String
    let title: String
    
    init(id: String, title: String) {
        self.id = id
        self.title = title
    }
    
    convenience init() {
        self.init(id: "", title: "")
    }
}

class AddQueryModel {
    let sep = ","
    
    var type: String = ""
    var title: String = ""
    var query: String = ""
    
    var usernames: [String] = []
    var classes: [QuizletClass] = []
    var includedSets: [QuizletSet] = []
    var excludedSets: [QuizletSet] = []
    
    var rowTypes: [[QueryRowType]] = [[],[]]
    var rowItems: [[String]] = [[],[]]
    
    func cellIdentifierForPath(indexPath: NSIndexPath) -> String {
        return rowTypes[indexPath.section][indexPath.row].id()
    }
    
    func rowItemForPath(indexPath: NSIndexPath) -> String {
        return rowItems[indexPath.section][indexPath.row]
    }
    
    func resultHeaderPath() -> NSIndexPath {
        return NSIndexPath(forRow: rowTypes[1].count - 1, inSection: 1)
    }
    
    func numberOfRowsInSection(section: Int) -> Int {
        return rowTypes[section].count
    }
    
    func isHeaderAtPath(indexPath: NSIndexPath) -> Bool {
        return (cellIdentifierForPath(indexPath) as NSString).hasSuffix(" Header")
    }

    func appendUser(name: String) -> NSIndexPath {
        usernames.append(name)

        let path = NSIndexPath(forRow: usernames.count, inSection: 1)
        insertAtPath(path, type: .UserCell, item: name)
        return path
    }
    
    func appendClass(id: String, title: String) -> NSIndexPath {
        let qcls = QuizletClass(id: id, title: title)
        classes.append(qcls)

        let path = NSIndexPath(forRow: usernames.count + classes.count + 1, inSection: 1)
        insertAtPath(path, type: .ClassCell, item: qcls.title)
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
        for name in usernames {
            add(R, .UserCell, name)
        }
        
        add(R, .ClassHeader)
        for qcls in classes {
            add(R, .ClassCell, qcls.title)
        }
        
        if (includedSets.count > 0) {
            add(R, .IncludeHeader)
            for set in includedSets {
                add(R, .IncludeCell, set.title)
            }
        }

        if (excludedSets.count > 0) {
            add(R, .ExcludeHeader)
            for set in excludedSets {
                add(R, .ExcludeCell, set.title)
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
        query = q.query

        usernames = q.creators.characters.split{$0 == ","}.map(String.init)
        
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
        if (q.query != query) {
            q.query = query
        }
        
        let creators = usernames.joinWithSeparator(sep)
        if (q.creators != creators) {
            q.creators = creators
        }
        
        var ids = [String]()
        for cls in classes {
            ids.append(cls.id)
        }
        let classIds = ids.joinWithSeparator(sep)
        if (q.classes != classIds) {
            q.classes = classIds
        }
        
        ids = []
        for set in includedSets {
            ids.append(String(set.id))
        }
        let includedIds = ids.joinWithSeparator(sep)
        if (q.includedSets != includedIds) {
            q.includedSets = includedIds
        }
        
        ids = []
        for set in excludedSets {
            ids.append(String(set.id))
        }
        let excludedIds = ids.joinWithSeparator(sep)
        if (q.excludedSets != excludedIds) {
            q.excludedSets = excludedIds
        }
        
        // @NSManaged var user: User
        // @NSManaged var sets: NSSet
    }
}
