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
    @NSManaged var filters: NSOrderedSet

    func copyFrom(userAccount: UserAccount) {
        self.accessToken = userAccount.accessToken
        self.accessTokenExpiration = Int64(userAccount.expiresIn + Int(NSDate().timeIntervalSince1970))
        self.name = userAccount.userName
        self.id = userAccount.userId
    }
}
