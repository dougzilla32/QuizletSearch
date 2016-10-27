//
//  SearchIndex.swift
//  QuizletSearch
//
//  Created by Doug on 10/21/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import CoreData
import Foundation

let BetweenTermAndDefinition = "\t"
let BetweenRows = "\n"
let BetweenSets = "\n"

// Turns out the search index is way too big and takes too long to create
// for larger data sets
let SearchIndexEnabled = false

class SearchIndex {
    let MaxCount = 2

    var allTerms: SortedSetsAndTerms
    var index = [String: IndexedSetsAndTerms]()
    
    init(query: Query?) {
        allTerms = SearchIndex.initSortedTerms(query: query)
        if (SearchIndexEnabled) {
            buildIndex(allTerms: allTerms)
        }
    }
    
    private func buildIndex(allTerms: SortedSetsAndTerms) {
        for set in allTerms.bySet {
            for term in set.terms {
                buildIndex(textForCompare: term.termForCompare,
                           textForDisplay: term.termForDisplay,
                           isDefinition: false,
                           term: term,
                           set: set,
                           firstCharacter: SearchIndex.firstCharacterForSet(text: term.termForDisplay.string))
                buildIndex(textForCompare: term.definitionForCompare,
                           textForDisplay: term.definitionForDisplay,
                           isDefinition: true,
                           term: term,
                           set: set,
                           firstCharacter: SearchIndex.firstCharacterForSet(text: term.definitionForDisplay.string))
            }
        }
    }
    
    class StringIndexCount {
        var text: String
        var characterIndex: Int
        var unicharCount: Int
        
        init(text: String, characterIndex: Int, unicharCount: Int) {
            self.text = text
            self.characterIndex = characterIndex
            self.unicharCount = unicharCount
        }
    }

    private func buildIndex(textForCompare: StringWithBoundaries, textForDisplay: StringWithBoundaries, isDefinition: Bool, term: SortTerm, set: SortedQuizletSet<SortTerm>, firstCharacter: Character) {
        var substrings = [StringIndexCount]()

        let text = UnicharIterator(string: textForCompare, options: .WhitespaceInsensitiveSearch)
        
        while (!text.isEnd()) {
            var isFirst = true
            repeat {
                var unichar = text.currentUnichar()
                let c = NSString.init(characters: &unichar, length: 1) as String
                
                for sic in substrings {
                    sic.text.append(c)
                    var range = NSRange(location: sic.characterIndex, length: text.characterIndex - sic.characterIndex + 1) // always +1?
                    range = textForDisplay.characterRangeToUnicharRange(range)
                    addRangeToIndex(range: range, forSubstring: sic.text, isDefinition: isDefinition, term: term, set: set, firstCharacter: firstCharacter)
                    sic.unicharCount += 1
                    if (sic.unicharCount == MaxCount) {
                        substrings.removeFirst()
                    }
                }
                
                if (isFirst) {
                    isFirst = false
                    let sic = StringIndexCount(text: c, characterIndex: text.characterIndex, unicharCount: 1)
                    
                    var range = NSRange(location: sic.characterIndex, length: text.characterIndex - sic.characterIndex + 1) // always +1?
                    range = textForDisplay.characterRangeToUnicharRange(range)
                    addRangeToIndex(range: range, forSubstring: sic.text, isDefinition: isDefinition, term: term, set: set, firstCharacter: firstCharacter)
                    
                    if (MaxCount > 1) {
                        substrings.append(sic)
                    }
                }
                
                text.advance()
            } while (!text.isCharacterBoundary() && substrings.count > 0)
            
            
            text.advanceToCharacterBoundary()
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

    private class func initSortedTerms(query: Query?) -> SortedSetsAndTerms {
        var AtoZterms: [SortTerm] = []
        var AtoZ: [SortedQuizletSet<SortTerm>] = []
        var bySet: [SortedQuizletSet<SortTerm>] = []
        var bySetAtoZ: [SortedQuizletSet<SortTerm>] = []
        
        if (query != nil) {
            for set in query!.sets {
                let quizletSet = set as! QuizletSet
                var termsForSet = [SortTerm]()
                
                for termAny in quizletSet.terms {
                    let term = termAny as! Term
                    if (term.term.isWhitespace() && term.definition.isWhitespace()) {
                        continue
                    }
                    let sortTerm = SortTerm(term: term)
                    AtoZterms.append(sortTerm)
                    termsForSet.append(sortTerm)
                }
                
                // Use native term order for 'bySet'
                bySet.append(SortedQuizletSet(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))
                
                // Use alphabetically sorted terms for 'bySetAtoZ'
                termsForSet.sort(by: termComparator)
                bySetAtoZ.append(SortedQuizletSet(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))
            }
            
            AtoZ = collateAtoZ(AtoZterms)
            // sort(&AtoZterms, termComparator)
            
            bySet.sort(by: { (s1: SortedQuizletSet<SortTerm>, s2: SortedQuizletSet<SortTerm>) -> Bool in
                return s1.createdDate > s2.createdDate
            })
            
            bySetAtoZ.sort(by: { (s1: SortedQuizletSet<SortTerm>, s2: SortedQuizletSet<SortTerm>) -> Bool in
                return s1.title.compare(s2.title, options: [.caseInsensitive, .numeric]) != .orderedDescending
            })
        }
        
        return SortedSetsAndTerms(AtoZ: AtoZ, bySet: bySet, bySetAtoZ: bySetAtoZ)
    }
    
    class func collateAtoZ(_ unsortedAtoZterms: [SortTerm]) -> [SortedQuizletSet<SortTerm>] {
        var sortedAtoZterms = unsortedAtoZterms
        sortedAtoZterms.sort(by: termComparator)
        
        var currentCharacter: Character? = nil
        var currentTerms: [SortTerm]? = nil
        var AtoZbySet: [SortedQuizletSet<SortTerm>] = []
        
        for term in sortedAtoZterms {
            var text = term.termForDisplay.string
            //var text = term.definitionForDisplay.string
            text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            let firstCharacter = firstCharacterForSet(text: text)
            
            if (currentCharacter != firstCharacter) {
                if (currentTerms != nil) {
                    AtoZbySet.append(SortedQuizletSet(title: "\(currentCharacter!)", terms: currentTerms!, createdDate: 0))
                }
                currentTerms = []
                currentCharacter = firstCharacter
            }
            currentTerms!.append(term)
        }
        
        if (currentTerms != nil) {
            AtoZbySet.append(SortedQuizletSet(title: "\(currentCharacter!)", terms: currentTerms!, createdDate: 0))
        }
        
        return AtoZbySet
    }
    
    class func firstCharacterForSet(text textParam: String) -> Character {
        let text = textParam.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        var firstCharacter: Character
        if (text.isEmpty) {
            firstCharacter = " "
        }
        else {
            firstCharacter = text[text.startIndex]
            
            // Use '9' as the index view title for all numbers greater than 9
            if "0"..."9" ~= firstCharacter {
                let next = text.characters.index(after: text.startIndex)
                if (next != text.endIndex) {
                    let secondCharacter = text[next]
                    if ("0"..."9" ~= secondCharacter) {
                        firstCharacter = "9"
                    }
                }
            }
            
            firstCharacter = Common.toUppercase(firstCharacter)
        }
        return firstCharacter
    }
    
    class func termComparator(_ t1: SortTerm, t2: SortTerm) -> Bool {
        switch (t1.termForDisplay.string.compare(t2.termForDisplay.string, options: [.caseInsensitive, .numeric])) {
        case .orderedAscending:
            return true
        case .orderedDescending:
            return false
        case .orderedSame:
            return t1.definitionForDisplay.string.compare(t2.definitionForDisplay.string, options: [.caseInsensitive, .numeric]) != .orderedDescending
        }
    }
}

class SortTerm: Equatable, Hashable {
    let termForDisplay: StringWithBoundaries
    let definitionForDisplay: StringWithBoundaries
    
    let termForCompare: StringWithBoundaries
    let definitionForCompare: StringWithBoundaries
    
    let setId: Int64
    
    init(term: Term) {
        self.termForDisplay = StringWithBoundaries(string: term.term)
        self.definitionForDisplay = StringWithBoundaries(string: term.definition)
        
        self.termForCompare = term.term.lowercased().decomposeAndNormalize()
        self.definitionForCompare = term.definition.lowercased().decomposeAndNormalize()
        
        self.setId = term.set.id
    }
    
    static func ==(lhs: SortTerm, rhs: SortTerm) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}

class SearchTerm {
    let sortTerm: SortTerm
//    let score: Double
    var termRanges: [NSRange]
    var definitionRanges: [NSRange]
    
    init(sortTerm: SortTerm,
//         score: Double = 0.0,
        termRanges: [NSRange] = [],
        definitionRanges: [NSRange] = []) {
        self.sortTerm = sortTerm
//        self.score = score
        self.termRanges = termRanges
        self.definitionRanges = definitionRanges
    }
}

class SortedQuizletSet<T>: Equatable, Hashable {
    let title: String
    var terms: [T]
    let createdDate: Int64
    
    init(title: String, terms: [T], createdDate: Int64) {
        self.title = title
        self.terms = terms
        self.createdDate = createdDate
    }

    static func ==(lhs: SortedQuizletSet<T>, rhs: SortedQuizletSet<T>) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}

protocol SearchedAndSorted {
    func getAtoZCount() -> Int
    
    func getBySetCount() -> Int
    
    func getBySetAtoZCount() -> Int
    
    func getAtoZTermCount(index: Int) -> Int
    
    func getBySetTermCount(index: Int) -> Int
    
    func getBySetAtoZTermCount(index: Int) -> Int
    
    func getAtoZTitle(index: Int) -> String
    
    func getBySetTitle(index: Int) -> String
    
    func getBySetAtoZTitle(index: Int) -> String
    
    func getAtoZSectionIndexTitles() -> [String]
    
    func getBySetSectionIndexTitles() -> [String]
    
    func getBySetAtoZSectionIndexTitles() -> [String]
    
    func termForPath(_ indexPath: IndexPath, sortSelection: SortSelection) -> SearchTerm
    
    func exportAtoZ() -> String
    
    func exportBySet() -> String
    
    func exportBySetAtoZ() -> String
}

class SortedSetsAndTerms: SearchedAndSorted {
    var AtoZ: [SortedQuizletSet<SortTerm>]
    var bySet: [SortedQuizletSet<SortTerm>]
    var bySetAtoZ: [SortedQuizletSet<SortTerm>]
    
    init() {
        AtoZ = []
        bySet = []
        bySetAtoZ = []
    }
    
    init(AtoZ: [SortedQuizletSet<SortTerm>], bySet: [SortedQuizletSet<SortTerm>], bySetAtoZ: [SortedQuizletSet<SortTerm>]) {
        self.AtoZ = AtoZ
        self.bySet = bySet
        self.bySetAtoZ = bySetAtoZ
    }

    func getAtoZCount() -> Int {
        return AtoZ.count
    }
    
    func getBySetCount() -> Int {
        return bySet.count
    }
    
    func getBySetAtoZCount() -> Int {
        return bySetAtoZ.count
    }
    
    func getAtoZTermCount(index: Int) -> Int {
        return AtoZ[index].terms.count
    }
    
    func getBySetTermCount(index: Int) -> Int {
        return bySet[index].terms.count
    }
    
    func getBySetAtoZTermCount(index: Int) -> Int {
        return bySetAtoZ[index].terms.count
    }
    
    func getAtoZTitle(index: Int) -> String {
        return AtoZ[index].title
    }
    
    func getBySetTitle(index: Int) -> String {
        return bySet[index].title
    }
    
    func getBySetAtoZTitle(index: Int) -> String {
        return bySetAtoZ[index].title
    }
    
    func getAtoZSectionIndexTitles() -> [String] {
        var titles: [String] = []
        for section in AtoZ {
            titles.append(section.title)
        }
        return titles
    }
    
    func getBySetSectionIndexTitles() -> [String] {
        return []
    }
    
    func getBySetAtoZSectionIndexTitles() -> [String] {
        var titles: [String] = []
        for section in bySetAtoZ {
            titles.append("\(SearchIndex.firstCharacterForSet(text: section.title))")
        }
        return titles
    }
    
    func termForPath(_ indexPath: IndexPath, sortSelection: SortSelection) -> SearchTerm {
        var term: SortTerm
        switch (sortSelection) {
        case .atoZ:
            term = AtoZ[indexPath.section].terms[indexPath.row]
        case .bySet:
            term = bySet[indexPath.section].terms[indexPath.row]
        case .bySetAtoZ:
            term = bySetAtoZ[indexPath.section].terms[indexPath.row]
        }
        return SearchTerm(sortTerm: term)
    }

    func exportAtoZ() -> String {
        var data = ""
        for set in AtoZ {
            for term in set.terms {
                data.append(term.termForDisplay.string)
                data.append(BetweenTermAndDefinition)
                data.append(term.definitionForDisplay.string)
                data.append(BetweenRows)
            }
        }
        return data
    }
    
    func exportBySet() -> String {
        var data = ""
        for set in bySet {
            if (!data.isEmpty) {
                data.append(BetweenSets)
            }
            data.append(set.title)
            data.append(BetweenRows)
            for term in set.terms {
                data.append(term.termForDisplay.string)
                data.append(BetweenTermAndDefinition)
                data.append(term.definitionForDisplay.string)
                data.append(BetweenRows)
            }
        }
        return data
    }
    
    func exportBySetAtoZ() -> String {
        var data = ""
        for set in bySetAtoZ {
            if (!data.isEmpty) {
                data.append(BetweenSets)
            }
            data.append(set.title)
            data.append(BetweenRows)
            for term in set.terms {
                data.append(term.termForDisplay.string)
                data.append(BetweenTermAndDefinition)
                data.append(term.definitionForDisplay.string)
                data.append(BetweenRows)
            }
        }
        return data
    }
}

class SearchedSetsAndTerms: SearchedAndSorted {
    var AtoZ: [SortedQuizletSet<SearchTerm>]
    var bySet: [SortedQuizletSet<SearchTerm>]
    var bySetAtoZ: [SortedQuizletSet<SearchTerm>]
    
    var levenshteinMatch: [SearchTerm] = []
    var stringScoreMatch: [SearchTerm] = []
    
    init() {
        AtoZ = []
        bySet = []
        bySetAtoZ = []
    }
    
    init(AtoZ: [SortedQuizletSet<SearchTerm>], bySet: [SortedQuizletSet<SearchTerm>], bySetAtoZ: [SortedQuizletSet<SearchTerm>]) {
        self.AtoZ = AtoZ
        self.bySet = bySet
        self.bySetAtoZ = bySetAtoZ
    }
    
    func getAtoZCount() -> Int {
        return AtoZ.count
    }
    
    func getBySetCount() -> Int {
        return bySet.count
    }
    
    func getBySetAtoZCount() -> Int {
        return bySetAtoZ.count
    }
    
    func getAtoZTermCount(index: Int) -> Int {
        return AtoZ[index].terms.count
    }
    
    func getBySetTermCount(index: Int) -> Int {
        return bySet[index].terms.count
    }
    
    func getBySetAtoZTermCount(index: Int) -> Int {
        return bySetAtoZ[index].terms.count
    }
    
    func getAtoZTitle(index: Int) -> String {
        return AtoZ[index].title
    }
    
    func getBySetTitle(index: Int) -> String {
        return bySet[index].title
    }
    
    func getBySetAtoZTitle(index: Int) -> String {
        return bySetAtoZ[index].title
    }
    
    func getAtoZSectionIndexTitles() -> [String] {
        var titles: [String] = []
        for section in AtoZ {
            titles.append(section.title)
        }
        return titles
    }
    
    func getBySetSectionIndexTitles() -> [String] {
        return []
    }
    
    func getBySetAtoZSectionIndexTitles() -> [String] {
        var titles: [String] = []
        for section in bySetAtoZ {
            titles.append("\(SearchIndex.firstCharacterForSet(text: section.title))")
        }
        return titles
    }
    
    func termForPath(_ indexPath: IndexPath, sortSelection: SortSelection) -> SearchTerm {
        var term: SearchTerm
        switch (sortSelection) {
        case .atoZ:
            term = AtoZ[indexPath.section].terms[indexPath.row]
            /*
             switch (indexPath.section) {
             case 0:
             term = AtoZ[indexPath.row]
             case 1:
             term = (levenshteinMatch.count > 0) ? levenshteinMatch[indexPath.row] : stringScoreMatch[indexPath.row]
             case 2:
             term = stringScoreMatch[indexPath.row]
             default:
             abort()
             }
             */
        case .bySet:
            term = bySet[indexPath.section].terms[indexPath.row]
        case .bySetAtoZ:
            term = bySetAtoZ[indexPath.section].terms[indexPath.row]
        }
        return term
    }

    func exportAtoZ() -> String {
        var data = ""
        for set in AtoZ {
            for term in set.terms {
                data.append(term.sortTerm.termForDisplay.string)
                data.append(BetweenTermAndDefinition)
                data.append(term.sortTerm.definitionForDisplay.string)
                data.append(BetweenRows)
            }
        }
        return data
    }
    
    func exportBySet() -> String {
        var data = ""
        for set in bySet {
            if (!data.isEmpty) {
                data.append(BetweenSets)
            }
            data.append(set.title)
            data.append(BetweenRows)
            for term in set.terms {
                data.append(term.sortTerm.termForDisplay.string)
                data.append(BetweenTermAndDefinition)
                data.append(term.sortTerm.definitionForDisplay.string)
                data.append(BetweenRows)
            }
        }
        return data
    }
    
    func exportBySetAtoZ() -> String {
        var data = ""
        for set in bySetAtoZ {
            if (!data.isEmpty) {
                data.append(BetweenSets)
            }
            data.append(set.title)
            data.append(BetweenRows)
            for term in set.terms {
                data.append(term.sortTerm.termForDisplay.string)
                data.append(BetweenTermAndDefinition)
                data.append(term.sortTerm.definitionForDisplay.string)
                data.append(BetweenRows)
            }
        }
        return data
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

class IndexedSetsAndTerms: SearchedAndSorted {
    typealias TermType = SearchTerm
    
    private var AtoZ: [SortedQuizletSet<SearchTerm>]?
    private var bySet: [SortedQuizletSet<SearchTerm>] = []
    private var bySetAtoZ: [SortedQuizletSet<SearchTerm>]?
    
    private var AtoZTermPair: TermPair! = TermPair()
    private var AtoZIndex: SetIndexReference! = SetIndexReference()
    
    private var bySetTermPair: TermPair! = TermPair()
    private var bySetPair: SetPair! = SetPair()
    
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
    
    func getAtoZCount() -> Int {
        return getAtoZ().count
    }
    
    func getBySetCount() -> Int {
        return getBySet().count
    }
    
    func getBySetAtoZCount() -> Int {
        return getBySetAtoZ().count
    }
    
    func getAtoZTermCount(index: Int) -> Int {
        return getAtoZ()[index].terms.count
    }
    
    func getBySetTermCount(index: Int) -> Int {
        return getBySet()[index].terms.count
    }
    
    func getBySetAtoZTermCount(index: Int) -> Int {
        return getBySetAtoZ()[index].terms.count
    }
    
    func getAtoZTitle(index: Int) -> String {
        return getAtoZ()[index].title
    }
    
    func getBySetTitle(index: Int) -> String {
        return getBySet()[index].title
    }
    
    func getBySetAtoZTitle(index: Int) -> String {
        return getBySetAtoZ()[index].title
    }
    
    func getAtoZSectionIndexTitles() -> [String] {
        var titles: [String] = []
        for section in getAtoZ() {
            titles.append(section.title)
        }
        return titles
    }
    
    func getBySetSectionIndexTitles() -> [String] {
        return []
    }
    
    func getBySetAtoZSectionIndexTitles() -> [String] {
        var titles: [String] = []
        for section in getBySetAtoZ() {
            titles.append("\(SearchIndex.firstCharacterForSet(text: section.title))")
        }
        return titles
    }
    
    func termForPath(_ indexPath: IndexPath, sortSelection: SortSelection) -> SearchTerm {
        var term: SearchTerm
        switch (sortSelection) {
        case .atoZ:
            term = getAtoZ()[indexPath.section].terms[indexPath.row]
        case .bySet:
            term = getBySet()[indexPath.section].terms[indexPath.row]
        case .bySetAtoZ:
            term = getBySetAtoZ()[indexPath.section].terms[indexPath.row]
        }
        return term
    }

    func exportAtoZ() -> String {
        var data = ""
        for set in getAtoZ() {
            for term in set.terms {
                data.append(term.sortTerm.termForDisplay.string)
                data.append(BetweenTermAndDefinition)
                data.append(term.sortTerm.definitionForDisplay.string)
                data.append(BetweenRows)
            }
        }
        return data
    }
    
    func exportBySet() -> String {
        var data = ""
        for set in getBySet() {
            if (!data.isEmpty) {
                data.append(BetweenSets)
            }
            data.append(set.title)
            data.append(BetweenRows)
            for term in set.terms {
                data.append(term.sortTerm.termForDisplay.string)
                data.append(BetweenTermAndDefinition)
                data.append(term.sortTerm.definitionForDisplay.string)
                data.append(BetweenRows)
            }
        }
        return data
    }
    
    func exportBySetAtoZ() -> String {
        var data = ""
        for set in getBySetAtoZ() {
            if (!data.isEmpty) {
                data.append(BetweenSets)
            }
            data.append(set.title)
            data.append(BetweenRows)
            for term in set.terms {
                data.append(term.sortTerm.termForDisplay.string)
                data.append(BetweenTermAndDefinition)
                data.append(term.sortTerm.definitionForDisplay.string)
                data.append(BetweenRows)
            }
        }
        return data
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
            termPair.sortTerm = term
            termPair.searchTerm = searchTerm
            
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
            termPair.sortTerm = term
            termPair.searchTerm = searchTerm
            
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

