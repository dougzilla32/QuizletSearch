//
//  LevenshteinDistance.swift
//  QuizletSearch
//
//  https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Levenshtein_distance#Objective-C
//

import Foundation

func computeLevenshteinScore(_ source: String, target: String) -> Double {
    let sourceCharacters = Array(source)
    let targetCharacters = Array(target)
    let levenshteinDistance = computeLevenshteinDistance(sourceCharacters, target: targetCharacters)
    return 1.0 - (Double(levenshteinDistance)/Double(Swift.max(sourceCharacters.count, targetCharacters.count)))
}

func computeLevenshteinDistance(_ source: String, target: String) -> Int {
    return computeLevenshteinDistance(Array(source), target: Array(target))
}

private func computeLevenshteinDistance(_ source: [Character], target: [Character]) -> Int {
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
            let match = (source[i - 1] == target[j - 1]) ? 0 : 1
            let costReplace = cost[i - 1] + match
            let costInsert = cost[i] + 1
            let costDelete = newCost[i - 1] + 1
            newCost[i] = Swift.min(Swift.min(costInsert, costDelete), costReplace)
        }
        
        let swap: [Int] = cost
        cost = newCost
        newCost = swap
    }
    
    return cost[sourceLength - 1]
}
