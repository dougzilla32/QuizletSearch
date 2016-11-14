//
//  QType.swift
//  QuizletSearch
//
//  Created by Doug on 11/13/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import Foundation

protocol QItem {
    var type: QTypeId { get }
}

enum QTypeId {
    case qSet, qClass, qUser
}
