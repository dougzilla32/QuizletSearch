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
    @NSManaged var queries: NSOrderedSet // Query

    func copyFrom(_ userAccount: UserAccount) {
        self.accessToken = userAccount.accessToken
        self.accessTokenExpiration = Int64(userAccount.expiresIn) + Int64(Date().timeIntervalSince1970)
        self.name = userAccount.userName
        self.id = userAccount.userId
    }
    
    func expiresIn() -> Int {
        return Int(self.accessTokenExpiration - Int64(Date().timeIntervalSince1970))
    }
    
    func addQuery(_ query: Query) {
        let mutableItems = queries.mutableCopy() as! NSMutableOrderedSet
        mutableItems.add(query)
        queries = mutableItems.copy() as! NSOrderedSet
    }

    func insertQuery(_ query: Query, atIndex: Int) {
        let mutableItems = queries.mutableCopy() as! NSMutableOrderedSet
        mutableItems.insert(query, at: atIndex)
        queries = mutableItems.copy() as! NSOrderedSet
    }

    func moveQueriesAtIndexes(_ indexes: IndexSet, toIndex: Int) {
        let mutableItems = queries.mutableCopy() as! NSMutableOrderedSet
        mutableItems.moveObjects(at: indexes, to: toIndex)
        queries = mutableItems.copy() as! NSOrderedSet
    }

    func removeQueryAtIndex(_ index: Int) {
        let mutableItems = queries.mutableCopy() as! NSMutableOrderedSet
        mutableItems.removeObject(at: index)
        queries = mutableItems.copy() as! NSOrderedSet
    }
}
