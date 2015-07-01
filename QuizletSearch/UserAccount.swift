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
    let userName: String
    let userId: String

    init(accessToken: String, expiresIn: Int, userName: String, userId: String) {
        self.accessToken = accessToken
        self.expiresIn = expiresIn
        self.userName = userName
        self.userId = userId
    }
}
