//
//  SearchOperation.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/9/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit
import CoreData
import Foundation

class SortTerm {
    let termForDisplay: StringWithBoundaries
    let definitionForDisplay: StringWithBoundaries
    
    let termForCompare: StringWithBoundaries
    let definitionForCompare: StringWithBoundaries
    
    init(term: Term) {
        self.termForDisplay = StringWithBoundaries(string: term.term)
        self.definitionForDisplay = StringWithBoundaries(string: term.definition)
        
        self.termForCompare = term.term.lowercased().decomposeAndNormalize()
        self.definitionForCompare = term.definition.lowercased().decomposeAndNormalize()
    }
}

class SearchTerm {
    let sortTerm: SortTerm
    let score: Double
    let termRanges: [NSRange]
    let definitionRanges: [NSRange]
    
    init(sortTerm: SortTerm, score: Double = 0.0, termRanges: [NSRange] = [], definitionRanges: [NSRange] = []) {
        self.sortTerm = sortTerm
        self.score = score
        self.termRanges = termRanges
        self.definitionRanges = definitionRanges
    }
}

class SortedQuizletSet<T> {
    let title: String
    let terms: [T]
    let createdDate: Int64
    
    init(title: String, terms: [T], createdDate: Int64) {
        self.title = title
        self.terms = terms
        self.createdDate = createdDate
    }
}

class SortedSetsAndTerms<T> {
    // var AtoZ: [T]
    var AtoZ: [SortedQuizletSet<T>]
    var bySet: [SortedQuizletSet<T>]
    var bySetAtoZ: [SortedQuizletSet<T>]
    
    var levenshteinMatch: [T] = []
    var stringScoreMatch: [T] = []
    
    init() {
        AtoZ = []
        bySet = []
        bySetAtoZ = []
    }
    
    init(AtoZ: [SortedQuizletSet<T>], bySet: [SortedQuizletSet<T>], bySetAtoZ: [SortedQuizletSet<T>]) {
        self.AtoZ = AtoZ
        self.bySet = bySet
        self.bySetAtoZ = bySetAtoZ
    }
    
    func termForPath(_ indexPath: IndexPath, sortSelection: SortSelection) -> T {
        var term: T
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
}

class SearchOperation: Operation {
    let query: String
    let sortSelection: SortSelection
    let allTerms: SortedSetsAndTerms<SortTerm>
    
    let searchTerms = SortedSetsAndTerms<SearchTerm>()
    
    init(query: String, sortSelection: SortSelection, allTerms: SortedSetsAndTerms<SortTerm>) {
        self.query = query
        self.sortSelection = sortSelection
        self.allTerms = allTerms
    }
    
    override func main() {
        updateSearchTermsForQuery(query)
    }
    
    func updateSearchTermsForQuery(_ queryString: String) {
        let query = queryString.lowercased().decomposeAndNormalize()
        
        if (self.isCancelled) {
            return
        }
        
        switch (sortSelection) {
        case .atoZ:
            searchTerms.AtoZ = searchTermsBySetForQuery(query, sortTermsBySet: allTerms.AtoZ)
            // searchTerms.AtoZ = searchTermsForQuery(query, terms: sortedTerms.AtoZ)
            // searchTerms.levenshteinMatch = SearchViewController.levenshteinMatchForQuery(query, terms: sortedTerms.AtoZ)
            // searchTerms.stringScoreMatch = SearchViewController.stringScoreMatchForQuery(query, terms: sortedTerms.AtoZ)
        case .bySet:
            searchTerms.bySet = searchTermsBySetForQuery(query, sortTermsBySet: allTerms.bySet)
        case .bySetAtoZ:
            searchTerms.bySetAtoZ = searchTermsBySetForQuery(query, sortTermsBySet: allTerms.bySetAtoZ)
        }
    }
    
    /*
    func searchTermsForQuery(query: StringWithBoundaries, terms: [SortTerm]) -> [SearchTerm] {
        var searchTerms: [SearchTerm] = []
        if (query.string.isWhitespace()) {
            for term in terms {
                searchTerms.append(SearchTerm(sortTerm: term))
            }
        } else {
            let options = NSStringCompareOptions.WhitespaceInsensitiveSearch
            
            for term in terms {
                if (self.cancelled) {
                    return []
                }
                
                let termRanges = String.characterRangesOfUnichars(term.termForCompare, targetString: query, options: options)
                let definitionRanges = String.characterRangesOfUnichars(term.definitionForCompare, targetString: query, options: options)
                
                if (termRanges.count > 0 || definitionRanges.count > 0) {
                    searchTerms.append(SearchTerm(sortTerm: term,
                        score: 0.0,
                        termRanges: term.termForDisplay.characterRangesToUnicharRanges(termRanges),
                        definitionRanges: term.definitionForDisplay.characterRangesToUnicharRanges(definitionRanges)))
                }
            }
        }
        return searchTerms
    }
    */
    
    func searchTermsBySetForQuery(_ query: StringWithBoundaries, sortTermsBySet: [SortedQuizletSet<SortTerm>]) -> [SortedQuizletSet<SearchTerm>] {
        var searchTermsBySet: [SortedQuizletSet<SearchTerm>] = []
        if (query.string.isWhitespace()) {
            for quizletSet in sortTermsBySet {
                var searchTermsForSet = [SearchTerm]()
                for term in quizletSet.terms {
                    searchTermsForSet.append(SearchTerm(sortTerm: term))
                }
                searchTermsBySet.append(SortedQuizletSet<SearchTerm>(title: quizletSet.title, terms: searchTermsForSet, createdDate: quizletSet.createdDate))
            }
        } else {
            for quizletSet in sortTermsBySet {
                var searchTermsForSet = [SearchTerm]()
                
                for term in quizletSet.terms {
                    if (self.isCancelled) {
                        return []
                    }
                    
                    let options = NSString.CompareOptions.WhitespaceInsensitiveSearch
                    let termRanges = String.characterRangesOfUnichars(term.termForCompare, targetString: query, options: options)
                    let definitionRanges = String.characterRangesOfUnichars(term.definitionForCompare, targetString: query, options: options)
                    
                    if (termRanges.count > 0 || definitionRanges.count > 0) {
                        searchTermsForSet.append(SearchTerm(sortTerm: term,
                            score: 0.0,
                            termRanges: term.termForDisplay.characterRangesToUnicharRanges(termRanges),
                            definitionRanges: term.definitionForDisplay.characterRangesToUnicharRanges(definitionRanges)))
                    }
                }
                
                if (searchTermsForSet.count > 0) {
                    searchTermsBySet.append(SortedQuizletSet<SearchTerm>(title: quizletSet.title, terms: searchTermsForSet, createdDate: quizletSet.createdDate))
                }
            }
        }
        return searchTermsBySet
    }
    
    func searchTermsBySetForQuery(_ query: StringWithBoundaries, termsTable: [String: SortedQuizletSet<SearchTerm>]) -> [SortedQuizletSet<SearchTerm>] {
        return []
    }
    
    class func initSortedTerms() -> SortedSetsAndTerms<SortTerm> {
        var AtoZterms: [SortTerm] = []
        var AtoZ: [SortedQuizletSet<SortTerm>] = []
        var bySet: [SortedQuizletSet<SortTerm>] = []
        var bySetAtoZ: [SortedQuizletSet<SortTerm>] = []
        
        if let query = (UIApplication.shared.delegate as! AppDelegate).dataModel.currentQuery {
            for set in query.sets {
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

    class func levenshteinMatchForQuery(_ query: String, sortTerms: [SortTerm]) -> [SearchTerm] {
        var levenshteinMatch: [SearchTerm] = []
        if (!query.isWhitespace()) {
            for sortTerm in sortTerms {
                let termScore = computeLevenshteinScore(query, target: sortTerm.termForDisplay.string)
                let definitionScore = computeLevenshteinScore(query, target: sortTerm.definitionForDisplay.string)
                
                if (termScore > 0.70 || definitionScore > 0.70) {
                    levenshteinMatch.append(SearchTerm(sortTerm: sortTerm, score: Swift.max(termScore, definitionScore)))
                }
            }
        }
        return levenshteinMatch
    }
    
    class func stringScoreMatchForQuery(_ query: String, sortTerms: [SortTerm]) -> [SearchTerm] {
        var stringScoreMatch: [SearchTerm] = []
        if (!query.isWhitespace()) {
            for sortTerm in sortTerms {
                let lowercaseQuery = query.lowercased() as NSString
                let termScore = sortTerm.termForDisplay.string.scoreAgainst(lowercaseQuery)
                let definitionScore = sortTerm.definitionForDisplay.string.scoreAgainst(lowercaseQuery)
                
                if (termScore > 0.70 || definitionScore > 0.70) {
                    stringScoreMatch.append(SearchTerm(sortTerm: sortTerm, score: Swift.max(termScore, definitionScore)))
                }
            }
        }
        return stringScoreMatch
    }
}
