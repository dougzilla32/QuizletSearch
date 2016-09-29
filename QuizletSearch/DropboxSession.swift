//
//  DropboxSession.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/17/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit
import Foundation

//
// Note: NSURLComponents does not percent-escape the following characters which causes
// problems while parsing the response: '&' ';'
//
class DropboxSession {
    let dropboxAppKey = "ky4ns2i5loah5lx"
    let dropboxAppSecret = "3x1g8g5b6zj2grc"
    let dropboxRedirectUri = "byteclub://userauthorization"
    let dropboxState = "wied3GnmHFs_wer_asdWDSWEfWe"
    // Dropbox does not properly handle unicode percent escaping, it double-escapes them in the response
    // let dropboxState = "wied3GnmHFs%<>,.:!@/#$/%^*()_+-={}|[]\\?/~"
    
    var dropboxAccessToken: String?

    // Dropbox authorize parameters:
    //
    // response_type    : "token" or "code"
    // client_id        : app key
    // redirect_uri     : app URI
    // state            : arbitrary data
    // require_role     : "work" or "personal"
    // force_reapprove  : true or false
    // disable_signup   : true or false
    //
    func authorizeURL() -> URL {
        var url = URLComponents()
        url.scheme = "https"
        url.host = "www.dropbox.com"
        url.path = "/1/oauth2/authorize"
        url.queryItems = [
            URLQueryItem(name: "response_type", value: "token"),
            URLQueryItem(name: "client_id", value: dropboxAppKey),
            URLQueryItem(name: "redirect_uri", value: dropboxRedirectUri),
            URLQueryItem(name: "state", value: dropboxState)
        ]
        
        return url.url!
    }
    
    // Dropbox authorize response parameters:
    //
    // access_token : access token used to make dropbox calls
    // token_type   : "bearer"
    // uid          : user id
    // state        : should match state from request
    //
    func acquireAccessToken(_ url: URL) {
        // The URL fragment contains the "/1/oauth2/authorize" response parameters
        let fragment = url.fragment
        if (fragment == nil) {
            NSLog("Fragment is missing from authorize response: \(url)")
            return
        }
        
        // Parse the response parameters
        var parseFragment = URLComponents()
        parseFragment.percentEncodedQuery = fragment
        var responseParams = [String: String]()
        for item in parseFragment.queryItems! {
            let queryItem = item 
            responseParams[queryItem.name] = queryItem.value
        }
        
        // Check the state to prevent cross-site request forgery (CSRF) attacks
        let state = responseParams["state"]
        if (state == nil) {
            NSLog("Parameter \"state\" missing from authorize response: \(url)")
            return
        }
        if (state != dropboxState) {
            NSLog("State mismatch between authorize request and response, possible CSRF attack: \(state!)")
            return
        }
        
        // Check if the response contains an error message
        let responseError = responseParams["error"]
        if (responseError != nil) {
            NSLog("Error: \(responseError!)")
            let responseErrorDescription = responseParams["error_description"]
            if (responseErrorDescription != nil) {
                NSLog(responseErrorDescription!.replacingOccurrences(of: "+", with: " "))
            }
            return
        }
        
        // Sanity check the response parameters
        let accessToken = responseParams["access_token"]
        if (accessToken == nil) {
            NSLog("Parameter \"access_token\" missing from authorize response: \(url)")
            return
        }
        let tokenType = responseParams["token_type"]
        if (tokenType != "bearer") {
            NSLog("Unexpected token type \"\(tokenType)\" in authorize response: \(url)")
            return
        }
        
        dropboxAccessToken = accessToken
        print("We have the access token!  Success! \(accessToken!)")
    }
}
