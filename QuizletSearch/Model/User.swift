//
//  User.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/27/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation
import CoreData

class User: NSManagedObject {

    @NSManaged var accessToken: String
    @NSManaged var accessTokenExpiration: Int64
    @NSManaged var name: String
    @NSManaged var id: String

    @NSManaged var root: Root
    @NSManaged var queries: NSOrderedSet

    func copyFrom(userAccount: UserAccount) {
        self.accessToken = userAccount.accessToken
        self.accessTokenExpiration = Int64(userAccount.expiresIn) + Int64(NSDate().timeIntervalSince1970)
        self.name = userAccount.userName
        self.id = userAccount.userId
    }
    
    func expiresIn() -> Int {
        return Int(self.accessTokenExpiration - Int64(NSDate().timeIntervalSince1970))
    }
    
    func addQuery(query: Query) {
        let mutableItems = queries.mutableCopy() as! NSMutableOrderedSet
        mutableItems.addObject(query)
        queries = mutableItems.copy() as! NSOrderedSet
    }

    func insertQuery(query: Query, atIndex: Int) {
        let mutableItems = queries.mutableCopy() as! NSMutableOrderedSet
        mutableItems.insertObject(query, atIndex: atIndex)
        queries = mutableItems.copy() as! NSOrderedSet
    }

    func moveQueriesAtIndexes(indexes: NSIndexSet, toIndex: Int) {
        let mutableItems = queries.mutableCopy() as! NSMutableOrderedSet
        mutableItems.moveObjectsAtIndexes(indexes, toIndex: toIndex)
        queries = mutableItems.copy() as! NSOrderedSet
    }

    func removeQueryAtIndex(index: Int) {
        let mutableItems = queries.mutableCopy() as! NSMutableOrderedSet
        mutableItems.removeObjectAtIndex(index)
        queries = mutableItems.copy() as! NSOrderedSet
    }
}
