//
//  Filter.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/20/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation

class Filter {
    var quizletSets: [Int: QuizletSet] = [:]
        
    func addSet(id: Int, quizletSet: QuizletSet) {
        quizletSets[id] = quizletSet
    }
        
    func removeSet(id: Int, quizletSet: QuizletSet) {
        quizletSets.removeValueForKey(id)
    }
}