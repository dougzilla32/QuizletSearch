//
//  SearchOperation.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/9/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation

class SearchOperation: Operation {
    let query: StringWithBoundaries
    let sortSelection: SortSelection
    let allTerms: IndexedSetsAndTerms
    
    let searchTerms = SearchedSetsAndTerms()
    
    init(query: StringWithBoundaries, sortSelection: SortSelection, allTerms: IndexedSetsAndTerms) {
        self.query = query
        self.sortSelection = sortSelection
        self.allTerms = allTerms
    }
    
    override func main() {
        updateSearchTermsForQuery(query)
    }
    
    func updateSearchTermsForQuery(_ query: StringWithBoundaries) {
        if (self.isCancelled) {
            return
        }
        
        switch (sortSelection) {
        case .atoZ:
            searchTerms.AtoZ = searchTermsBySetForQuery(query, sortTermsBySet: allTerms.getAtoZ())
            // searchTerms.AtoZ = searchTermsForQuery(query, terms: sortedTerms.AtoZ)
            // searchTerms.levenshteinMatch = SearchViewController.levenshteinMatchForQuery(query, terms: sortedTerms.AtoZ)
            // searchTerms.stringScoreMatch = SearchViewController.stringScoreMatchForQuery(query, terms: sortedTerms.AtoZ)
        case .bySet:
            searchTerms.bySet = searchTermsBySetForQuery(query, sortTermsBySet: allTerms.getBySet())
        case .bySetAtoZ:
            searchTerms.bySetAtoZ = searchTermsBySetForQuery(query, sortTermsBySet: allTerms.getBySetAtoZ())
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
    
    func searchTermsBySetForQuery(_ query: StringWithBoundaries, sortTermsBySet: [SortedQuizletSet<SearchTerm>]) -> [SortedQuizletSet<SearchTerm>] {
        var searchTermsBySet: [SortedQuizletSet<SearchTerm>] = []
        if (query.string.isWhitespace()) {
            for quizletSet in sortTermsBySet {
                var searchTermsForSet = [SearchTerm]()
                for term in quizletSet.terms {
                    searchTermsForSet.append(term)
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
                    let termRanges = StringWithBoundaries.characterRangesOfUnichars(term.sortTerm.termForCompare, targetString: query, options: options)
                    let definitionRanges = StringWithBoundaries.characterRangesOfUnichars(term.sortTerm.definitionForCompare, targetString: query, options: options)
                    
                    if (termRanges.count > 0 || definitionRanges.count > 0) {
                        searchTermsForSet.append(SearchTerm(sortTerm: term.sortTerm,
//                            score: 0.0,
                            termRanges: term.sortTerm.termForDisplay.characterRangesToUnicharRanges(termRanges),
                            definitionRanges: term.sortTerm.definitionForDisplay.characterRangesToUnicharRanges(definitionRanges)))
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
    
    class func levenshteinMatchForQuery(_ query: String, sortTerms: [SortTerm]) -> [SearchTerm] {
        var levenshteinMatch: [SearchTerm] = []
        if (!query.isWhitespace()) {
            for sortTerm in sortTerms {
                let termScore = computeLevenshteinScore(query, target: sortTerm.termForDisplay.string)
                let definitionScore = computeLevenshteinScore(query, target: sortTerm.definitionForDisplay.string)
                
                if (termScore > 0.70 || definitionScore > 0.70) {
                    levenshteinMatch.append(SearchTerm(sortTerm: sortTerm
//                                                       score: Swift.max(termScore, definitionScore)
                    ))
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
                    stringScoreMatch.append(SearchTerm(sortTerm: sortTerm
//                                                       score: Swift.max(termScore, definitionScore)
                    ))
                }
            }
        }
        return stringScoreMatch
    }
}
