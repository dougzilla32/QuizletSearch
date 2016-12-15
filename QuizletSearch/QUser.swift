//
//  QUser.swift
//  QuizletSearch
//
//  Created by Doug on 11/13/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import Foundation

class QUser: QItem {
    let userName: String
    let accountType: QUserAccountType
    let profileImage: URL
    let signUpDate: Int64?
    
    var type: QTypeId { get { return QTypeId.qUser } }
    
    init(userName: String, accountType: QUserAccountType, profileImage: URL, signUpDate: Int64?) {
        self.userName = userName
        self.accountType = accountType
        self.profileImage = profileImage
        self.signUpDate = signUpDate
    }
    
    class func userFromJSON(_ jsonUser: NSDictionary) -> QUser? {
        var quser: QUser? = nil
        if  let userName = jsonUser["username"] as? String,
            let accountTypeString = jsonUser["account_type"] as? String,
            let accountType = QUserAccountType(string: accountTypeString),
            let profileImageString = jsonUser["profile_image"] as? String,
            let profileImage = URL(string: profileImageString) {
            let signUpDate = (jsonUser["sign_up_date"] as? NSNumber)?.int64Value
            quser = QUser(userName: userName, accountType: accountType, profileImage: profileImage, signUpDate: signUpDate)
        }
        return quser
    }
}

enum QUserAccountType {
    case free, plus, teacher, other
    
    init?(string: String) {
        switch string {
        case "free": self = .free
        case "plus": self = .plus
        case "teacher": self = .teacher
        default: self = .other
        }
    }
}
