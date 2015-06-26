//
//  UserAccount.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/18/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation

class UserAccount {
    let accessToken: String
    let expiresIn: Int
    let userId: String
    let creationDate: NSDate

    init(accessToken: String, expiresIn: Int, userId: String) {
        self.accessToken = accessToken
        self.expiresIn = expiresIn
        self.userId = userId
        self.creationDate = NSDate()
    }
}
