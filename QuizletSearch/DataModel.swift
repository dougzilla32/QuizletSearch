//
//  DataModel.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/27/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation
import CoreData

class DataModel {
    var moc: NSManagedObjectContext

    var currentUser: User? {
        didSet {
            // if set to different user then clear the current filter (if any)
            // and release the filters and sets for the previous user
            // 1) unfetch them
            // 2) remove references (necessary?)
        }
    }

    /*
    var filters: [Filter]?
    
    var currentFilter: Filter? {
        willSet {
            var newUser = newValue?.user
            if (newUser != currentUser) {
                currentUser = newUser
            }
        }
        
        didSet {
            // clear the existing filter, if any
        }
    }
    */
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.moc = managedObjectContext
        if let userId = NSUserDefaults.standardUserDefaults().stringForKey("currentUser") {
            currentUser = fetchUserWithId(userId)
        }
    }
    
    func save() {
        var error: NSError?
        var users = moc.save(&error)
        if (error != nil) {
            NSLog("An error occurred while saving: \(error), \(error?.userInfo)")
        }
    }
    
    func fetchUsers() -> [User]? {
        let fetchRequest = NSFetchRequest(entityName: "User")
        
        var error: NSError?
        var users = moc.executeFetchRequest(fetchRequest, error: &error) as? [User]
        if (users == nil) {
            NSLog("An error occurred while fetching the list of users: \(error), \(error?.userInfo)")
            users = nil
        }
        
        return users
    }
    
    func fetchUserWithId(userId: String) -> User? {
        let fetchRequest = NSFetchRequest(entityName: "User")
        fetchRequest.predicate = NSPredicate(format: "id == %@", userId)
        
        var error: NSError?
        var users = moc.executeFetchRequest(fetchRequest, error: &error) as? [User]
        if (users == nil) {
            NSLog("An error occurred while fetching the list of users: \(error), \(error?.userInfo)")
            return nil
        }
        if (users!.count == 0) {
            return nil
        }

        return users![0]
    }
    
    func addOrUpdateUser(userAccount: UserAccount) {
        var user = fetchUserWithId(userAccount.userId)
        if (user == nil) {
            var newUser = NSEntityDescription.insertNewObjectForEntityForName("User",
                inManagedObjectContext: moc) as! User
            var newFilter = NSEntityDescription.insertNewObjectForEntityForName("Filter",
                inManagedObjectContext: moc) as! Filter
            // title, query, user, sets
            newFilter.title = "My Sets"
            newFilter.query = "*"
            newFilter.user = newUser
            newUser.filters = NSOrderedSet(array: [newFilter])

            user = newUser
        }
        user!.copyFrom(userAccount)
        save()
        
        if (currentUser != user) {
            currentUser = user
            NSUserDefaults.standardUserDefaults().setObject(user!.id, forKey: "currentUser")
        }
    }
        
    /*
    func fetchFilters() -> [Filter]? {
        if (currentUser == nil) {
            NSLog("Invalid call to 'fetchUsers': currentUser is not set")
            return nil
        }

        let fetchRequest = NSFetchRequest(entityName: "Filter")
        fetchRequest.predicate = NSPredicate(format: "user == %@", currentUser!)
        
        var error: NSError?
        let filters = moc.executeFetchRequest(fetchRequest, error: &error) as? [Filter]
        if (users == nil) {
            NSLog("An error occurred while fetching the list of filters for user \(currentUser!.name): \(error), \(error?.userInfo)")
        }
        
        self.filters = filters
        return filters
    }
    */
}
