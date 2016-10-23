//
//  SearchIndex.swift
//  QuizletSearch
//
//  Created by Doug on 10/21/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import Foundation

class SearchIndex {
    let MaxCount = 3

    var index = [String: IndexedSetsAndTerms]()
    
    init() {
    }
    
    func buildIndex(allTerms: SortedSetsAndTerms<SortTerm>) {
        for set in allTerms.bySet {
            for term in set.terms {
                buildIndex(text: term.termForCompare.string,
                           isDefinition: false,
                           term: term,
                           set: set,
                           firstCharacter: SearchOperation.firstCharacterForSet(text: term.termForDisplay.string))
                buildIndex(text: term.definitionForCompare.string,
                           isDefinition: true,
                           term: term,
                           set: set,
                           firstCharacter: SearchOperation.firstCharacterForSet(text: term.definitionForDisplay.string))
            }
        }
    }
    
    func buildIndex(text: String, isDefinition: Bool, term: SortTerm, set: SortedQuizletSet<SortTerm>, firstCharacter: Character) {
        var currentCharacterIndex = 0
        var substrings = [String]()
        var substringsIndex = -1
        
        for uc in text.utf16 {
            // for c in lowerText.characters {
            let c = Character(UnicodeScalar(uc)!)
            if (Common.isAlphaNumeric(c)) {
                if (substrings.count == 0) {
                    substringsIndex = currentCharacterIndex
                    // print("")
                }
                else {
                    if (substrings.count == MaxCount) {
                        substrings.removeFirst()
                        substringsIndex += 1
                    }
                    for i in 0 ..< substrings.count {
                        var substr = substrings[i]
                        substr.append(c)
                        substrings[i] = substr
                        
                        addRangeToIndex(range: NSRange(location: substringsIndex + i, length: currentCharacterIndex - substringsIndex - i), forSubstring: substr,  isDefinition: isDefinition, term: term, set: set, firstCharacter: firstCharacter)
                        // print("index[\(substr)] = \(index[substr]!)")
                    }
                }
                
                let newString = String(c)
                substrings.append(newString)
                
                addRangeToIndex(range: NSRange(location: currentCharacterIndex, length: 1), forSubstring: newString, isDefinition: isDefinition, term: term, set: set, firstCharacter: firstCharacter)
                // print("Index[\(newString)] = \(index[newString]!)")
            }
            else {
                // Commented out to allow search across word boundaries:
                //
                // Reset on word boundary
                //   substrings.removeAll()
                //   substringsIndex = -1
            }
            
            currentCharacterIndex += 1
        }
    }
    
    func addRangeToIndex(range: NSRange, forSubstring: String, isDefinition: Bool, term: SortTerm, set: SortedQuizletSet<SortTerm>, firstCharacter: Character) {
        var indexedSetsAndTerms = index[forSubstring]
        if (indexedSetsAndTerms == nil) {
            indexedSetsAndTerms = IndexedSetsAndTerms()
            index[forSubstring] = indexedSetsAndTerms
        }
        
        indexedSetsAndTerms!.appendRange(range: range, isDefinition: isDefinition, term: term, set: set, firstCharacter: firstCharacter)
        
        // Using the Array<NSRange> code is almost 5x slower:
        //        if (indexMap[forSubstring] == nil) {
        //            indexMap[forSubstring] = Array<NSRange>()
        //        }
        //        indexMap[forSubstring]!.append(index)
    }
    
    func find(_ s: String) -> IndexedSetsAndTerms? {
        return index[s]
    }
}

class TermPair {
    var sortTerm: SortTerm?
    var searchTerm: SearchTerm?
}

class SetPair {
    var sortSet: SortedQuizletSet<SortTerm>?
    var searchSet: SortedQuizletSet<SearchTerm>?
}

class SetIndexReference {
    var index: [Character: SortedQuizletSet<SearchTerm>] = [:]
}

class IndexedSetsAndTerms {
    var AtoZ: [SortedQuizletSet<SearchTerm>]?
    var bySet: [SortedQuizletSet<SearchTerm>] = []
    var bySetAtoZ: [SortedQuizletSet<SearchTerm>]?
    
    var AtoZTermPair: TermPair! = TermPair()
    var AtoZIndex: SetIndexReference! = SetIndexReference()
    
    var bySetTermPair: TermPair! = TermPair()
    var bySetPair: SetPair! = SetPair()
    
    func getAtoZ() -> [SortedQuizletSet<SearchTerm>] {
        if (AtoZ == nil) {
            AtoZ = []
            for elem in AtoZIndex.index.values {
                AtoZ!.append(elem)
            }

            AtoZTermPair = nil
            AtoZIndex = nil

            AtoZ!.sort(by: { (s1: SortedQuizletSet<SearchTerm>, s2: SortedQuizletSet<SearchTerm>) -> Bool in
                return s1.title.compare(s2.title, options: [.caseInsensitive, .numeric]) != .orderedDescending
            })
        }
        return AtoZ!
    }
    
    func getBySet() -> [SortedQuizletSet<SearchTerm>] {
        if (bySetTermPair != nil) {
            bySetTermPair = nil
            bySetPair = nil
        }
        return bySet
    }
    
    func getBySetAtoZ() -> [SortedQuizletSet<SearchTerm>] {
        if (bySetTermPair != nil) {
            bySetTermPair = nil
            bySetPair = nil
        }
        if (bySetAtoZ == nil) {
            bySetAtoZ = bySet

            bySetAtoZ!.sort(by: { (s1: SortedQuizletSet<SearchTerm>, s2: SortedQuizletSet<SearchTerm>) -> Bool in
                return s1.title.compare(s2.title, options: [.caseInsensitive, .numeric]) != .orderedDescending
            })
        }
        return bySetAtoZ!
    }
    
    func appendRange(range: NSRange, isDefinition: Bool, term: SortTerm, set: SortedQuizletSet<SortTerm>, firstCharacter: Character) {
        appendRange(range: range, isDefinition: isDefinition, term: term, firstCharacter: firstCharacter,
                    termPair: AtoZTermPair, setIndex: AtoZIndex)
        
        appendRange(range: range, isDefinition: isDefinition, term: term, set: set,
                    termPair: bySetTermPair, setPair: bySetPair)
    }
    
    func appendRange(range: NSRange,
                     isDefinition: Bool,
                     term: SortTerm,
                     firstCharacter: Character,
                     termPair: TermPair,
                     setIndex: SetIndexReference) {
        var searchTerm: SearchTerm
        if (termPair.sortTerm == term) {
            searchTerm = termPair.searchTerm!
        }
        else {
            searchTerm = SearchTerm(sortTerm: term)
            
            var searchSet = setIndex.index[firstCharacter]
            if (searchSet == nil) {
                searchSet = SortedQuizletSet<SearchTerm>(title: "\(firstCharacter)", terms: [searchTerm], createdDate: 0)
                setIndex.index[firstCharacter] = searchSet
            }
            else {
                searchSet!.terms.append(searchTerm)
            }
        }
        
        if (isDefinition) {
            searchTerm.definitionRanges.append(range)
        }
        else {
            searchTerm.termRanges.append(range)
        }
    }
    
    func appendRange(range: NSRange,
                     isDefinition: Bool,
                     term: SortTerm,
                     set: SortedQuizletSet<SortTerm>,
                     termPair: TermPair,
                     setPair: SetPair) {
        var searchTerm: SearchTerm
        if (termPair.sortTerm == term) {
            searchTerm = termPair.searchTerm!
        }
        else {
            searchTerm = SearchTerm(sortTerm: term)
            
            if (setPair.sortSet != set) {
                setPair.searchSet = SortedQuizletSet<SearchTerm>(title: set.title, terms: [searchTerm], createdDate: set.createdDate)
                setPair.sortSet = set
                bySet.append(setPair.searchSet!)
            }
            else {
                setPair.searchSet!.terms.append(searchTerm)
            }
        }
        
        if (isDefinition) {
            searchTerm.definitionRanges.append(range)
        }
        else {
            searchTerm.termRanges.append(range)
        }
    }
}

