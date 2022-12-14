//
//  QSet.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/20/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation

class QSet: QItem {
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
    let termCount: Int64?
    
    var normalizedTitle: StringWithBoundaries?
    var normalizedDescription: StringWithBoundaries?
    var normalizedCreatedBy: StringWithBoundaries?
    
    var type: QTypeId { get { return QTypeId.qSet } }
    
    init(id: Int64, url: String, title: String, description: String, createdBy: String, creatorId: Int64, createdDate: Int64, modifiedDate: Int64, classIds: String, termCount: Int64? = nil) {
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
        self.termCount = termCount
    }
    
    class func setFromJSON(_ jsonSet: NSDictionary) -> QSet? {
        var qset: QSet? = nil
        if  let id = (jsonSet["id"] as? NSNumber)?.int64Value,
            let url = jsonSet["url"] as? String,
            let title = jsonSet["title"] as? String,
            let description = jsonSet["description"] as? String,
            let createdBy = jsonSet["created_by"] as? String,
            let creatorId = (jsonSet["creator_id"] as? NSNumber)?.int64Value,
            let createdDate = (jsonSet["created_date"] as? NSNumber)?.int64Value,
            let modifiedDate = (jsonSet["modified_date"] as? NSNumber)?.int64Value {
                var classIds = ""
                if let ids = jsonSet["class_ids"] as? NSArray {
                    for id in ids {
                        if let idNumber = id as? NSNumber {
                            if (!classIds.isEmpty) {
                                classIds += ","
                            }
                            classIds += String(describing: idNumber)
                        }
                    }
                }
                let termCount = (jsonSet["term_count"] as? NSNumber)?.int64Value
            
                qset = QSet(id: id, url: url, title: title, description: description, createdBy: createdBy, creatorId: creatorId, createdDate: createdDate, modifiedDate: modifiedDate, classIds: classIds, termCount: termCount)
            
                if let terms = jsonSet["terms"] as? NSArray {
                    for termObject in terms {
                        if let termObjectDictionary = termObject as? NSDictionary {
                            if  let id = (termObjectDictionary["id"] as? NSNumber)?.int64Value,
                                let term = termObjectDictionary["term"] as? String,
                                let definition = termObjectDictionary["definition"] as? String {
                                    qset!.terms.append(QTerm(id: id, term: term, definition: definition))
                            }
                        }
                    }
                }
        }
        return qset
    }
    
    class func setsFromJSON(_ json: Array<NSDictionary>) -> Array<QSet>? {
        var qsets = [QSet]()
        for jsonSet in json {
            let qset = QSet.setFromJSON(jsonSet)
            if (qset == nil) {
                NSLog("Invalid Quizlet Set in setsFromJSON: \(jsonSet)")
                if (!IsFaultTolerant) {
                    return nil
                }
                continue
            }
            qsets.append(qset!)
        }
        return qsets
    }

    func appendTerm(_ term: QTerm) {
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
