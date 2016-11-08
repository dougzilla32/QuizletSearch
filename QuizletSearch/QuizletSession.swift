//
//  QuizletSession.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/17/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation
import AVFoundation
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


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
        var task: URLSessionDataTask!
        var description: String!
        
        init() { }
        
        init(task: URLSessionDataTask, description: String) {
            self.task = task
            self.description = description
        }
        
        var hashValue: Int {
            return task.hashValue + description.hashValue
        }
    }
    
    fileprivate var currentTokenTask: Task?
    fileprivate var currentQueryTasks = Set<Task>()

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
    func authorizeURL() -> URL {
        var url = URLComponents()
        url.scheme = "https"
        url.host = "www.quizlet.com"
        url.path = "/authorize"
        url.queryItems = [
            URLQueryItem(name: "scope", value: "read"),
            URLQueryItem(name: "client_id", value: quizletClientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: quizletRedirectUri),
            URLQueryItem(name: "state", value: quizletState)
        ]
        
        return url.url!
    }
    
    // Acquire token parameters:
    //
    // grant_type       : "authorization_code"
    // code             : code from authorize response
    // redirect_uri     : check for match with authorize call
    //
    // Include HTTP basic authorization containing the client ID and secret
    //
    func acquireAccessToken(_ url: URL,
        completion: @escaping (() throws -> UserAccount) -> Void) {
        
        // The URL query contains the "/oauth/authorize" response parameters
        if (url.query == nil) {
            NSLog("Query is missing from authorize response: \(url)")
            return
        }
        
        // Parse the response parameters
        let parseQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)
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
                responseErrorDescription = responseErrorDescription!.replacingOccurrences(of: "+", with: " ")
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
        
        var url = URLComponents()
        url.scheme = "https"
        url.host = "api.quizlet.com"
        url.path = "/oauth/token"
        
        var parameters = URLComponents()
        parameters.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code!),
            URLQueryItem(name: "redirect_uri", value: quizletRedirectUri)
            // NSURLQueryItem(name: "client_id", value: quizletClientId),
            // NSURLQueryItem(name: "client_secret", value: quizletSecretKey)
        ]
        
        let authString = "\(quizletClientId):\(quizletSecretKey)"
        let authData = authString.data(using: String.Encoding.utf8)
        let base64AuthString = authData!.base64EncodedString(options: .lineLength64Characters)
        
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Authorization": "Basic \(base64AuthString)"
            // "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"
        ]
        let session = URLSession(configuration: config)
        var request = URLRequest(url: url.url!)
        request.httpMethod = "POST"
        request.httpBody = parameters.percentEncodedQuery?.data(using: String.Encoding.utf8)
        
        if (currentTokenTask != nil) {
            NSLog("Warning: task already running: \(currentTokenTask!.description)")
        }
        
        let task = session.dataTask(with: request,
            completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
                self.currentTokenTask = nil
                
                let jsonAny: Any? = QuizletSession.checkJSONResponseFromUrl(url.url!, data: data, response: response, error: error)
                
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
        
        currentTokenTask = Task(task: task, description: String(describing: url.url!))
        task.resume()
    }
    
    class func checkJSONResponseFromUrl(_ url: URL, data: Data?, response: URLResponse? , error: Error?) -> Any? {
        if (error != nil) {
            if let nsError = error as? NSError {
                if (nsError.domain == "NSURLErrorDomain" && nsError.code == NSURLErrorCancelled) {
                    // The task was cancelled -- no need to log a message
                    return nil
                }
            }

            NSLog("\(url)\n\(error!)")
            return nil
        }
        
        // Status code 200 is 'ok', code 404 is 'not found' and code 410 is 'gone'.  Code 404 and 410 are not errors and indicate the class or user in the query either was not found or has been deleted.
        let httpResponse = response as! HTTPURLResponse
        if (httpResponse.statusCode != 200) {
            if (httpResponse.statusCode != 404 && httpResponse.statusCode != 410) {
                NSLog("Unexpected response for \(url) request: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                QuizletSession.logData(data)
            }
            return nil
        }
        
        var jsonError: NSError?
        var jsonAny: Any?
        do {
            jsonAny = try JSONSerialization.jsonObject(with: data!, options: .allowFragments)
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
    
    class func logData(_ data: Data?) {
        if (data != nil) {
            let str = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            if (str != nil) {
                NSLog(str as! String)
            }
        }
    }
    
    //
    // Possible failures: not connected, session expired, others
    //
    
    class func qsetsFromJSONAny(_ jsonAny: Any?, response: URLResponse?, error: Error?, functionName: String, completionHandler: ([QSet]?, _ response: URLResponse?, _ error: Error?) -> Void) {
        if (jsonAny == nil) {
            completionHandler(nil, response, error)
            return
        }
        
        if let json = jsonAny as? Array<NSDictionary> {
            let qsets = QSet.setsFromJSON(json)
            if (qsets == nil) {
                NSLog("Invalid Quizlet Set in \(functionName)")
            }
            completionHandler(qsets, response, error)
        } else {
            NSLog("Unexpected response in \(functionName): \(jsonAny)")
            completionHandler(nil, response, error)
        }
    }
    
    class func queryItemsForModifiedSince(_ modifiedSince: Int64?) -> [URLQueryItem] {
        let queryItems: [URLQueryItem] = []
        
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
    
    func searchSetsWithQuery(_ query: String?, creator: String?, autocomplete: Bool?, imagesOnly: Bool?, modifiedSince: Int64?, page: Int?, perPage: Int?, allowCellularAccess: Bool, completionHandler: @escaping (QueryResult?, _ response: URLResponse?, _ error: Error?) -> Void) {
        // perPage: between 1 and 50
        if (perPage < 1 || perPage > 50) {
            NSLog("Invalid perPage parameter")
            abort()
        }
        
        var params = [URLQueryItem]()
        if (query != nil) {
            params.append(URLQueryItem(name: "q", value: query!))
        }
        if (creator != nil) {
            params.append(URLQueryItem(name: "creator", value: creator!))
        }
        if (autocomplete != nil) {
            params.append(URLQueryItem(name: "autocomplete", value: autocomplete! ? "1" : "0"))
        }
        if (imagesOnly != nil) {
            params.append(URLQueryItem(name: "images_only", value: String(imagesOnly! ? 1 : 0)))
        }
        if (modifiedSince != nil) {
            // params.append(NSURLQueryItem(name: "modified_since", value: String(modifiedSince!)))
        }
        if (page != nil) {
            params.append(URLQueryItem(name: "page", value: String(page!)))
        }
        if (perPage != nil) {
            params.append(URLQueryItem(name: "perPage", value: String(perPage!)))
        }
        // params.append(NSURLQueryitem(name: "whitespace", value: "1"))
        // params.append(NSURLQueryItem(name: "sort", value: "title"))
        
        self.invokeQuery("/2.0/search/sets", queryItems: params,
            allowCellularAccess: allowCellularAccess, jsonCallback: { (jsonAny: Any?, response: URLResponse?, error: Error?) in
                if (jsonAny == nil) {
                    completionHandler(nil, response, error)
                    return
                }

                do {
                    let result = try QueryResult(jsonAny: jsonAny!)
                    completionHandler(result, response, error)
                }
                catch {
                    NSLog("Unexpected response in searchSetsWithQuery: \(jsonAny)")
                    completionHandler(nil, response, error)
                }
        })
    }
    
    func getSetsForIds(_ setIds: [Int64], modifiedSince: Int64?, allowCellularAccess: Bool, completionHandler: @escaping ([QSet]?, _ response: URLResponse?, _ error: Error?) -> Void) {
        
        var stringIds = [String]()
        for id in setIds {
            stringIds.append(String(id))
        }
        
        var queryItems = [URLQueryItem]()
        queryItems += QuizletSession.queryItemsForModifiedSince(modifiedSince)
        queryItems.append(URLQueryItem(name: "set_ids", value: stringIds.joined(separator: ",")))
        
        self.invokeQuery("/2.0/sets",
            queryItems: queryItems,
            allowCellularAccess: allowCellularAccess,
            jsonCallback: { (jsonAny: Any?, response: URLResponse?, error: Error?) in
                QuizletSession.qsetsFromJSONAny(jsonAny, response: response, error: error, functionName: "getSets", completionHandler: completionHandler)
        })
    }
    
    func getSetsInClass(_ classId: String, modifiedSince: Int64?, allowCellularAccess: Bool, completionHandler: @escaping ([QSet]?, _ response: URLResponse?, _ error: Error?) -> Void) {
        self.invokeQuery("/2.0/classes/\(classId)/sets",
            queryItems: QuizletSession.queryItemsForModifiedSince(modifiedSince),
            allowCellularAccess: allowCellularAccess,
            jsonCallback: { (jsonAny: Any?, response: URLResponse?, error: Error?) in
                
                QuizletSession.qsetsFromJSONAny(jsonAny, response: response, error: error, functionName: "getSetsInClass", completionHandler: completionHandler)
        })
    }
    
    func getFavoriteSetsForUser(_ user: String, modifiedSince: Int64?, allowCellularAccess: Bool, completionHandler: @escaping ([QSet]?, _ response: URLResponse?, _ error: Error?) -> Void) {
        self.invokeQuery("/2.0/users/\(user)/favorites", queryItems: QuizletSession.queryItemsForModifiedSince(modifiedSince), allowCellularAccess: allowCellularAccess, jsonCallback: { (jsonAny: Any?, response: URLResponse?, error: Error?) in

            QuizletSession.qsetsFromJSONAny(jsonAny, response: response, error: error, functionName: "getFavoriteSetsForUser", completionHandler: completionHandler)
        })
    }
    
    func getStudiedSetsForUser(_ user: String, modifiedSince: Int64?, allowCellularAccess: Bool, completionHandler: @escaping ([QSet]?, _ response: URLResponse?, _ error: Error?) -> Void) {
        self.invokeQuery("/2.0/users/\(user)/studied", queryItems: QuizletSession.queryItemsForModifiedSince(modifiedSince), allowCellularAccess: allowCellularAccess, jsonCallback: { (jsonAny: Any?, response: URLResponse?, error: Error?) in

            QuizletSession.qsetsFromJSONAny(jsonAny, response: response, error: error, functionName: "getStudiedSetsForUser", completionHandler: completionHandler)
        })
    }
    
    func getAllSetsForUser(_ user: String, modifiedSince: Int64?, allowCellularAccess: Bool, completionHandler: @escaping ([QSet]?, _ response: URLResponse?, _ error: Error?) -> Void) {

        self.invokeQuery("/2.0/users/\(user)/sets", queryItems: QuizletSession.queryItemsForModifiedSince(modifiedSince), allowCellularAccess: allowCellularAccess, jsonCallback: { (jsonAny: Any?, response: URLResponse?, error: Error?) in

            QuizletSession.qsetsFromJSONAny(jsonAny, response: response, error: error, functionName: "getAllSetsForUser", completionHandler: completionHandler)
        })
    }
    
    func getAllSampleSetsForUser(_ user: String, modifiedSince: Int64?, allowCellularAccess: Bool, completionHandler: ([QSet]?, _ response: URLResponse?, _ error: Error?) -> Void) {

        let sampleFilePath = Bundle.main.path(forResource: "SampleQuizletData", ofType: "json")
        if (sampleFilePath == nil) {
            NSLog("Resource not found: SampleQuizletData.json")
            completionHandler(nil, nil, nil)
            return
        }

        let data = try? Data(contentsOf: URL(fileURLWithPath: sampleFilePath!))

        var jsonAny: Any?
        do {
            jsonAny = try JSONSerialization.jsonObject(with: data!, options: .allowFragments)
        } catch let error {
            NSLog("\(error)")
            completionHandler(nil, nil, nil)
            return
        }
        
        if let json = jsonAny as? Array<NSDictionary> {
            let qsets = QSet.setsFromJSON(json)
            if (qsets == nil) {
                NSLog("Invalid Quizlet Set in getAllSampleSetsForUser")
            }
            completionHandler(qsets, nil, nil)
        } else {
            NSLog("Unexpected response in getAllSampleSetsForUser: \(data)")
            completionHandler(nil, nil, nil)
        }
    }
    
    func invokeQuery(_ path: String, queryItems: [URLQueryItem]?, allowCellularAccess: Bool, jsonCallback: @escaping ((Any?, _ response: URLResponse?, _ error: Error?) -> Void)) {
        let accessToken = currentUser?.accessToken
        if (accessToken == nil) {
            NSLog("Access token is not set")
            jsonCallback(nil, nil, nil)
            return
        }
        
        var url = URLComponents()
        url.scheme = "https"
        url.host = "api.quizlet.com"
        url.path = path
        
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = allowCellularAccess

        var modifiedQueryItems = queryItems
        if (accessToken!.isEmpty) {
            let queryClientId = URLQueryItem(name: "client_id", value: quizletClientId)
            if (modifiedQueryItems != nil) {
                modifiedQueryItems!.append(queryClientId)
            } else {
                modifiedQueryItems = [queryClientId]
            }
        } else {
            config.httpAdditionalHeaders = [
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
        
        url.queryItems = modifiedQueryItems

        let session = URLSession(configuration: config)
        var request = URLRequest(url: url.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 15 // default is 60 seconds, timeout is the limit on a period of inactivity
        
        let queryTask = Task()
        let task = session.dataTask(with: request,
            completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
                DispatchQueue.main.async(execute: {
                    self.currentQueryTasks.remove(queryTask)
                })
                
                /** Print the result
                print(path)
                print("Response data: \(NSString(data: data, encoding: NSUTF8StringEncoding))")
                */
                
                let jsonData: Any? = QuizletSession.checkJSONResponseFromUrl(url.url!, data: data, response: response, error: error)
                jsonCallback(jsonData, response, error)
        })

        queryTask.task = task
        queryTask.description = String(describing: url.url!)
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
                URLQueryItem(name: "creator", value: "dougzilla32"),
                URLQueryItem(name: "client_id", value: "ZwGccNSqZJ"),
                URLQueryItem(name: "whitespace", value: "1")
            ],
            jsonCallback: { (results: Any) -> Void in
                print("dougzilla32's sets: \(results)")
        })
        
        // Sample call to fetch the weather for London
        InvokeWebService.get(scheme: "http",
            host: "api.openweathermap.org",
            path: "/data/2.5/weather",
            queryItems: [ URLQueryItem(name: "q", value: "London,uk") ],
            jsonCallback: { (results: Any) -> Void in
                print("Weather in London: \(results)")
        })
    }
    
    class func get(scheme: String, host: String, path: String, queryItems: [URLQueryItem]?, jsonCallback: @escaping ((Any) -> Void)) {

        var url = URLComponents()
        url.scheme = scheme
        url.host = host
        url.path = path
        url.queryItems = queryItems
        
        let config = URLSessionConfiguration.default
        // config.allowsCellularAccess = false
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            // "Authorization": "Bearer \(accessToken!)"
        ]
        let session = URLSession(configuration: config)
        var request = URLRequest(url: url.url!)
        request.httpMethod = "GET"
        
        session.dataTask(with: request,
            completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
                let jsonData: Any? = QuizletSession.checkJSONResponseFromUrl(url.url!, data: data, response: response, error: error)
                if (jsonData == nil) {
                    return
                }
                jsonCallback(jsonData!)
        }).resume()
    }
}

class GoogleTextToSpeech {
    static var player: AVAudioPlayer?
    
    class func speechFromText(_ text: String) {
        var url = URLComponents()
        url.scheme = "http"
        url.host = "translate.google.com"
        url.path = "/translate_tts"
        url.queryItems = [
            URLQueryItem(name: "tl", value: "ko"),
            URLQueryItem(name: "q", value: text)
        ]
        
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = false
        let session = URLSession(configuration: config)
        var request = URLRequest(url: url.url!)
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request,
            completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
                if (error != nil) {
                    NSLog("\(url.url!)\n\(error!)")
                    return
                }
                
                let httpResponse = response as! HTTPURLResponse
                if (httpResponse.statusCode != 200) {
                    NSLog("Unexpected response for translate_tts request: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
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
        var url = URLComponents()
        url.scheme = "https"
        url.host = "datamarket.accesscontrol.windows.net"
        url.path = "/v2/OAuth2-13"
        
        var query = URLComponents()
        query.queryItems = [
            URLQueryItem(name: "client_id", value: microsoftTranslatorClientId),
            URLQueryItem(name: "client_secret", value: microsoftTranslatorClientSecret),
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "scope", value: "http://api.microsofttranslator.com")
        ]
        
        let config = URLSessionConfiguration.default
        // config.allowsCellularAccess = false
        let session = URLSession(configuration: config)
        var request = URLRequest(url: url.url!)
        request.httpMethod = "POST"
        request.httpBody = query.percentEncodedQuery?.data(using: String.Encoding.utf8)
        
        session.dataTask(with: request,
            completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
                if (error != nil) {
                    NSLog("\(url.url!)\n\(error!)")
                    return
                }
                
                let httpResponse = response as! HTTPURLResponse
                if (httpResponse.statusCode != 200) {
                    NSLog("Unexpected response for microsoft translate request: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                    QuizletSession.logData(data)
                    return
                }
                
                let jsonData: Any? = QuizletSession.checkJSONResponseFromUrl(url.url!, data: data, response: response, error: error)
                if (jsonData == nil) {
                    return
                }
                
                let response = jsonData as! NSDictionary
                let accessToken = response["access_token"] as! String
                
                self.translateText("안녕히주무세요", from: "ko", to: "en", accessToken: accessToken)
        }).resume()
    }
    
    class func translateText(_ text: String, from: String, to: String, accessToken: String) {
        var url = URLComponents()
        url.scheme = "http"
        url.host = "api.microsofttranslator.com"
        url.path = "/v2/Http.svc/Translate"
        url.queryItems = [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
            URLQueryItem(name: "contentType", value: "text/plain")
        ]
        
        let config = URLSessionConfiguration.default
        // config.allowsCellularAccess = false
        config.httpAdditionalHeaders = [
            "Authorization": "Bearer \(accessToken)"
        ]
        let session = URLSession(configuration: config)
        var request = URLRequest(url: url.url!)
        request.httpMethod = "GET"
        
        session.dataTask(with: request,
            completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
                if (error != nil) {
                    NSLog("\(url.url!)\n\(error!)")
                    return
                }
                
                let httpResponse = response as! HTTPURLResponse
                if (httpResponse.statusCode != 200) {
                    NSLog("Unexpected response for microsoft translate request: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                    print(NSString(data: data!, encoding: String.Encoding.utf8.rawValue) as Any)
                    return
                }
                
                print("Success")
                print(response as Any)
                print(NSString(data: data!, encoding: String.Encoding.utf8.rawValue) as Any)
        }).resume()
    }
}
