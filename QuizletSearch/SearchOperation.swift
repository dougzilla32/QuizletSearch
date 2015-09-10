//
//  SearchOperation.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/9/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation

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
    
    func updateSearchTermsForQuery(var queryString: String) {
        var query = queryString.lowercaseString.decomposeAndNormalize()
        
        if (self.cancelled) {
            return
        }
        
        switch (sortSelection) {
        case .AtoZ:
            searchTerms.AtoZ = searchTermsForQuery(query, terms: sortedTerms.AtoZ)
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
            var options = NSStringCompareOptions.WhitespaceInsensitiveSearch
            
            for term in terms {
                if (self.cancelled) {
                    return []
                }
                
                var termRanges = String.characterRangesOfUnichars(term.termForCompare, targetString: query, options: options)
                var definitionRanges = String.characterRangesOfUnichars(term.definitionForCompare, targetString: query, options: options)
                
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
                    
                    var options = NSStringCompareOptions.WhitespaceInsensitiveSearch
                    var termRanges = String.characterRangesOfUnichars(term.termForCompare, targetString: query, options: options)
                    var definitionRanges = String.characterRangesOfUnichars(term.definitionForCompare, targetString: query, options: options)
                    
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
                var termScore = computeLevenshteinScore(query, sortTerm.termForDisplay.string)
                var definitionScore = computeLevenshteinScore(query, sortTerm.definitionForDisplay.string)
                
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
                var lowercaseQuery = query.lowercaseString
                var termScore = sortTerm.termForDisplay.string.scoreAgainst(lowercaseQuery)
                var definitionScore = sortTerm.definitionForDisplay.string.scoreAgainst(lowercaseQuery)
                
                if (termScore > 0.70 || definitionScore > 0.70) {
                    stringScoreMatch.append(SearchTerm(sortTerm: sortTerm, score: max(termScore, definitionScore)))
                }
            }
        }
        return stringScoreMatch
    }
}
