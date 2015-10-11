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
    
    var cellIds: [String] = []
    var rowItems: [String] = []
    
    func cellIdentifierForPath(indexPath: NSIndexPath) -> String {
        return cellIds[indexPath.section + indexPath.row]
    }
    
    func rowItemForPath(indexPath: NSIndexPath) -> String {
        return rowItems[indexPath.section + indexPath.row]
    }
    
    func resultHeaderPath() -> NSIndexPath {
        return pathForRow(cellIds.count - 1)
    }
    
    func pathForRow(row: Int) -> NSIndexPath {
        let section = (row == 0) ? 0 : 1
        return NSIndexPath(forRow: row - section, inSection: section)
    }
    
    func numberOfRowsInSection(section: Int) -> Int {
        return (section == 0) ? 1 : (cellIds.count - 1)
    }
    
    func isHeaderAtPath(indexPath: NSIndexPath) -> Bool {
        return (cellIdentifierForPath(indexPath) as NSString).hasSuffix(" Header")
    }

    func reloadData() {
        cellIds = []
        rowItems = []
        
        add("Query Header")
        // add("Query Cell")

        add("User Header")
        for name in usernames {
            add("User Cell", name)
        }
        
        add("Class Header")
        for qcls in classes {
            add("Class Cell", qcls.title)
        }
        
        if (includedSets.count > 0) {
            add("Include Header")
            for set in includedSets {
                add("Include Cell", set.title)
            }
        }

        if (excludedSets.count > 0) {
            add("Exclude Header")
            for set in excludedSets {
                add("Exclude Cell", set.title)
            }
        }
        
        add("Result Header")
    }
    
    func add(cellId: String, _ rowItem: String = "") {
        cellIds.append(cellId)
        rowItems.append(rowItem)
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
