//
//  UserPager.swift
//  QuizletSearch
//
//  Created by Doug on 11/13/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import Foundation

class UniversalPager: Pager<QItem> {
    override func invokeQuery(page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        paginationSize = PagerConstants.DefaultPaginationSize
        
        self.quizletSession.searchUniversalWithQuery(self.query, page: page, perPage: self.paginationSize, allowCellularAccess: true, completionHandler: { (queryResult: QueryResult<QItem>?, response: URLResponse?, error: Error?) in
            
            trace("SEARCH UNIVERSAL OUT", self.query, resetToken)
            
            // Convert queryResult: QueryResult<QItem> to QueryResult<QUser> by omitting matching classes and sets
            // Problem: need to keep calling searchUniversalWithQuery until we get some users!

            if (queryResult == nil || resetToken < self.resetCounter) {
                // Cancelled or error - if cancelled do nothing, instead just let the subsequent request fill in the rows
                self.loadingPages.remove(page)
                return
            }
            
            self.loadPageResult(queryResult!, response: .partial, page: page, resetToken: resetToken, completionHandler: completionHandler)
        })
    }
    
    override func emptyItem() -> QItem {
        return QUser(userName: "", accountType: .free, profileImage: URL(string: "http:")!, signUpDate: 0)
    }
}
