//
//  QuizletTerm.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/27/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation
import CoreData

class QuizletTerm: NSManagedObject {

    @NSManaged var term: String
    @NSManaged var definition: String
    @NSManaged var set: QuizletSet

}
