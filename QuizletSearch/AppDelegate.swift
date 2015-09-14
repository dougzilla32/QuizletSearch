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
    
    lazy var dataModel: DataModel = {
        return DataModel(managedObjectContext: self.managedObjectContext!, quizletSession: self.quizletSession)
    }()
    
    var refreshTimer: NSTimer?
    
    func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {

        var id: String
        if (managedObjectContext != nil) {
            id = (dataModel.currentUser == nil) ? "LoginViewController" : "SearchViewController"
        } else {
            id = "ErrorViewController"
        }
        
        setRootViewControllerWithIdentifier(id)

        return true
    }
    
    func setRootViewControllerWithIdentifier(id: String) {
        let storyboard = self.window!.rootViewController!.storyboard!
        self.window!.rootViewController = storyboard.instantiateViewControllerWithIdentifier(id)
    }
    
    func application(application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        // Tells the delegate that the launch process is almost done and the app is almost ready to run.
        return true
    }
    
    func refreshAndRestartTimer(allowCellularAccess allowCellularAccess: Bool, completionHandler: (([QSet]?) -> Void)? = nil) {
        if (managedObjectContext == nil || dataModel.currentUser == nil) {
            return
        }

        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        // Refresh the data model
        self.dataModel.refreshModelForCurrentFilter(allowCellularAccess: allowCellularAccess, completionHandler: { (qsets: [QSet]?) in
            if (completionHandler != nil) {
                completionHandler!(qsets)
            }
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        })
        
        if (refreshTimer != nil) {
            refreshTimer!.invalidate()
        }
        refreshTimer = NSTimer.scheduledTimerWithTimeInterval(60 * 5, target: self, selector: "refresh", userInfo: nil, repeats: true)
    }
    
    func cancelRefreshTimer() {
        if (refreshTimer != nil) {
            refreshTimer!.invalidate()
            refreshTimer = nil
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }
    
    func refresh() {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        self.dataModel.refreshModelForCurrentFilter(allowCellularAccess: false, completionHandler: { (qsets: [QSet]?) in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        })
    }
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {

        if (url.scheme == "quizletsearch") {
            self.setRootViewControllerWithIdentifier("SearchViewController")
            
            if (Common.isSampleMode) {
                // Sustitute a sample user, for use when the quizlet authentication server is down
                let userAccount = UserAccount(accessToken: "1234", expiresIn: 3200, userName: "dougzilla32", userId: "1234")
                self.dataModel.addOrUpdateUser(userAccount)
                self.saveContext()
                self.refreshAndRestartTimer(allowCellularAccess: true)
            }
            else {
                quizletSession.acquireAccessToken(url,
                    completionHandler: { (userAccount: UserAccount?, error: NSError?) in
                        if let err = error {
                            let alert = UIAlertView(title: err.localizedDescription, message: err.localizedFailureReason, delegate: nil, cancelButtonTitle: "Dismiss")
                            alert.show()
                            // TODO: should switch to either top-level login window or login list view here (i.e. go back) -- cannot defer switching to search view controller because the switch will fail to happen if it is attempted after the launching phase has completed.  Need to use a navigation controller or some such to make this work
                        } else {
                            self.dataModel.addOrUpdateUser(userAccount!)
                            self.saveContext()
                            self.refreshAndRestartTimer(allowCellularAccess: true)
                        }
                })
            }

            return true
        }
        
        return false
    }
    
    func proceedAsGuest(username: String?) {
        self.setRootViewControllerWithIdentifier("SearchViewController")

        let userAccount = UserAccount(accessToken: "", expiresIn: 0, userName: "dougzilla32", userId: "")
        self.dataModel.addOrUpdateUser(userAccount)
        self.saveContext()
        self.refreshAndRestartTimer(allowCellularAccess: true)
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    // MARK: - Core Data stack
    
    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.example.QuizletSearch" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] 
        }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("QuizletSearch", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
        }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("Temp.sqlite")
        var error: NSError? = nil
        do {
            try coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
        } catch var error as NSError {
            coordinator = nil
            NSLog("Initialization error \(error), \(error.userInfo)")
            
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
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        exit(0)
    }
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
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

