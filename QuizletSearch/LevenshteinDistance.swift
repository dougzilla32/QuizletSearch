//
//  LevenshteinDistance.swift
//  QuizletSearch
//
//  https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Levenshtein_distance#Objective-C
//

import Foundation

func computeLevenshteinScore(source: String, target: String) -> Double {
    var sourceCharacters = Array(source)
    var targetCharacters = Array(target)
    var levenshteinDistance = computeLevenshteinDistance(sourceCharacters, targetCharacters)
    return 1.0 - (Double(levenshteinDistance)/Double(max(sourceCharacters.count, targetCharacters.count)))
}

func computeLevenshteinDistance(source: String, target: String) -> Int {
    return computeLevenshteinDistance(Array(source), Array(target))
}

private func computeLevenshteinDistance(source: [Character], target: [Character]) -> Int {
    let sourceLength = source.count + 1
    let targetLength = target.count + 1
    
    var cost: [Int] = []
    var newCost: [Int] = []
    
    for i in 0..<sourceLength {
        cost.append(i)
        newCost.append(0)
    }
    
    for j in 1..<targetLength {
        newCost[0] = j - 1
        
        for i in 1..<sourceLength {
            var match = (source[i - 1] == target[j - 1]) ? 0 : 1
            var costReplace = cost[i - 1] + match
            var costInsert = cost[i] + 1
            var costDelete = newCost[i - 1] + 1
            newCost[i] = min(min(costInsert, costDelete), costReplace)
        }
        
        var swap: [Int] = cost
        cost = newCost
        newCost = swap
    }
    
    return cost[sourceLength - 1]
}