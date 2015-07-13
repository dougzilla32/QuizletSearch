//
//  QuizletSet.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/27/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation
import CoreData

class QuizletSet: NSManagedObject {

    @NSManaged var id: Int64
    @NSManaged var title: String
    @NSManaged var url: String
    @NSManaged var createdBy: String
    @NSManaged var creatorId: Int64
    @NSManaged var modifiedDate: Int64
    @NSManaged var terms: NSOrderedSet
    @NSManaged var filters: NSSet

    func initFrom(qset: QSet, moc: NSManagedObjectContext) {
        self.id = qset.id
        self.title = qset.title
        self.url = qset.url
        self.createdBy = qset.createdBy
        self.creatorId = qset.creatorId
        
        var newTerms = [Term]()
        for qterm in qset.terms {
            var term = NSEntityDescription.insertNewObjectForEntityForName("Term",
                inManagedObjectContext: moc) as! Term
            term.term = qterm.term
            term.definition = qterm.definition
            term.set = self
            newTerms.append(term)
        }
        self.terms = NSOrderedSet(array: newTerms)
        self.filters = NSSet()
    }
    
    func copyFrom(qset: QSet, moc: NSManagedObjectContext) {
        if (self.id != qset.id) {
            NSLog("Mismatching ids when caching quizlet set: \(qset.title)")
        }
        self.title = qset.title
        self.url = qset.url
        self.createdBy = qset.createdBy
        self.creatorId = qset.creatorId
        
        // Update the terms
        var minCount = min(self.terms.count, qset.terms.count)
        var replaceFromHere = minCount
        
        // Compare terms until we find the first mismatch
        for i in 0 ..< minCount {
            var term = self.terms[i] as! Term
            // TODO: could possibly rely on the id for comparison rather than term and definition
            // if (term.id != qset.terms[i].id)
            if (term.term != qset.terms[i].term || term.definition != qset.terms[i].definition) {
                replaceFromHere = i
                break
            }
        }
        
        if (replaceFromHere < self.terms.count || replaceFromHere < qset.terms.count) {
            // Add, update, and delete terms as necessary
            var mutableItems = self.terms.mutableCopy() as! NSMutableOrderedSet
            
            // Update terms
            for i in replaceFromHere ..< minCount {
                var term = mutableItems[i] as! Term
                term.id = qset.terms[i].id
                term.term = qset.terms[i].term
                term.definition = qset.terms[i].definition
            }
            
            // Delete extra terms (if any)
            for i in minCount ..< self.terms.count {
                moc.deleteObject(mutableItems[i] as! Term)
            }
            
            // Append new terms (if any)
            for i in minCount ..< qset.terms.count {
                var term = NSEntityDescription.insertNewObjectForEntityForName("Term",
                    inManagedObjectContext: moc) as! Term
                term.id = qset.terms[i].id
                term.term = qset.terms[i].term
                term.definition = qset.terms[i].definition
                term.set = self
                mutableItems.addObject(term)
            }

            self.terms = mutableItems.copy() as! NSOrderedSet
        }
    }
}
