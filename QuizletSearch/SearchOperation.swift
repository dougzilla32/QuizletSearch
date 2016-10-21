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

class SortedTerms<T> {
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
    
    func updateSearchTermsForQuery(_ queryString: String) {
        let query = queryString.lowercased().decomposeAndNormalize()
        
        if (self.isCancelled) {
            return
        }
        
        switch (sortSelection) {
        case .atoZ:
            searchTerms.AtoZ = searchTermsBySetForQuery(query, sortTermsBySet: sortedTerms.AtoZ)
            // searchTerms.AtoZ = searchTermsForQuery(query, terms: sortedTerms.AtoZ)
            // searchTerms.levenshteinMatch = SearchViewController.levenshteinMatchForQuery(query, terms: sortedTerms.AtoZ)
            // searchTerms.stringScoreMatch = SearchViewController.stringScoreMatchForQuery(query, terms: sortedTerms.AtoZ)
        case .bySet:
            searchTerms.bySet = searchTermsBySetForQuery(query, sortTermsBySet: sortedTerms.bySet)
        case .bySetAtoZ:
            searchTerms.bySetAtoZ = searchTermsBySetForQuery(query, sortTermsBySet: sortedTerms.bySetAtoZ)
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
