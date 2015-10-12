//
//  AddQueryModel.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/10/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import Foundation

class QuizletClass {
    let id = ""
    let title = ""
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
    
    var cellIds: [[String]] = [[],[]]
    var rowItems: [[String]] = [[],[]]
    
    func cellIdentifierForPath(indexPath: NSIndexPath) -> String {
        return cellIds[indexPath.section][indexPath.row]
    }
    
    func rowItemForPath(indexPath: NSIndexPath) -> String {
        return rowItems[indexPath.section][indexPath.row]
    }
    
    func resultHeaderPath() -> NSIndexPath {
        return NSIndexPath(forRow: cellIds[1].count - 1, inSection: 1)
    }
    
    func numberOfRowsInSection(section: Int) -> Int {
        return cellIds[section].count
    }
    
    func isHeaderAtPath(indexPath: NSIndexPath) -> Bool {
        return (cellIdentifierForPath(indexPath) as NSString).hasSuffix(" Header")
    }

    func reloadData() {
        let Q = 0
        let R = 1
        
        cellIds = [[],[]]
        rowItems = [[],[]]
        
        add(Q, "Query Header")
        // add(Q, "Query Cell")

        add(R, "User Header")
        for name in usernames {
            add(R, "User Cell", name)
        }
        
        add(R, "Class Header")
        for qcls in classes {
            add(R, "Class Cell", qcls.title)
        }
        
        if (includedSets.count > 0) {
            add(R, "Include Header")
            for set in includedSets {
                add(R, "Include Cell", set.title)
            }
        }

        if (excludedSets.count > 0) {
            add(R, "Exclude Header")
            for set in excludedSets {
                add(R, "Exclude Cell", set.title)
            }
        }
        
        add(R, "Result Header")
    }
    
    func add(section: Int, _ cellId: String, _ rowItem: String = "") {
        cellIds[section].append(cellId)
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
