//
//  Filter.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/27/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation
import CoreData

class Filter: NSManagedObject {

    @NSManaged var title: String
    @NSManaged var query: String
    @NSManaged var user: User
    @NSManaged var sets: NSSet

}
