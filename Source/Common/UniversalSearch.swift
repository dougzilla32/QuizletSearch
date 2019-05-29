//
//  UniversalSearch.swift
//  QuizletSearch
//
//  Created by Doug on 11/26/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import UIKit

class UniversalSearch {
    let MaxTermCount = 5000
    let MaxCharacters = 1000000
    let MaxTotalResults = 300
    
    let quizletSession = (UIApplication.shared.delegate as! AppDelegate).dataModel.quizletSession
    
    var pager: UniversalPager
    
    var totalResults: Int?
    var totalResultsNoMax: Int?
    
    func updateTotals() {
        var total = 0
        var stillLoading = false
        if let t = pager.totalResults {
            total = t
        }
        else {
            stillLoading = true
        }

        totalResults = (stillLoading && total == 0) ? nil : Swift.min(total, MaxTotalResults)
        totalResultsNoMax = (stillLoading && total == 0) ? nil : total
    }
    
    init() {
        pager = UniversalPager(query: nil)
    }
    
    convenience init(query: String?) {
        self.init()
        
        updateQuery(query)
        
    }
    
    // MARK: - Query
    
    func updateQuery(_ query: String?) {
        pager.reset(query: query)
    }
    
    func executeFullSearch(completionHandler: @escaping ([QItem]?) -> Void) {
        trace("executeFullSearch START")
        
        // Cancel previous queries
        quizletSession.cancelQueryTasks()
        
        let qitems = [QItem]()
        loadNextPage(currentPageNumber: 1, qitems: qitems, completionHandler: completionHandler)
    }
    
    func loadNextPage(currentPageNumber: Int, qitems qitemsParam: [QItem], completionHandler: @escaping ([QItem]?) -> Void) {
        var qitems = qitemsParam
        
        if (!pager.enabled) {
            trace("executeFullSearch COMPLETE qitems.count:", qitems.count)
            completionHandler(qitems)
            return
        }
        
        trace("loadNextPage query:", pager.query ?? "nil")
        
        pager.pagerPause = Int64(NSEC_PER_SEC/10000)
        
        pager.loadPage(currentPageNumber, completionHandler: { [unowned self] (affectedRows: CountableRange<Int>?, totalResults: Int?, response: PagerResponse) -> Void in
            if (response != .complete) {
                return
            }
            
            let newQSets = self.pager.items?[currentPageNumber-1]
            self.pager.items?[currentPageNumber-1] = nil

            if (newQSets != nil) {
                for item in newQSets! {
                    qitems.append(item)
                }
            }

            if (newQSets == nil || currentPageNumber >= (self.pager.totalPages ?? 0)) {
                trace("executeFullSearch COMPLETE qitems.count:", qitems.count)
                completionHandler(qitems)
            }
            else {
                self.loadNextPage(currentPageNumber: currentPageNumber + 1, qitems: qitems, completionHandler: completionHandler)
            }
        })
    }
    
    func executeSearch(_ pagerIndex: Int?, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        // Cancel previous queries
        quizletSession.cancelQueryTasks()
        
        loadFirstPages(completionHandler: completionHandler)
    }
    
    func loadFirstPages(completionHandler: @escaping (_ affectedRows: CountableRange<Int>, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        pager.pagerPause = PagerConstants.DefaultPagerPause
            
        pager.loadPage(1, completionHandler: { (affectedRows: CountableRange<Int>?, totalResults: Int?, response: PagerResponse) -> Void in
            self.loadComplete(affectedRows: affectedRows, totalResults: totalResults, response: response, completionHandler: completionHandler)
        })
    }
    
    func loadComplete(affectedRows: CountableRange<Int>?, totalResults: Int?, response: PagerResponse, completionHandler: (_ affectedRows: CountableRange<Int>, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        self.updateTotals()
        
        var r = affectedRows!
        if (r.lowerBound >= MaxTotalResults) {
            return
        }
        r = r.clamped(to: 0..<Swift.min(r.upperBound, MaxTotalResults))
        
        completionHandler(
            r,
            self.totalResults,
            response)
    }
    
    func isLoading() -> Bool {
        return pager.isLoading()
    }
    
    func peekQItemForRow(_ row: Int) -> QItem? {
        if (row >= MaxTotalResults) {
            return nil
        }
        
        return pager.peekItemForRow(row)
    }
    
    func getQItemForRow(_ row: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) -> QItem? {
        if (row >= MaxTotalResults) {
            return nil
        }
        
        if let t = pager.totalResults {
            if case 0..<t = row {
                return pager.getItemForRow(row, completionHandler: { (affectedRows: CountableRange<Int>?, totalResults: Int?, response: PagerResponse) -> Void in
                    self.loadComplete(affectedRows: affectedRows, totalResults: totalResults, response: response, completionHandler: completionHandler)
                })
            }
        }
        return nil
    }
    
}
