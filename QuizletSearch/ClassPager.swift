//
//  ClassPager.swift
//  QuizletSearch
//
//  Created by Doug on 11/13/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import Foundation

class ClassPager: Pager<QClass> {
    override func invokeQuery(page: Int, resetToken: Int, completionHandler: @escaping (_ affectedResults: CountableRange<Int>?, _ totalResults: Int?, _ response: PagerResponse) -> Void) {
        paginationSize = PagerConstants.DefaultPaginationSize
        
        self.quizletSession.searchClassesWithQuery(self.query, page: page, perPage: self.paginationSize, allowCellularAccess: true, completionHandler: { (queryResult: QueryResult<QClass>?, response: URLResponse?, error: Error?) in
            
            trace("SEARCH CLASSES OUT", self.query, resetToken)
            if (queryResult == nil || resetToken < self.resetCounter) {
                // Cancelled or error - if cancelled do nothing, instead just let the subsequent request fill in the rows
                self.loadingPages.remove(page)
                return
            }
            
            self.loadPageResult(queryResult!, response: .partial, page: page, resetToken: resetToken, completionHandler: completionHandler)
        })
    }
    
    override func emptyItem() -> QClass {
        return QClass(id: 0, name: "", setCount: 0, userCount: 0, createdDate: 0, adminOnly: false, hasAccess: false, accessLevel: "", description: "")
    }
}
