//
//  QuizletSession.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/17/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation
import AVFoundation

//
// Note: NSURLComponents does not percent-escape the following characters which causes
// problems while parsing the response: '&' ';'
//
class QuizletSession {
    let quizletClientId = "ZwGccNSqZJ"
    let quizletSecretKey = "Jq2xbvn55EaJwhqbtMvtem"
    let quizletRedirectUri = "quizletsearch://userauthorization"
    let quizletState = "qW3Ecv34asdf4/aseErBw34gs="
    
    var currentUser: UserAccount?
    
    class Task {
        let task: NSURLSessionDataTask
        let description: String
        
        init(task: NSURLSessionDataTask, description: String) {
            self.task = task
            self.description = description
        }
    }
    
    private var currentTokenTask: Task?
    private var currentQueryTask: Task?

    func close() {
        for task in [ currentTokenTask, currentQueryTask ] {
            if (task != nil) {
                NSLog("Canceling task: \(task!.description)")
                task!.task.cancel()
            }
        }
        currentTokenTask = nil
        currentQueryTask = nil
    }
    
    // Quizlet authorize parameters:
    //
    // scope            : "read", "write_set", and/or "write_group"
    // client_id        : client id
    // response_type    : must be "code"
    // state            : arbitrary data
    // redirect_uri     : app URI
    //
    func authorizeURL() -> NSURL {
        var url = NSURLComponents()
        url.scheme = "https"
        url.host = "www.quizlet.com"
        url.path = "/authorize"
        url.queryItems = [
            NSURLQueryItem(name: "scope", value: "read"),
            NSURLQueryItem(name: "client_id", value: quizletClientId),
            NSURLQueryItem(name: "response_type", value: "code"),
            NSURLQueryItem(name: "redirect_uri", value: quizletRedirectUri),
            NSURLQueryItem(name: "state", value: quizletState)
        ]
        
        return url.URL!
    }
    
    // Acquire token parameters:
    //
    // grant_type       : "authorization_code"
    // code             : code from authorize response
    // redirect_uri     : check for match with authorize call
    //
    // Include HTTP basic authorization containing the client ID and secret
    //
    func acquireAccessToken(url: NSURL,
        completionHandler: (userAccount: UserAccount?, error: NSError?) -> Void) {
            
        // The URL query contains the "/oauth/authorize" response parameters
        if (url.query == nil) {
            NSLog("Query is missing from authorize response: \(url)")
            return
        }
        
        // Parse the response parameters
        var parseQuery = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
        var responseParams = [String: String]()
        for item in parseQuery!.queryItems! {
            var queryItem = item as! NSURLQueryItem
            responseParams[queryItem.name] = queryItem.value
        }
        
        // Check the state to prevent cross-site request forgery (CSRF) attacks
        var state = responseParams["state"]
        if (state == nil) {
            NSLog("Parameter \"state\" missing from authorize response: \(url)")
            return
        }
        if (state != quizletState) {
            NSLog("State mismatch between authorize request and response, possible CSRF attack: \(state!)")
            return
        }
        
        // Check if the response contains an error message
        var responseError = responseParams["error"]
        if (responseError != nil) {
            var responseErrorDescription = responseParams["error_description"]
            if (responseErrorDescription != nil) {
                responseErrorDescription = responseErrorDescription!.stringByReplacingOccurrencesOfString("+", withString: " ")
            } else {
                responseErrorDescription = "Unable to complete login"
            }

            var error = NSError(domain: responseError!, code: 0,
                userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString(responseError!, comment: ""),
                    NSLocalizedFailureReasonErrorKey: responseErrorDescription!
                ])
            completionHandler(userAccount: nil, error: error)
            return
        }
    
        // Sanity check the response parameters
        var code = responseParams["code"]
        if (code == nil) {
            NSLog("Parameter \"code\" missing from authorize response: \(url)")
            return
        }
        
        var url = NSURLComponents()
        url.scheme = "https"
        url.host = "api.quizlet.com"
        url.path = "/oauth/token"
        
        var parameters = NSURLComponents()
        parameters.queryItems = [
            NSURLQueryItem(name: "grant_type", value: "authorization_code"),
            NSURLQueryItem(name: "code", value: code!),
            NSURLQueryItem(name: "redirect_uri", value: quizletRedirectUri)
        ]
        
        var authString = "\(quizletClientId):\(quizletSecretKey)"
        var authData = authString.dataUsingEncoding(NSUTF8StringEncoding)
        var base64AuthString = authData!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding64CharacterLineLength)
        
        var config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.HTTPAdditionalHeaders = [
            "Accept": "application/json",
            "Authorization": "Basic \(base64AuthString)"
        ]
        var session = NSURLSession(configuration: config)
        var request = NSMutableURLRequest(URL: url.URL!)
        request.HTTPMethod = "POST"
        request.HTTPBody = parameters.percentEncodedQuery?.dataUsingEncoding(NSUTF8StringEncoding)
        
        if (currentTokenTask != nil) {
            NSLog("Warning: task already running: \(currentTokenTask!.description)")
        }
        
        let task = session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                self.currentTokenTask = nil
                
                var jsonAny: AnyObject? = QuizletSession.checkJSONResponseFromUrl(url.URL!, data: data, response: response, error: error)
                
                if let json = jsonAny as? NSDictionary,
                    let accessToken = json["access_token"] as? String,
                    let expiresIn = json["expires_in"] as? Int,
                    let userId = json["user_id"] as? String {
                        self.currentUser = UserAccount(accessToken: accessToken, expiresIn: expiresIn, userName: userId, userId: userId)
                        completionHandler(userAccount: self.currentUser!, error: nil)
                } else {
                    NSLog("Unexpected JSON response: \(jsonAny)")
                    return
                }
        })
        
        currentTokenTask = Task(task: task, description: toString(url.URL!))
        task.resume()
    }
    
    class func checkJSONResponseFromUrl(url: NSURL, data: NSData?, response: NSURLResponse? , error: NSError?) -> AnyObject? {
        if (error != nil) {
            NSLog("\(url)\n\(error!)")
            return nil
        }
        
        var httpResponse = response as! NSHTTPURLResponse
        if (httpResponse.statusCode != 200) {
            NSLog("Unexpected response for \(url) request: \(NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode))")
            QuizletSession.logData(data)
            return nil
        }
        
        var jsonError: NSError?
        var jsonAny: AnyObject? = NSJSONSerialization.JSONObjectWithData(
            data!, options: NSJSONReadingOptions.AllowFragments, error: &jsonError)
        if (jsonError != nil) {
            NSLog("\(url)\n\(jsonError!)")
            return nil
        }
        
        return jsonAny
    }
    
    class func logData(data: NSData?) {
        if (data != nil) {
            var str = NSString(data: data!, encoding: NSUTF8StringEncoding)
            if (str != nil) {
                NSLog(str as! String)
            }
        }
    }
    
    //
    // Possible failures: not connected, session expired, others
    //
    func getSetsInClass(classId: String, modifiedSince: Int64, allowCellularAccess: Bool, completionHandler: ([QSet]?) -> Void) {
        self.invokeQuery("/2.0/classes/\(classId)/sets", queryItems: nil, allowCellularAccess: allowCellularAccess, jsonCallback: { (data: AnyObject?) in
            if (data == nil) {
                completionHandler(nil)
                return
            }
            var myQuizletSetsAsDictionary = data as! NSDictionary
            println("searchSetsWithQuery:")
            println(myQuizletSetsAsDictionary)
            println(_stdlib_getDemangledTypeName(data))
            // completionHandler(qsets)
        })
    }
    
    func searchSetsWithQuery(query: String, modifiedSince: Int64, allowCellularAccess: Bool, completionHandler: ([QSet]?) -> Void) {
        self.invokeQuery("/2.0/search/sets",
            queryItems: [NSURLQueryItem(name: "q", value: query)],
            allowCellularAccess: allowCellularAccess,
            jsonCallback: { (data: AnyObject?) in
                if (data == nil) {
                    completionHandler(nil)
                    return
                }
                var myQuizletSetsAsDictionary = data as! NSDictionary
                println("searchSetsWithQuery:")
                println(myQuizletSetsAsDictionary)
                // completionHandler(qsets)
        })
    }
    
    func getFavoriteSetsForUser(user: String, modifiedSince: Int64, allowCellularAccess: Bool, completionHandler: ([QSet]?) -> Void) {
        self.invokeQuery("/2.0/users/\(user)/favorites", queryItems: nil, allowCellularAccess: allowCellularAccess, jsonCallback: { (data: AnyObject?) in
            if (data == nil) {
                completionHandler(nil)
                return
            }
            var favoriteSets = data as! Array<NSDictionary>
            println("getFavoriteSetsForUser:")
            println(favoriteSets)
            // completionHandler(qsets)
        })
    }
    
    func getStudiedSetsForUser(user: String, modifiedSince: Int64, allowCellularAccess: Bool, completionHandler: ([QSet]?) -> Void) {
        self.invokeQuery("/2.0/users/\(user)/studied", queryItems: nil, allowCellularAccess: allowCellularAccess, 
            jsonCallback: { (data: AnyObject?) in
                if (data == nil) {
                    completionHandler(nil)
                    return
                }
                var studiedSets = data as! Array<NSDictionary>
                println("getStudiedSetsForUser:")
                println(studiedSets)
                // completionHandler(qsets)
        })
    }
    
    func getAllSetsForUser(user: String, modifiedSince: Int64, allowCellularAccess: Bool, completionHandler: ([QSet]?) -> Void) {

        var queryItems: [NSURLQueryItem]? = nil
        
        /** The following code is commented out because the "modified_since" parameter does not work in all cases.  If the user has edited a term or moved a term, the "modified_date" for the set is not updated.  If the user inserts or deletes a term then the "modified_date" is updated as expected.
        if (modifiedSince != 0) {
            queryItems = [
                NSURLQueryItem(name: "modified_since", value: NSNumber(longLong: modifiedSince).stringValue)
                // NSURLQueryItem(name: "whitespace", value: "1")
            ]
        }
        */
        
        self.invokeQuery("/2.0/users/\(user)/sets", queryItems: queryItems, allowCellularAccess: allowCellularAccess, jsonCallback: { (data: AnyObject?) in
            if (data == nil) {
                completionHandler(nil)
                return
            }

            if let json = data as? Array<NSDictionary> {
                var qsets = QSet.setsFromJSON(json)
                if (qsets == nil) {
                    NSLog("Invalid Quizlet Set in getAllSetsForUser")
                }
                completionHandler(qsets)
            } else {
                NSLog("Unexpected response in getAllSetsForUser: \(data)")
                completionHandler(nil)
            }
        })
    }
    
    func invokeQuery(path: String, var queryItems: [NSURLQueryItem]?, allowCellularAccess: Bool, jsonCallback: ((AnyObject?) -> Void)) {
        var accessToken = currentUser?.accessToken
        if (accessToken == nil) {
            NSLog("Access token is not set")
            jsonCallback(nil)
            return
        }
        
        var url = NSURLComponents()
        url.scheme = "https"
        url.host = "api.quizlet.com"
        url.path = path
        
        /** Pretty print for debugging
        var whitespace = NSURLQueryItem(name: "whitespace", value: "1")
        if (queryItems != nil) {
            queryItems!.append(whitespace)
        } else {
            queryItems = [whitespace]
        }
        */
        url.queryItems = queryItems
        
        var config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.allowsCellularAccess = allowCellularAccess
        config.HTTPAdditionalHeaders = [
            "Accept": "application/json",
            "Authorization": "Bearer \(accessToken!)"
        ]
        var session = NSURLSession(configuration: config)
        var request = NSMutableURLRequest(URL: url.URL!)
        request.HTTPMethod = "GET"
        request.timeoutInterval = 15 // default is 60 seconds, timeout is the limit on a period of inactivity
        
        if (currentQueryTask != nil) {
            NSLog("Canceling task already running: \(currentQueryTask!.description)")
            currentQueryTask!.task.cancel()
            currentQueryTask = nil
        }
        
        let task = session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                self.currentQueryTask = nil
                
                /** Print the result
                println(path)
                println("Response data: \(NSString(data: data, encoding: NSUTF8StringEncoding))")
                */
                
                var jsonData: AnyObject? = QuizletSession.checkJSONResponseFromUrl(url.URL!, data: data, response: response, error: error)
                jsonCallback(jsonData)
        })
        
        currentQueryTask = Task(task: task, description: toString(url.URL!))
        task.resume()
    }
}

class InvokeWebService {
    class func samples() {
        // Sample call to fetch dougzilla's sets from the Quizlet
        InvokeWebService.get(scheme: "https",
            host: "api.quizlet.com",
            path: "/2.0/search/sets",
            queryItems: [
                NSURLQueryItem(name: "creator", value: "dougzilla32"),
                NSURLQueryItem(name: "client_id", value: "ZwGccNSqZJ"),
                NSURLQueryItem(name: "whitespace", value: "1")
            ],
            jsonCallback: { (results: AnyObject) -> Void in
                println("dougzilla32's sets: \(results)")
        })
        
        // Sample call to fetch the weather for London
        InvokeWebService.get(scheme: "http",
            host: "api.openweathermap.org",
            path: "/data/2.5/weather",
            queryItems: [ NSURLQueryItem(name: "q", value: "London,uk") ],
            jsonCallback: { (results: AnyObject) -> Void in
                println("Weather in London: \(results)")
        })
    }
    
    class func get(#scheme: String, host: String, path: String, var queryItems: [NSURLQueryItem]?, jsonCallback: ((AnyObject) -> Void)) {

        var url = NSURLComponents()
        url.scheme = scheme
        url.host = host
        url.path = path
        url.queryItems = queryItems
        
        var config = NSURLSessionConfiguration.defaultSessionConfiguration()
        // config.allowsCellularAccess = false
        config.HTTPAdditionalHeaders = [
            "Accept": "application/json",
            // "Authorization": "Bearer \(accessToken!)"
        ]
        var session = NSURLSession(configuration: config)
        var request = NSMutableURLRequest(URL: url.URL!)
        request.HTTPMethod = "GET"
        
        session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                var jsonData: AnyObject? = QuizletSession.checkJSONResponseFromUrl(url.URL!, data: data, response: response, error: error)
                if (jsonData == nil) {
                    return
                }
                jsonCallback(jsonData!)
        }).resume()
    }
}

class GoogleTextToSpeech {
    static var player: AVAudioPlayer?
    
    class func speechFromText(text: String) {
        var url = NSURLComponents()
        url.scheme = "http"
        url.host = "translate.google.com"
        url.path = "/translate_tts"
        url.queryItems = [
            NSURLQueryItem(name: "tl", value: "ko"),
            NSURLQueryItem(name: "q", value: text)
        ]
        
        var config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.allowsCellularAccess = false
        var session = NSURLSession(configuration: config)
        var request = NSMutableURLRequest(URL: url.URL!)
        request.HTTPMethod = "POST"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                if (error != nil) {
                    NSLog("\(url.URL!)\n\(error!)")
                    return
                }
                
                var httpResponse = response as! NSHTTPURLResponse
                if (httpResponse.statusCode != 200) {
                    NSLog("Unexpected response for translate_tts request: \(NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode))")
                    return
                }
                
                var audioError: NSError?
                var player = AVAudioPlayer(data: data, error: &audioError)
                if (audioError != nil) {
                    NSLog("Audio error: \(audioError)\n\(url)")
                    return
                }
                
                self.player = player // need a reference to the audio player that will last a while, otherwise the player will be released and the sound will not play
                player.prepareToPlay()
                player.play()
        }).resume()
    }
}

class MicrosoftTranslateSession {
    static let microsoftTranslatorClientId = "QuizletSearch"
    static let microsoftTranslatorClientSecret = "E3iu5Ludn2SAIdeiRMRkEnoQe3Dxro/QhKZmFz36gow="
    
    class func getMicrosoftToken() {
        var url = NSURLComponents()
        url.scheme = "https"
        url.host = "datamarket.accesscontrol.windows.net"
        url.path = "/v2/OAuth2-13"
        
        var query = NSURLComponents()
        query.queryItems = [
            NSURLQueryItem(name: "client_id", value: microsoftTranslatorClientId),
            NSURLQueryItem(name: "client_secret", value: microsoftTranslatorClientSecret),
            NSURLQueryItem(name: "grant_type", value: "client_credentials"),
            NSURLQueryItem(name: "scope", value: "http://api.microsofttranslator.com")
        ]
        
        var config = NSURLSessionConfiguration.defaultSessionConfiguration()
        // config.allowsCellularAccess = false
        var session = NSURLSession(configuration: config)
        var request = NSMutableURLRequest(URL: url.URL!)
        request.HTTPMethod = "POST"
        request.HTTPBody = query.percentEncodedQuery?.dataUsingEncoding(NSUTF8StringEncoding)
        
        session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                if (error != nil) {
                    NSLog("\(url.URL!)\n\(error!)")
                    return
                }
                
                var httpResponse = response as! NSHTTPURLResponse
                if (httpResponse.statusCode != 200) {
                    NSLog("Unexpected response for microsoft translate request: \(NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode))")
                    QuizletSession.logData(data)
                    return
                }
                
                var jsonData: AnyObject? = QuizletSession.checkJSONResponseFromUrl(url.URL!, data: data, response: response, error: error)
                if (jsonData == nil) {
                    return
                }
                
                var response = jsonData as! NSDictionary
                var accessToken = response["access_token"] as! String
                
                self.translateText("안녕히주무세요", from: "ko", to: "en", accessToken: accessToken)
        }).resume()
    }
    
    class func translateText(text: String, from: String, to: String, accessToken: String) {
        var url = NSURLComponents()
        url.scheme = "http"
        url.host = "api.microsofttranslator.com"
        url.path = "/v2/Http.svc/Translate"
        url.queryItems = [
            NSURLQueryItem(name: "text", value: text),
            NSURLQueryItem(name: "from", value: from),
            NSURLQueryItem(name: "to", value: to),
            NSURLQueryItem(name: "contentType", value: "text/plain")
        ]
        
        var config = NSURLSessionConfiguration.defaultSessionConfiguration()
        // config.allowsCellularAccess = false
        config.HTTPAdditionalHeaders = [
            "Authorization": "Bearer \(accessToken)"
        ]
        var session = NSURLSession(configuration: config)
        var request = NSMutableURLRequest(URL: url.URL!)
        request.HTTPMethod = "GET"
        
        session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                if (error != nil) {
                    NSLog("\(url.URL!)\n\(error!)")
                    return
                }
                
                var httpResponse = response as! NSHTTPURLResponse
                if (httpResponse.statusCode != 200) {
                    NSLog("Unexpected response for microsoft translate request: \(NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode))")
                    println(NSString(data: data!, encoding: NSUTF8StringEncoding))
                    return
                }
                
                println("Success")
                println(response)
                println(NSString(data: data!, encoding: NSUTF8StringEncoding))
        }).resume()
    }
}
