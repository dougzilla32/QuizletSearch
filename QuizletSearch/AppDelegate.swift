//
//  AppDelegate.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/1/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UIAlertViewDelegate {

    let quizletSession = QuizletSession()
    
    var window: UIWindow?
    
    let QueriesViewController = "QueriesNavigationController"
    let LoginViewController = "LoginViewController"
    static let ErrorViewController = "ErrorViewController"
    
    let refreshInterval: TimeInterval = 60 * 5  // 5 minutes
    
    lazy var dataModel: DataModel = {
        [unowned self] in
        return DataModel(managedObjectContext: self.managedObjectContext!, quizletSession: self.quizletSession)
    }()
    
    var refreshTimer: Timer?
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        var id: String
        if (managedObjectContext != nil) {
            id = (dataModel.currentUser == nil) ? LoginViewController : QueriesViewController
        } else {
            id = AppDelegate.ErrorViewController
        }
        
        initRootViewControllerWithIdentifier(id)

        return true
    }
    
    func initRootViewControllerWithIdentifier(_ id: String) {
        let storyboard = self.window!.rootViewController!.storyboard!
        self.window!.rootViewController = storyboard.instantiateViewController(withIdentifier: id)
    }
    
    // Tells the delegate that the launch process is almost done and the app is almost ready to run.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    func refreshAndRestartTimer(allowCellularAccess: Bool, modified: Bool, completionHandler: (([QSet]?) -> Void)? = nil) {
        if (managedObjectContext == nil || dataModel.currentUser == nil) {
            return
        }
        
        cancelRefreshTimer()

        let currentTime = Date.timeIntervalSinceReferenceDate
        let query = dataModel.currentQuery!
        let successTime = query.timeOfMostRecentSuccessfulRefresh ?? 0
        let timeRemaining = Swift.max(0, refreshInterval - (currentTime - successTime))
        
        trace("refreshAndRestartTimer modified:", modified, "timeRemaining:", timeRemaining)
        if (modified || timeRemaining == 0) {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            
            self.dataModel.refreshModelForCurrentQuery(allowCellularAccess: allowCellularAccess, completionHandler: { (qsets: [QSet]?, termCount: Int) in
                if (qsets != nil) {
                    query.timeOfMostRecentSuccessfulRefresh = Date.timeIntervalSinceReferenceDate
                }
                if (completionHandler != nil) {
                    completionHandler!(qsets)
                }
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                
                self.refreshTimer = Timer.scheduledTimer(timeInterval: self.refreshInterval, target: self, selector: #selector(AppDelegate.refresh), userInfo: nil, repeats: false)
            })
        }
        else {
            self.refreshTimer = Timer.scheduledTimer(timeInterval: timeRemaining, target: self, selector: #selector(AppDelegate.refresh), userInfo: nil, repeats: false)
        }
    }
    
    func cancelRefreshTimer() {
        if (refreshTimer != nil) {
            refreshTimer!.invalidate()
            refreshTimer = nil
        }
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = false

        quizletSession.cancelQueryTasks()
    }
    
    @objc func refresh() {
        let query = dataModel.currentQuery

        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        self.dataModel.refreshModelForCurrentQuery(allowCellularAccess: false, completionHandler: { (qsets: [QSet]?, termCount: Int) in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if (qsets != nil) {
                query!.timeOfMostRecentSuccessfulRefresh = Date.timeIntervalSinceReferenceDate
            }
            UIApplication.shared.isNetworkActivityIndicatorVisible = false

            self.refreshTimer = Timer.scheduledTimer(timeInterval: self.refreshInterval, target: self, selector: #selector(AppDelegate.refresh), userInfo: nil, repeats: false)
        })
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {

        if (url.scheme == "quizletsearch") {
            self.initRootViewControllerWithIdentifier(QueriesViewController)
            
            if (Common.isSampleMode) {
                // Sustitute a sample user, for use when the quizlet authentication server is down
                let userAccount = UserAccount(accessToken: "1234", expiresIn: 3200, userName: "dougzilla32", userId: "1234")
                self.dataModel.addOrUpdateUser(userAccount)
                self.saveContext()
//                self.refreshAndRestartTimer(allowCellularAccess: true)
            }
            else {
                quizletSession.acquireAccessToken(url) {
                    do {
                        let userAccount = try $0()
                        self.dataModel.addOrUpdateUser(userAccount)
                        self.saveContext()
//                        self.refreshAndRestartTimer(allowCellularAccess: true)
                    } catch let error as NSError {
                        let alert = UIAlertView(title: error.localizedDescription, message: error.localizedFailureReason, delegate: nil, cancelButtonTitle: "Dismiss")
                        alert.show()
                        // TODO: should switch to either top-level login window or login list view here (i.e. go back) -- cannot defer switching to search view controller because the switch will fail to happen if it is attempted after the launching phase has completed.  Need to use a navigation controller or some such to make this work
                    }
                }
            }

            return true
        }
        
        return false
    }
    
    func proceedAsGuest(_ name: String?) {
        let username = (name != nil) ? name! : ""
        let userAccount = UserAccount(accessToken: "", expiresIn: 0, userName: username, userId: "")
        
        self.dataModel.addOrUpdateUser(userAccount)
        self.saveContext()
//        self.refreshAndRestartTimer(allowCellularAccess: true)

        self.initRootViewControllerWithIdentifier(QueriesViewController)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    // MARK: - Core Data stack
    
    lazy var applicationDocumentsDirectory: URL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.example.QuizletSearch" in the application's documents Application Support directory.
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1] 
        }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "QuizletSearch", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
        }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        [unowned self] in
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("Temp.sqlite")
        var error: NSError? = nil
        do {
            try coordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch var error as NSError {
            coordinator = nil
            NSLog("Initialization error \(error), \(error.userInfo)")
            
            (UIApplication.shared.delegate as! AppDelegate).initRootViewControllerWithIdentifier(AppDelegate.ErrorViewController)
            
            var reason = String(format: NSLocalizedString("Model load error", comment: ""),
                (error.userInfo["reason"] as! String))
            var alert = UIAlertView(
                title: NSLocalizedString("Initialization error", comment: ""),
                message: reason,
                delegate: self,
                cancelButtonTitle: NSLocalizedString("Exit", comment: ""))
            alert.show()
            return nil
        } catch {
            fatalError()
        }
        
        return coordinator
        }()
    
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        exit(0)
    }
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
        [unowned self] in
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext()
        managedObjectContext.persistentStoreCoordinator = coordinator
        managedObjectContext.undoManager = nil
        return managedObjectContext
        }()
    
    // MARK: - Core Data Saving support
    
    func saveContext() {
        do {
            try dataModel.save()
        } catch let error as NSError {
            NSLog("Save error \(error), \(error.userInfo)")
            let alert = UIAlertView(
                title: NSLocalizedString("Save error", comment: ""),
                message: dataModel.validationMessages(error),
                delegate: nil,
                cancelButtonTitle: NSLocalizedString("Dismiss", comment: ""))
            alert.show()
        }
    }
}

