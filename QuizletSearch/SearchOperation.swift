//
//  SearchOperation.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/9/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation

class SortTerm {
    let termForDisplay: StringWithBoundaries
    let definitionForDisplay: StringWithBoundaries
    
    let termForCompare: StringWithBoundaries
    let definitionForCompare: StringWithBoundaries
    
    init(term: Term) {
        self.termForDisplay = StringWithBoundaries(string: term.term)
        self.definitionForDisplay = StringWithBoundaries(string: term.definition)
        
        self.termForCompare = term.term.lowercaseString.decomposeAndNormalize()
        self.definitionForCompare = term.definition.lowercaseString.decomposeAndNormalize()
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

class SortSet<T> {
    let title: String
    let terms: [T]
    let createdDate: Int64
    
    init(title: String, terms: [T], createdDate: Int64) {
        self.title = title
        self.terms = terms
        self.createdDate = createdDate
    }
}

class SortedTerms<T> {
    // var AtoZ: [T]
    var AtoZ: [SortSet<T>]
    var bySet: [SortSet<T>]
    var bySetAtoZ: [SortSet<T>]
    
    var levenshteinMatch: [T] = []
    var stringScoreMatch: [T] = []
    
    init() {
        AtoZ = []
        bySet = []
        bySetAtoZ = []
    }
    
    init(AtoZ: [SortSet<T>], bySet: [SortSet<T>], bySetAtoZ: [SortSet<T>]) {
        self.AtoZ = AtoZ
        self.bySet = bySet
        self.bySetAtoZ = bySetAtoZ
    }
    
    func termForPath(indexPath: NSIndexPath, sortSelection: SortSelection) -> T {
        var term: T
        switch (sortSelection) {
        case .AtoZ:
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
        case .BySet:
            term = bySet[indexPath.section].terms[indexPath.row]
        case .BySetAtoZ:
            term = bySetAtoZ[indexPath.section].terms[indexPath.row]
        }
        return term
    }
}

class SearchOperation: NSOperation {
    let query: String
    let sortSelection: SortSelection
    let sortedTerms: SortedTerms<SortTerm>
    
    let searchTerms = SortedTerms<SearchTerm>()
    
    init(query: String, sortSelection: SortSelection, sortedTerms: SortedTerms<SortTerm>) {
        self.query = query
        self.sortSelection = sortSelection
        self.sortedTerms = sortedTerms
    }
    
    override func main() {
        updateSearchTermsForQuery(query)
    }
    
    func updateSearchTermsForQuery(queryString: String) {
        let query = queryString.lowercaseString.decomposeAndNormalize()
        
        if (self.cancelled) {
            return
        }
        
        switch (sortSelection) {
        case .AtoZ:
            searchTerms.AtoZ = searchTermsBySetForQuery(query, termsBySet: sortedTerms.AtoZ)
            // searchTerms.AtoZ = searchTermsForQuery(query, terms: sortedTerms.AtoZ)
            // searchTerms.levenshteinMatch = SearchViewController.levenshteinMatchForQuery(query, terms: sortedTerms.AtoZ)
            // searchTerms.stringScoreMatch = SearchViewController.stringScoreMatchForQuery(query, terms: sortedTerms.AtoZ)
        case .BySet:
            searchTerms.bySet = searchTermsBySetForQuery(query, termsBySet: sortedTerms.bySet)
        case .BySetAtoZ:
            searchTerms.bySetAtoZ = searchTermsBySetForQuery(query, termsBySet: sortedTerms.bySetAtoZ)
        }
    }
    
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
    
    func searchTermsBySetForQuery(query: StringWithBoundaries, termsBySet: [SortSet<SortTerm>]) -> [SortSet<SearchTerm>] {
        var searchTermsBySet: [SortSet<SearchTerm>] = []
        if (query.string.isWhitespace()) {
            for quizletSet in termsBySet {
                var termsForSet = [SearchTerm]()
                for term in quizletSet.terms {
                    termsForSet.append(SearchTerm(sortTerm: term))
                }
                searchTermsBySet.append(SortSet<SearchTerm>(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))
            }
        } else {
            for quizletSet in termsBySet {
                var termsForSet = [SearchTerm]()
                
                for term in quizletSet.terms {
                    if (self.cancelled) {
                        return []
                    }
                    
                    let options = NSStringCompareOptions.WhitespaceInsensitiveSearch
                    let termRanges = String.characterRangesOfUnichars(term.termForCompare, targetString: query, options: options)
                    let definitionRanges = String.characterRangesOfUnichars(term.definitionForCompare, targetString: query, options: options)
                    
                    if (termRanges.count > 0 || definitionRanges.count > 0) {
                        termsForSet.append(SearchTerm(sortTerm: term,
                            score: 0.0,
                            termRanges: term.termForDisplay.characterRangesToUnicharRanges(termRanges),
                            definitionRanges: term.definitionForDisplay.characterRangesToUnicharRanges(definitionRanges)))
                    }
                }
                
                if (termsForSet.count > 0) {
                    searchTermsBySet.append(SortSet<SearchTerm>(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))
                }
            }
        }
        return searchTermsBySet
    }
    
    class func levenshteinMatchForQuery(query: String, sortTerms: [SortTerm]) -> [SearchTerm] {
        var levenshteinMatch: [SearchTerm] = []
        if (!query.isWhitespace()) {
            for sortTerm in sortTerms {
                let termScore = computeLevenshteinScore(query, target: sortTerm.termForDisplay.string)
                let definitionScore = computeLevenshteinScore(query, target: sortTerm.definitionForDisplay.string)
                
                if (termScore > 0.70 || definitionScore > 0.70) {
                    levenshteinMatch.append(SearchTerm(sortTerm: sortTerm, score: max(termScore, definitionScore)))
                }
            }
        }
        return levenshteinMatch
    }
    
    class func stringScoreMatchForQuery(query: String, sortTerms: [SortTerm]) -> [SearchTerm] {
        var stringScoreMatch: [SearchTerm] = []
        if (!query.isWhitespace()) {
            for sortTerm in sortTerms {
                let lowercaseQuery = query.lowercaseString
                let termScore = sortTerm.termForDisplay.string.scoreAgainst(lowercaseQuery)
                let definitionScore = sortTerm.definitionForDisplay.string.scoreAgainst(lowercaseQuery)
                
                if (termScore > 0.70 || definitionScore > 0.70) {
                    stringScoreMatch.append(SearchTerm(sortTerm: sortTerm, score: max(termScore, definitionScore)))
                }
            }
        }
        return stringScoreMatch
    }
}
