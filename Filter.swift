//
//  Filter.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/27/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation
import CoreData

enum FilterType: String {
    case CurrentUserAllSets = "CurrentUserAllSets"
    case CurrentUserFavorites = "CurrentUserFavorites"
    case GeneralQuery = "GeneralQuery"
}

class Filter: NSManagedObject {
    
    @NSManaged var type: String
    @NSManaged var title: String
    @NSManaged var query: String
    @NSManaged var queryTerm: String
    @NSManaged var queryCreator: String
    @NSManaged var user: User
    @NSManaged var currentUser: User
    @NSManaged var sets: NSSet

}
