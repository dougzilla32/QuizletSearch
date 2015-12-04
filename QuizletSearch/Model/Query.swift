//
//  Query.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/27/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation
import CoreData

class Query: NSManagedObject {
    
    @NSManaged var type: String
    @NSManaged var title: String
    @NSManaged var query: String
    @NSManaged var creators: String // comma separated list [username, folder], [username2, folder]
    @NSManaged var classes: String  // comma separated list of class IDs
    @NSManaged var includedSets: String  // comma separated list of included set IDs
    @NSManaged var excludedSets: String  // comma separated list of excluded set IDs
    @NSManaged var maxModifiedDate: Int64
    @NSManaged var user: User
    @NSManaged var sets: NSSet // QuizletSet

    var timeOfMostRecentSuccessfulRefresh: NSTimeInterval?
}
