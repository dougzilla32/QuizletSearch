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

    @NSManaged var id: Int32
    @NSManaged var title: String
    @NSManaged var url: String
    @NSManaged var createdBy: String
    @NSManaged var creatorId: Int32
    @NSManaged var terms: NSOrderedSet
    @NSManaged var filters: NSSet

}
