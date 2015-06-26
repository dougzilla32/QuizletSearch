//
//  QuizletSets.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/20/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation

class QuizletSet {
    var id: Int
    var url: String
    var title: String
    var createdBy: String
    var creatorId: Int
    
    var terms: [QuizletTerm]
    
    init(id: Int, url: String, title: String, createdBy: String, creatorId: Int) {
        self.id = id
        self.url = url
        self.title = title
        self.createdBy = createdBy
        self.creatorId = creatorId
        self.terms = []
    }
    
    class func setFromJSON(jsonSet: NSDictionary) -> QuizletSet? {
        var qset: QuizletSet? = nil
        if  let id = jsonSet["id"] as? Int,
            let url = jsonSet["url"] as? String,
            let title = jsonSet["title"] as? String,
            let createdBy = jsonSet["created_by"] as? String,
            let creatorId = jsonSet["creator_id"] as? Int {
                qset = QuizletSet(id: id, url: url, title: title, createdBy: createdBy, creatorId: creatorId)
        }
        return qset
    }
    
    class func setsFromJSON(json: Array<NSDictionary>) -> Array<QuizletSet>? {
        var qsets = [QuizletSet]()
        for jsonSet in json {
            var qset = QuizletSet.setFromJSON(jsonSet)
            if (qset == nil) {
                NSLog("Invalid Quizlet Set in setsFromJSON: \(jsonSet)")
                return nil
            }
            qsets.append(qset!)
        }
        return qsets
    }

    func appendTerm(term: QuizletTerm) {
        self.terms.append(term)
    }
}

class QuizletTerm {
    let term: String
    let definition: String
    
    init(term: String, definition: String) {
        self.term = term
        self.definition = definition
    }
}
