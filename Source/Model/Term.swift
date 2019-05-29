//
//  QuizletTerm.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/27/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation
import CoreData

class Term: NSManagedObject {

    @NSManaged var id: Int64
    @NSManaged var term: String
    @NSManaged var definition: String
    @NSManaged var set: QuizletSet

    func initFrom(_ qterm: QTerm) {
        self.id = qterm.id
        self.term = qterm.term
        self.definition = qterm.definition
    }
    
    func copyFrom(_ qterm: QTerm) {
        if (self.id != qterm.id) {
            self.id = qterm.id
        }
        if (self.term != qterm.term) {
            self.term = qterm.term
        }
        if (self.definition != qterm.definition) {
            self.definition = qterm.definition
        }
    }
}
