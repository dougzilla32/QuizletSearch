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
    @NSManaged var id: Int32
    @NSManaged var filters: NSOrderedSet

}
