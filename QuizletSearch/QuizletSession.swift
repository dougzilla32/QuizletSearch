//
//  QuizletSession.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/17/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation
import AVFoundation

func ==(lhs: QuizletSession.Task, rhs: QuizletSession.Task) -> Bool {
    return (lhs.task == rhs.task && lhs.description == rhs.description)
}

//
// Note: NSURLComponents does not percent-escape the following characters which causes
// problems while parsing the response: '&' ';'
//
class QuizletSession {
    // Original client, dougzilla32 'Quizlet Search'
    let quizletClientId = "ZwGccNSqZJ"
    let quizletSecretKey = "Jq2xbvn55EaJwhqbtMvtem"
    let quizletRedirectUri = "quizletsearch://userauthorization"
    let quizletState = "qW3Ecv34asdf4/aseErBw34gs="

    // Test client, dougzilla88 'Quizlet Search Tester'
    // let quizletClientId = "kJTRmEt95w"
    // let quizletSecretKey = "Jq2xbvn55EaJwhqbtMvtem"
    // let quizletRedirectUri = "quizletsearch://userauthorization"
    // let quizletState = "simpleState"
    
    var currentUser: UserAccount?
    
    class Task: Hashable {
        var task: NSURLSessionDataTask!
        var description: String!
        
        init() { }
        
        init(task: NSURLSessionDataTask, description: String) {
            self.task = task
            self.description = description
        }
        
        var hashValue: Int {
            return task.hashValue + description.hashValue
        }
    }
    
    private var currentTokenTask: Task?
    private var currentQueryTasks = Set<Task>()

    func close() {
        for task in currentQueryTasks {
            task.task.cancel()
        }
        
        if let task = currentTokenTask {
            task.task.cancel()
        }
    }
    
    func cancelQueryTasks() {
        for task in currentQueryTasks {
            task.task.cancel()
        }
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
        let url = NSURLComponents()
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
        completion: (() throws -> UserAccount) -> Void) {
        
        // The URL query contains the "/oauth/authorize" response parameters
        if (url.query == nil) {
            NSLog("Query is missing from authorize response: \(url)")
            return
        }
        
        // Parse the response parameters
        let parseQuery = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
        var responseParams = [String: String]()
        for item in parseQuery!.queryItems! {
            responseParams[item.name] = item.value
        }
        
        // Check the state to prevent cross-site request forgery (CSRF) attacks
        let state = responseParams["state"]
        if (state == nil) {
            NSLog("Parameter \"state\" missing from authorize response: \(url)")
            return
        }
        if (state != quizletState) {
            NSLog("State mismatch between authorize request and response, possible CSRF attack: \(state!)")
            return
        }
        
        // Check if the response contains an error message
        let responseError = responseParams["error"]
        if (responseError != nil) {
            var responseErrorDescription = responseParams["error_description"]
            if (responseErrorDescription != nil) {
                responseErrorDescription = responseErrorDescription!.stringByReplacingOccurrencesOfString("+", withString: " ")
            } else {
                responseErrorDescription = "Unable to complete login"
            }

            let error = NSError(domain: responseError!, code: 0,
                userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString(responseError!, comment: ""),
                    NSLocalizedFailureReasonErrorKey: responseErrorDescription!
                ])
            completion {
                throw error
            }
            return
        }
    
        // Sanity check the response parameters
        let code = responseParams["code"]
        if (code == nil) {
            NSLog("Parameter \"code\" missing from authorize response: \(url)")
            return
        }
        
        let url = NSURLComponents()
        url.scheme = "https"
        url.host = "api.quizlet.com"
        url.path = "/oauth/token"
        
        let parameters = NSURLComponents()
        parameters.queryItems = [
            NSURLQueryItem(name: "grant_type", value: "authorization_code"),
            NSURLQueryItem(name: "code", value: code!),
            NSURLQueryItem(name: "redirect_uri", value: quizletRedirectUri)
            // NSURLQueryItem(name: "client_id", value: quizletClientId),
            // NSURLQueryItem(name: "client_secret", value: quizletSecretKey)
        ]
        
        let authString = "\(quizletClientId):\(quizletSecretKey)"
        let authData = authString.dataUsingEncoding(NSUTF8StringEncoding)
        let base64AuthString = authData!.base64EncodedStringWithOptions(.Encoding64CharacterLineLength)
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.HTTPAdditionalHeaders = [
            "Accept": "application/json",
            "Authorization": "Basic \(base64AuthString)"
            // "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"
        ]
        let session = NSURLSession(configuration: config)
        let request = NSMutableURLRequest(URL: url.URL!)
        request.HTTPMethod = "POST"
        request.HTTPBody = parameters.percentEncodedQuery?.dataUsingEncoding(NSUTF8StringEncoding)
        
        if (currentTokenTask != nil) {
            NSLog("Warning: task already running: \(currentTokenTask!.description)")
        }
        
        let task = session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                self.currentTokenTask = nil
                
                let jsonAny: AnyObject? = QuizletSession.checkJSONResponseFromUrl(url.URL!, data: data, response: response, error: error)
                
                if let json = jsonAny as? NSDictionary,
                    let accessToken = json["access_token"] as? String,
                    let expiresIn = json["expires_in"] as? Int,
                    let userId = json["user_id"] as? String {
                        self.currentUser = UserAccount(accessToken: accessToken, expiresIn: expiresIn, userName: userId, userId: userId)
                        completion {
                            return self.currentUser!
                        }
                } else {
                    NSLog("Unexpected JSON response: \(jsonAny)")
                    return
                }
        })
        
        currentTokenTask = Task(task: task, description: String(url.URL!))
        task.resume()
    }
    
    class func checkJSONResponseFromUrl(url: NSURL, data: NSData?, response: NSURLResponse? , error: NSError?) -> AnyObject? {
        if (error != nil) {
            if (error!.domain == "NSURLErrorDomain" && error!.code == NSURLErrorCancelled) {
                // The task was cancelled -- no need to log a message
            }
            else {
                NSLog("\(url)\n\(error!)")
            }
            return nil
        }
        
        let httpResponse = response as! NSHTTPURLResponse
        if (httpResponse.statusCode != 200) {
            NSLog("Unexpected response for \(url) request: \(NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode))")
            QuizletSession.logData(data)
            return nil
        }
        
        var jsonError: NSError?
        var jsonAny: AnyObject?
        do {
            jsonAny = try NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments)
        } catch let error as NSError {
            jsonError = error
            jsonAny = nil
        }
        if (jsonError != nil) {
            NSLog("\(url)\n\(jsonError!)")
            return nil
        }
        
        return jsonAny
    }
    
    class func logData(data: NSData?) {
        if (data != nil) {
            let str = NSString(data: data!, encoding: NSUTF8StringEncoding)
            if (str != nil) {
                NSLog(str as! String)
            }
        }
    }
    
    //
    // Possible failures: not connected, session expired, others
    //
    
    class func qsetsFromJSONAny(jsonAny: AnyObject?, functionName: String, completionHandler: ([QSet]?) -> Void) {
        if (jsonAny == nil) {
            completionHandler(nil)
            return
        }
        
        if let json = jsonAny as? Array<NSDictionary> {
            let qsets = QSet.setsFromJSON(json)
            if (qsets == nil) {
                NSLog("Invalid Quizlet Set in \(functionName)")
            }
            completionHandler(qsets)
        } else {
            NSLog("Unexpected response in \(functionName): \(jsonAny)")
            completionHandler(nil)
        }
    }
    
    class func queryItemsForModifiedSince(modifiedSince: Int64?) -> [NSURLQueryItem] {
        let queryItems: [NSURLQueryItem] = []
        
        /** The following code is commented out because the "modified_since" parameter does not work in all cases.  If the user has edited a term or moved a term, the "modified_date" for the set is not updated.  If the user inserts or deletes a term then the "modified_date" is updated as expected.
        if (modifiedSince != nil) {
            if queryItems == nil { queryItems = [] }
            queryItems!.append(NSURLQueryItem(name: "modified_since", value: String(modifiedSince)))
        }
        if (whitespaceOption) {
            if queryItems == nil { queryItems = [] }
            queryItems!.append(NSURLQueryItem(name: "whitespace", value: "1"))
        }
        */
        
        return queryItems
    }
    
    func searchSetsWithQuery(query: String?, creator: String?, autocomplete: Bool?, imagesOnly: Bool?, modifiedSince: Int64?, page: Int?, perPage: Int?, allowCellularAccess: Bool, completionHandler: (QueryResult?) -> Void) {
        // perPage: between 1 and 50
        if (perPage < 1 || perPage > 50) {
            NSLog("Invalid perPage parameter")
            abort()
        }
        
        var params = [NSURLQueryItem]()
        if (query != nil) {
            params.append(NSURLQueryItem(name: "q", value: query!))
        }
        if (creator != nil) {
            params.append(NSURLQueryItem(name: "creator", value: creator!))
        }
        if (autocomplete != nil) {
            params.append(NSURLQueryItem(name: "autocomplete", value: autocomplete! ? "1" : "0"))
        }
        if (imagesOnly != nil) {
            params.append(NSURLQueryItem(name: "images_only", value: String(imagesOnly! ? 1 : 0)))
        }
        if (modifiedSince != nil) {
            // params.append(NSURLQueryItem(name: "modified_since", value: String(modifiedSince!)))
        }
        if (page != nil) {
            params.append(NSURLQueryItem(name: "page", value: String(page!)))
        }
        if (perPage != nil) {
            params.append(NSURLQueryItem(name: "perPage", value: String(perPage!)))
        }
        // params.append(NSURLQueryitem(name: "whitespace", value: "1"))
        // params.append(NSURLQueryItem(name: "sort", value: "title"))
        
        self.invokeQuery("/2.0/search/sets", queryItems: params,
            allowCellularAccess: allowCellularAccess, jsonCallback: { (jsonAny: AnyObject?) in
                if (jsonAny == nil) {
                    completionHandler(nil)
                    return
                }

                do {
                    let result = try QueryResult(jsonAny: jsonAny!)
                    completionHandler(result)
                }
                catch {
                    NSLog("Unexpected response in searchSetsWithQuery: \(jsonAny)")
                    completionHandler(nil)
                }
        })
    }
    
    func getSetsForIds(setIds: [Int64], modifiedSince: Int64?, allowCellularAccess: Bool, completionHandler: ([QSet]?) -> Void) {
        
        var stringIds = [String]()
        for id in setIds {
            stringIds.append(String(id))
        }
        
        var queryItems = [NSURLQueryItem]()
        queryItems += QuizletSession.queryItemsForModifiedSince(modifiedSince)
        queryItems.append(NSURLQueryItem(name: "set_ids", value: stringIds.joinWithSeparator(",")))
        
        self.invokeQuery("/2.0/sets",
            queryItems: queryItems,
            allowCellularAccess: allowCellularAccess,
            jsonCallback: { (jsonAny: AnyObject?) in
                QuizletSession.qsetsFromJSONAny(jsonAny, functionName: "getSets", completionHandler: completionHandler)
        })
    }
    
    func getSetsInClass(classId: String, modifiedSince: Int64?, allowCellularAccess: Bool, completionHandler: ([QSet]?) -> Void) {
        self.invokeQuery("/2.0/classes/\(classId)/sets",
            queryItems: QuizletSession.queryItemsForModifiedSince(modifiedSince),
            allowCellularAccess: allowCellularAccess,
            jsonCallback: { (jsonAny: AnyObject?) in
                
                QuizletSession.qsetsFromJSONAny(jsonAny, functionName: "getSetsInClass", completionHandler: completionHandler)
        })
    }
    
    func getFavoriteSetsForUser(user: String, modifiedSince: Int64?, allowCellularAccess: Bool, completionHandler: ([QSet]?) -> Void) {
        self.invokeQuery("/2.0/users/\(user)/favorites", queryItems: QuizletSession.queryItemsForModifiedSince(modifiedSince), allowCellularAccess: allowCellularAccess, jsonCallback: { (jsonAny: AnyObject?) in

            QuizletSession.qsetsFromJSONAny(jsonAny, functionName: "getFavoriteSetsForUser", completionHandler: completionHandler)
        })
    }
    
    func getStudiedSetsForUser(user: String, modifiedSince: Int64?, allowCellularAccess: Bool, completionHandler: ([QSet]?) -> Void) {
        self.invokeQuery("/2.0/users/\(user)/studied", queryItems: QuizletSession.queryItemsForModifiedSince(modifiedSince), allowCellularAccess: allowCellularAccess, jsonCallback: { (jsonAny: AnyObject?) in

            QuizletSession.qsetsFromJSONAny(jsonAny, functionName: "getStudiedSetsForUser", completionHandler: completionHandler)
        })
    }
    
    func getAllSetsForUser(user: String, modifiedSince: Int64?, allowCellularAccess: Bool, completionHandler: ([QSet]?) -> Void) {

        self.invokeQuery("/2.0/users/\(user)/sets", queryItems: QuizletSession.queryItemsForModifiedSince(modifiedSince), allowCellularAccess: allowCellularAccess, jsonCallback: { (jsonAny: AnyObject?) in

            QuizletSession.qsetsFromJSONAny(jsonAny, functionName: "getAllSetsForUser", completionHandler: completionHandler)
        })
    }
    
    func getAllSampleSetsForUser(user: String, modifiedSince: Int64?, allowCellularAccess: Bool, completionHandler: ([QSet]?) -> Void) {

        let sampleFilePath = NSBundle.mainBundle().pathForResource("SampleQuizletData", ofType: "json")
        if (sampleFilePath == nil) {
            NSLog("Resource not found: SampleQuizletData.json")
            completionHandler(nil)
            return
        }

        let data = NSData(contentsOfFile: sampleFilePath!)

        var jsonAny: AnyObject?
        do {
            jsonAny = try NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments)
        } catch let error as NSError {
            NSLog("\(error)")
            completionHandler(nil)
            return
        }
        
        if let json = jsonAny as? Array<NSDictionary> {
            let qsets = QSet.setsFromJSON(json)
            if (qsets == nil) {
                NSLog("Invalid Quizlet Set in getAllSampleSetsForUser")
            }
            completionHandler(qsets)
        } else {
            NSLog("Unexpected response in getAllSampleSetsForUser: \(data)")
            completionHandler(nil)
        }
    }
    
    func invokeQuery(path: String, var queryItems: [NSURLQueryItem]?, allowCellularAccess: Bool, jsonCallback: ((AnyObject?) -> Void)) {
        let accessToken = currentUser?.accessToken
        if (accessToken == nil) {
            NSLog("Access token is not set")
            jsonCallback(nil)
            return
        }
        
        let url = NSURLComponents()
        url.scheme = "https"
        url.host = "api.quizlet.com"
        url.path = path
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.allowsCellularAccess = allowCellularAccess

        if (accessToken!.isEmpty) {
            let queryClientId = NSURLQueryItem(name: "client_id", value: quizletClientId)
            if (queryItems != nil) {
                queryItems!.append(queryClientId)
            } else {
                queryItems = [queryClientId]
            }
        } else {
            config.HTTPAdditionalHeaders = [
                "Accept": "application/json",
                "Authorization": "Bearer \(accessToken!)"
            ]
        }

        /** Pretty print for debugging
        var whitespace = NSURLQueryItem(name: "whitespace", value: "1")
        if (queryItems != nil) {
        queryItems!.append(whitespace)
        } else {
        queryItems = [whitespace]
        }
        */
        
        url.queryItems = queryItems

        let session = NSURLSession(configuration: config)
        let request = NSMutableURLRequest(URL: url.URL!)
        request.HTTPMethod = "GET"
        request.timeoutInterval = 15 // default is 60 seconds, timeout is the limit on a period of inactivity
        
        let queryTask = Task()
        let task = session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                dispatch_async(dispatch_get_main_queue(), {
                    self.currentQueryTasks.remove(queryTask)
                })
                
                /** Print the result
                print(path)
                print("Response data: \(NSString(data: data, encoding: NSUTF8StringEncoding))")
                */
                
                let jsonData: AnyObject? = QuizletSession.checkJSONResponseFromUrl(url.URL!, data: data, response: response, error: error)
                jsonCallback(jsonData)
        })

        queryTask.task = task
        queryTask.description = String(url.URL!)
        currentQueryTasks.insert(queryTask)
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
                print("dougzilla32's sets: \(results)")
        })
        
        // Sample call to fetch the weather for London
        InvokeWebService.get(scheme: "http",
            host: "api.openweathermap.org",
            path: "/data/2.5/weather",
            queryItems: [ NSURLQueryItem(name: "q", value: "London,uk") ],
            jsonCallback: { (results: AnyObject) -> Void in
                print("Weather in London: \(results)")
        })
    }
    
    class func get(scheme scheme: String, host: String, path: String, queryItems: [NSURLQueryItem]?, jsonCallback: ((AnyObject) -> Void)) {

        let url = NSURLComponents()
        url.scheme = scheme
        url.host = host
        url.path = path
        url.queryItems = queryItems
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        // config.allowsCellularAccess = false
        config.HTTPAdditionalHeaders = [
            "Accept": "application/json",
            // "Authorization": "Bearer \(accessToken!)"
        ]
        let session = NSURLSession(configuration: config)
        let request = NSMutableURLRequest(URL: url.URL!)
        request.HTTPMethod = "GET"
        
        session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                let jsonData: AnyObject? = QuizletSession.checkJSONResponseFromUrl(url.URL!, data: data, response: response, error: error)
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
        let url = NSURLComponents()
        url.scheme = "http"
        url.host = "translate.google.com"
        url.path = "/translate_tts"
        url.queryItems = [
            NSURLQueryItem(name: "tl", value: "ko"),
            NSURLQueryItem(name: "q", value: text)
        ]
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.allowsCellularAccess = false
        let session = NSURLSession(configuration: config)
        let request = NSMutableURLRequest(URL: url.URL!)
        request.HTTPMethod = "POST"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                if (error != nil) {
                    NSLog("\(url.URL!)\n\(error!)")
                    return
                }
                
                let httpResponse = response as! NSHTTPURLResponse
                if (httpResponse.statusCode != 200) {
                    NSLog("Unexpected response for translate_tts request: \(NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode))")
                    return
                }
                
                var player: AVAudioPlayer!
                do {
                    player = try AVAudioPlayer(data: data!)
                } catch let error as NSError {
                    NSLog("Audio error: \(error)\n\(url)")
                    return
                } catch {
                    fatalError()
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
        let url = NSURLComponents()
        url.scheme = "https"
        url.host = "datamarket.accesscontrol.windows.net"
        url.path = "/v2/OAuth2-13"
        
        let query = NSURLComponents()
        query.queryItems = [
            NSURLQueryItem(name: "client_id", value: microsoftTranslatorClientId),
            NSURLQueryItem(name: "client_secret", value: microsoftTranslatorClientSecret),
            NSURLQueryItem(name: "grant_type", value: "client_credentials"),
            NSURLQueryItem(name: "scope", value: "http://api.microsofttranslator.com")
        ]
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        // config.allowsCellularAccess = false
        let session = NSURLSession(configuration: config)
        let request = NSMutableURLRequest(URL: url.URL!)
        request.HTTPMethod = "POST"
        request.HTTPBody = query.percentEncodedQuery?.dataUsingEncoding(NSUTF8StringEncoding)
        
        session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                if (error != nil) {
                    NSLog("\(url.URL!)\n\(error!)")
                    return
                }
                
                let httpResponse = response as! NSHTTPURLResponse
                if (httpResponse.statusCode != 200) {
                    NSLog("Unexpected response for microsoft translate request: \(NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode))")
                    QuizletSession.logData(data)
                    return
                }
                
                let jsonData: AnyObject? = QuizletSession.checkJSONResponseFromUrl(url.URL!, data: data, response: response, error: error)
                if (jsonData == nil) {
                    return
                }
                
                let response = jsonData as! NSDictionary
                let accessToken = response["access_token"] as! String
                
                self.translateText("안녕히주무세요", from: "ko", to: "en", accessToken: accessToken)
        }).resume()
    }
    
    class func translateText(text: String, from: String, to: String, accessToken: String) {
        let url = NSURLComponents()
        url.scheme = "http"
        url.host = "api.microsofttranslator.com"
        url.path = "/v2/Http.svc/Translate"
        url.queryItems = [
            NSURLQueryItem(name: "text", value: text),
            NSURLQueryItem(name: "from", value: from),
            NSURLQueryItem(name: "to", value: to),
            NSURLQueryItem(name: "contentType", value: "text/plain")
        ]
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        // config.allowsCellularAccess = false
        config.HTTPAdditionalHeaders = [
            "Authorization": "Bearer \(accessToken)"
        ]
        let session = NSURLSession(configuration: config)
        let request = NSMutableURLRequest(URL: url.URL!)
        request.HTTPMethod = "GET"
        
        session.dataTaskWithRequest(request,
            completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) in
                if (error != nil) {
                    NSLog("\(url.URL!)\n\(error!)")
                    return
                }
                
                let httpResponse = response as! NSHTTPURLResponse
                if (httpResponse.statusCode != 200) {
                    NSLog("Unexpected response for microsoft translate request: \(NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode))")
                    print(NSString(data: data!, encoding: NSUTF8StringEncoding))
                    return
                }
                
                print("Success")
                print(response)
                print(NSString(data: data!, encoding: NSUTF8StringEncoding))
        }).resume()
    }
}
