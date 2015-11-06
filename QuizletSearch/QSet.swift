//
//  QSet.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/20/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation

class QSet {
    let id: Int64
    let url: String
    let title: String
    let description: String
    let createdBy: String
    let creatorId: Int64
    let createdDate: Int64
    let modifiedDate: Int64
    let classIds: String
    
    var terms: [QTerm]
    
    init(id: Int64, url: String, title: String, description: String, createdBy: String, creatorId: Int64, createdDate: Int64, modifiedDate: Int64, classIds: String) {
        self.id = id
        self.url = url
        self.title = title
        self.description = description
        self.createdBy = createdBy
        self.creatorId = creatorId
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.classIds = classIds
        self.terms = []
    }
    
    class func setFromJSON(jsonSet: NSDictionary) -> QSet? {
        var qset: QSet? = nil
        if  let id = (jsonSet["id"] as? NSNumber)?.longLongValue,
            let url = jsonSet["url"] as? String,
            let title = jsonSet["title"] as? String,
            let description = jsonSet["description"] as? String,
            let createdBy = jsonSet["created_by"] as? String,
            let creatorId = (jsonSet["creator_id"] as? NSNumber)?.longLongValue,
            let createdDate = (jsonSet["created_date"] as? NSNumber)?.longLongValue,
            let modifiedDate = (jsonSet["modified_date"] as? NSNumber)?.longLongValue {
                var classIds = ""
                if let ids = jsonSet["class_ids"] as? NSArray {
                    for id in ids {
                        if let idNumber = id as? NSNumber {
                            if (!classIds.isEmpty) {
                                classIds += ","
                            }
                            classIds += String(idNumber)
                        }
                    }
                }
                qset = QSet(id: id, url: url, title: title, description: description, createdBy: createdBy, creatorId: creatorId, createdDate: createdDate, modifiedDate: modifiedDate, classIds: classIds)
                if let terms = jsonSet["terms"] as? NSArray {
                    for termObject in terms {
                        if  let id = (termObject["id"] as? NSNumber)?.longLongValue,
                            let term = termObject["term"] as? String,
                            let definition = termObject["definition"] as? String {
                                qset!.terms.append(QTerm(id: id, term: term, definition: definition))
                        }
                    }
                }
        }
        return qset
    }
    
    class func setsFromJSON(json: Array<NSDictionary>) -> Array<QSet>? {
        var qsets = [QSet]()
        for jsonSet in json {
            let qset = QSet.setFromJSON(jsonSet)
            if (qset == nil) {
                NSLog("Invalid Quizlet Set in setsFromJSON: \(jsonSet)")
                return nil
            }
            qsets.append(qset!)
        }
        return qsets
    }

    func appendTerm(term: QTerm) {
        self.terms.append(term)
    }
}

class QTerm {
    let id: Int64
    let term: String
    let definition: String
    
    init(id: Int64, term: String, definition: String) {
        self.id = id
        self.term = term
        self.definition = definition
    }
}
