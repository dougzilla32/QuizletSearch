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
    let allTermsSorted: SortedSetsAndTerms?
    let allTermsIndexed: IndexedSetsAndTerms?
    
    let searchTerms = SearchedSetsAndTerms()
    
    init(query: StringWithBoundaries, sortSelection: SortSelection, allTermsSorted: SortedSetsAndTerms) {
        self.query = query
        self.sortSelection = sortSelection
        self.allTermsSorted = allTermsSorted
        self.allTermsIndexed = nil
    }
    
    init(query: StringWithBoundaries, sortSelection: SortSelection, allTermsIndexed: IndexedSetsAndTerms) {
        self.query = query
        self.sortSelection = sortSelection
        self.allTermsIndexed = allTermsIndexed
        self.allTermsSorted = nil
    }
    
    override func main() {
        updateSearchTermsForQuery(query)
    }
    
    func updateSearchTermsForQuery(_ query: StringWithBoundaries) {
        if (self.isCancelled) {
            return
        }
        
        if (allTermsSorted != nil) {
            switch (sortSelection) {
            case .atoZ:
                searchTerms.AtoZ = searchTermsBySetForQuery(query, sortTermsBySet: allTermsSorted!.AtoZ)
            case .bySet:
                searchTerms.bySet = searchTermsBySetForQuery(query, sortTermsBySet: allTermsSorted!.bySet)
            case .bySetAtoZ:
                searchTerms.bySetAtoZ = searchTermsBySetForQuery(query, sortTermsBySet: allTermsSorted!.bySetAtoZ)
            }
        }
        else {
            switch (sortSelection) {
            case .atoZ:
                searchTerms.AtoZ = searchTermsBySetForQuery(query, searchTermsBySet: allTermsIndexed!.getAtoZ())
            case .bySet:
                searchTerms.bySet = searchTermsBySetForQuery(query, searchTermsBySet: allTermsIndexed!.getBySet())
            case .bySetAtoZ:
                searchTerms.bySetAtoZ = searchTermsBySetForQuery(query, searchTermsBySet: allTermsIndexed!.getBySetAtoZ())
            }
        }
    }
    
    func searchTermsBySetForQuery(_ query: StringWithBoundaries, sortTermsBySet: [SortedQuizletSet<SortTerm>]) -> [SortedQuizletSet<SearchTerm>] {
        var result: [SortedQuizletSet<SearchTerm>] = []
        if (query.string.isWhitespace()) {
            for quizletSet in sortTermsBySet {
                var searchTermsForSet = [SearchTerm]()
                for term in quizletSet.terms {
                    searchTermsForSet.append(SearchTerm(sortTerm: term))
                }
                result.append(SortedQuizletSet<SearchTerm>(title: quizletSet.title, terms: searchTermsForSet, createdDate: quizletSet.createdDate))
            }
        } else {
            for quizletSet in sortTermsBySet {
                var searchTermsForSet = [SearchTerm]()
                
                for term in quizletSet.terms {
                    if (self.isCancelled) {
                        return []
                    }
                    
                    let options = NSString.CompareOptions.WhitespaceInsensitiveSearch
                    let termRanges = StringWithBoundaries.characterRangesOfUnichars(term.termForCompare, targetString: query, options: options)
                    let definitionRanges = StringWithBoundaries.characterRangesOfUnichars(term.definitionForCompare, targetString: query, options: options)
                    
                    if (termRanges.count > 0 || definitionRanges.count > 0) {
                        searchTermsForSet.append(SearchTerm(sortTerm: term,
                            // score: 0.0,
                            termRanges: term.termForDisplay.characterRangesToUnicharRanges(termRanges),
                            definitionRanges: term.definitionForDisplay.characterRangesToUnicharRanges(definitionRanges)))
                    }
                }
                
                if (searchTermsForSet.count > 0) {
                    result.append(SortedQuizletSet<SearchTerm>(title: quizletSet.title, terms: searchTermsForSet, createdDate: quizletSet.createdDate))
                }
            }
        }
        return result
    }
    
    func searchTermsBySetForQuery(_ query: StringWithBoundaries, searchTermsBySet: [SortedQuizletSet<SearchTerm>]) -> [SortedQuizletSet<SearchTerm>] {
        var result: [SortedQuizletSet<SearchTerm>] = []
        if (query.string.isWhitespace()) {
            result = searchTermsBySet
        } else {
            for quizletSet in searchTermsBySet {
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
                            // score: 0.0,
                            termRanges: term.sortTerm.termForDisplay.characterRangesToUnicharRanges(termRanges),
                            definitionRanges: term.sortTerm.definitionForDisplay.characterRangesToUnicharRanges(definitionRanges)))
                    }
                }
                
                if (searchTermsForSet.count > 0) {
                    result.append(SortedQuizletSet<SearchTerm>(title: quizletSet.title, terms: searchTermsForSet, createdDate: quizletSet.createdDate))
                }
            }
        }
        return result
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
