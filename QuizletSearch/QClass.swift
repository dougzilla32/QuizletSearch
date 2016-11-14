//
//  QClass.swift
//  QuizletSearch
//
//  Created by Doug on 11/13/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import Foundation

class QClass: QItem {
    let id: Int64           // Quizlet's unique ID for a class.
    let name: String        // The name of the class, as supplied by the class's creator.
    let setCount: Int64     // The number of sets in this class (includes the number of non-public sets).
    let userCount: Int64	// The number of members in this class.
    let createdDate: Int64	// The date/time at which the class was created. Dates are UNIX timestamps.
    let adminOnly: Bool     // true or false depending on whether non-admins are allows to invite other members and post sets to this class.
    let hasAccess: Bool     // true or false depending on whether the currently logged in user has access.
    let accessLevel: String	// uninvolved,removed,rejected,applicant,member, or admin depending on how much access the currently logged in user has to this class.
    let description: String	// The creator's description of the class.

    var type: QTypeId { get { return QTypeId.qClass } }
    
    init(id: Int64, name: String, setCount: Int64, userCount: Int64, createdDate: Int64,
         adminOnly: Bool, hasAccess: Bool, accessLevel: String, description: String) {
         self.id = id
         self.name = name
         self.setCount = setCount
         self.userCount = userCount
         self.createdDate = createdDate
         self.adminOnly = adminOnly
         self.hasAccess = hasAccess
         self.accessLevel = accessLevel
         self.description = description
    }

    class func classFromJSON(_ jsonClass: NSDictionary) -> QClass? {
        var qclass: QClass? = nil
        if  let id = (jsonClass["id"] as? NSNumber)?.int64Value,
            let name = jsonClass["name"] as? String,
            let setCount = (jsonClass["set_count"] as? NSNumber)?.int64Value,
            let userCount = (jsonClass["user_count"] as? NSNumber)?.int64Value,
            let createdDate = (jsonClass["created_date"] as? NSNumber)?.int64Value,
            let adminOnly = jsonClass["admin_only"] as? Bool,
            let hasAccess = jsonClass["has_access"] as? Bool,
            let accessLevel = jsonClass["access_level"] as? String,
            let description = jsonClass["description"] as? String {
            qclass = QClass(id: id, name: name, setCount: setCount, userCount: userCount, createdDate: createdDate, adminOnly: adminOnly, hasAccess: hasAccess, accessLevel: accessLevel, description: description)
        }
        return qclass
    }
    
    class func classesFromJSON(_ json: Array<NSDictionary>) -> Array<QClass>? {
        var qclasses = [QClass]()
        for jsonClass in json {
            let qclass = QClass.classFromJSON(jsonClass)
            if (qclass == nil) {
                NSLog("Invalid Quizlet Class in classesFromJSON: \(jsonClass)")
                if (!IsFaultTolerant) {
                    return nil
                }
                continue
            }
            qclasses.append(qclass!)
        }
        return qclasses
    }
}
