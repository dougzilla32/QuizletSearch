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
    @NSManaged var setDescription: String
    @NSManaged var url: String
    @NSManaged var createdBy: String
    @NSManaged var creatorId: Int64
    @NSManaged var createdDate: Int64
    @NSManaged var modifiedDate: Int64
    @NSManaged var terms: NSOrderedSet
    @NSManaged var queries: NSSet

    func initFrom(qset: QSet, moc: NSManagedObjectContext) {
        self.id = qset.id
        self.title = qset.title
        self.setDescription = qset.description
        self.url = qset.url
        self.createdBy = qset.createdBy
        self.creatorId = qset.creatorId
        self.createdDate = qset.createdDate
        self.modifiedDate = qset.modifiedDate
        
        var newTerms = [Term]()
        for qterm in qset.terms {
            let term = NSEntityDescription.insertNewObjectForEntityForName("Term",
                inManagedObjectContext: moc) as! Term
            term.initFrom(qterm)
            term.set = self
            newTerms.append(term)
        }
        self.terms = NSOrderedSet(array: newTerms)
        self.queries = NSSet()
    }
    
    func copyFrom(qset: QSet, moc: NSManagedObjectContext) {
        if (self.id != qset.id) {
            NSLog("Mismatching ids when caching quizlet set: \(qset.title)")
        }
        if (self.title != qset.title) {
            self.title = qset.title
        }
        if (self.setDescription != qset.description) {
            self.setDescription = qset.description
        }
        if (self.url != qset.url) {
            self.url = qset.url
        }
        if (self.createdBy != qset.createdBy) {
            self.createdBy = qset.createdBy
        }
        if (self.creatorId != qset.creatorId) {
            self.creatorId = qset.creatorId
        }
        if (self.createdDate != qset.createdDate) {
            self.createdDate = qset.createdDate
        }
        if (self.modifiedDate != qset.modifiedDate) {
            self.modifiedDate = qset.modifiedDate
        }
        
        // Update the terms
        let minCount = min(self.terms.count, qset.terms.count)
        var updateFromHere = minCount
        
        // Compare terms until we find the first mismatch
        for i in 0 ..< minCount {
            let term = self.terms[i] as! Term
            if (term.id != qset.terms[i].id || term.term != qset.terms[i].term || term.definition != qset.terms[i].definition) {
                updateFromHere = i
                break
            }
        }
        
        if (updateFromHere < self.terms.count || updateFromHere < qset.terms.count) {
            // Update terms
            for i in updateFromHere ..< minCount {
                let term = self.terms[i] as! Term
                term.copyFrom(qset.terms[i])
            }
            
            if (self.terms.count > minCount || qset.terms.count > minCount) {
                let mutableItems = self.terms.mutableCopy() as! NSMutableOrderedSet

                // Delete extra terms (if any)
                for var i = self.terms.count - 1; i >= minCount; i-- {
                    moc.deleteObject(mutableItems[i] as! Term)
                    mutableItems.removeObjectAtIndex(i)
                }
                
                // Append new terms (if any)
                for i in minCount ..< qset.terms.count {
                    let term = NSEntityDescription.insertNewObjectForEntityForName("Term",
                        inManagedObjectContext: moc) as! Term
                    term.initFrom(qset.terms[i])
                    term.set = self
                    mutableItems.addObject(term)
                }
                
                self.terms = mutableItems.copy() as! NSOrderedSet
            }
        }
    }
}
