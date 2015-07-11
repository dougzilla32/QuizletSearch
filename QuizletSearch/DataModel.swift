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
    
    var quizletSession: QuizletSession
    
    var currentUser: User? {
        didSet {
            // if set to different user then clear the current filter (if any)
            // and release the filters and sets for the previous user
            // 1) unfetch them
            // 2) remove references (necessary?)
        }
    }
    
    lazy var root: Root = {
        // Set up root model object
        let request = NSFetchRequest(entityName: "Root")
        request.relationshipKeyPathsForPrefetching = ["users"]
        
        var error: NSError?
        var result = self.moc.executeFetchRequest(request, error: &error) as? [Root]
        if (result == nil) {
            NSLog("An error occurred while fetching the root: \(error), \(error?.userInfo)")
            abort()
        }
        
        var root: Root
        if (result!.count == 1) {
            root = result![0]
        } else if (result!.count == 0) {
            root = NSEntityDescription.insertNewObjectForEntityForName("Root",
                inManagedObjectContext: self.moc) as! Root
            root.users = NSOrderedSet()
        } else {
            NSLog("Unexpected state when loading data model: result.count = \(result!.count)")
            abort()
        }
        
        /*
        // Batch fault the root's users
        let userRequest = NSFetchRequest(entityName: "User")
        userRequest.predicate = NSPredicate(format: "self IN %@", root.users)
        
        var userError: NSError?
        var userResult = self.moc.executeFetchRequest(userRequest, error: &userError) as? [User]
        if (userResult == nil) {
            NSLog("An error occurred while fetching the root: \(userError), \(userError?.userInfo)")
            abort()
        }
        
        println("ROOT USERS:")
        for user in userResult! {
            println("  \(user.name)")
            println("  FILTERS:")
            for filter in user.filters {
                var f: Filter = filter as! Filter
                println("    \(f.title)")
            }
        }
        */
        
        return root
    }()

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
    
    init(managedObjectContext: NSManagedObjectContext, quizletSession: QuizletSession) {
        moc = managedObjectContext
        
        self.quizletSession = quizletSession
        
        // Set up current user
        if let userId = NSUserDefaults.standardUserDefaults().stringForKey("currentUser") {
            currentUser = fetchUserWithId(userId)
            if (currentUser != nil) {
                self.quizletSession.currentUser = UserAccount(accessToken: currentUser!.accessToken, expiresIn: currentUser!.expiresIn(), userName: currentUser!.name, userId: currentUser!.id)
            }
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
        let request = NSFetchRequest(entityName: "User")
        request.predicate = NSPredicate(format: "id == %@", userId)
        request.relationshipKeyPathsForPrefetching = ["filters"]
        
        var error: NSError?
        var users = moc.executeFetchRequest(request, error: &error) as? [User]
        if (users == nil) {
            NSLog("An error occurred while fetching the list of users: \(error), \(error?.userInfo)")
            return nil
        }
        if (users!.count == 0) {
            return nil
        }

        return users![0]
    }
    
    func addOrUpdateUser(userAccount: UserAccount) -> User {
        var user = fetchUserWithId(userAccount.userId)
        if (user == nil) {
            var newUser = NSEntityDescription.insertNewObjectForEntityForName("User",
                inManagedObjectContext: moc) as! User
            newUser.root = self.root
            newUser.currentFilter = createDefaultFilterForUser(newUser)
            newUser.currentFilter.currentUser = newUser
            newUser.filters = NSOrderedSet(object: newUser.currentFilter)

            var mutableUsers = root.users.mutableCopy() as! NSMutableOrderedSet
            mutableUsers.addObject(newUser)
            self.root.users = mutableUsers.copy() as! NSOrderedSet

            user = newUser
        }
        user!.copyFrom(userAccount)
        
        if (currentUser != user) {
            currentUser = user
            NSUserDefaults.standardUserDefaults().setObject(user!.id, forKey: "currentUser")
        }
        
        return user!
    }
    
    func createDefaultFilterForUser(user: User) -> Filter {
        var filter = NSEntityDescription.insertNewObjectForEntityForName("Filter",
            inManagedObjectContext: moc) as! Filter
        filter.type = FilterType.CurrentUserAllSets.rawValue
        filter.title = "My Sets"
        filter.query = ""
        filter.queryTerm = ""
        filter.queryCreator = ""
        filter.user = user
        filter.sets = NSSet()
        return filter
    }
    
    func refreshModelForCurrentFilter() {
        if (currentUser == nil) {
            return
        }
        
        var currentFilter = currentUser!.currentFilter
        var filterType = FilterType(rawValue: currentFilter.type)
        if (filterType == nil) {
            NSLog("Invalid filter type found in data store: \(currentFilter.type)")
            return
        }
        
        switch (filterType!) {
        case .CurrentUserAllSets:
            quizletSession.getAllSetsForUser(currentUser!.name,
                completionHandler: { (qsets: [QSet]?) in
                    self.updateSetsForFilter(currentFilter, qsets: qsets)
                })
        case .CurrentUserFavorites:
            quizletSession.getFavoriteSetsForUser(currentUser!.name)
        case .GeneralQuery:
            println("General Query")
        }
    }
    
    func updateSetsForFilter(filter: Filter, qsets: [QSet]?) {
        if (qsets == nil) {
            return
        }
        
        var oldSetMap = [Int64: QuizletSet]()
        for set in filter.sets {
            var qset = set as! QuizletSet
            oldSetMap[qset.id] = qset
        }
        
        var setsToUpdate = [QSet]()
        var setsToFetch = [QSet]()

        for qset in qsets! {
            var existingSet = oldSetMap.removeValueForKey(qset.id)
            if (existingSet != nil) {
                setsToUpdate.append(qset)
            } else {
                setsToFetch.append(qset)
            }
        }
        
        // The sets remaining in 'oldSetMap' are to be deleted if the are not referenced by any other filter
        
        
        // The 'setsToUpdate' are to have their list of terms updated
        
        // The 'setsToFetch' are to be fetched -- if a set already exists, update its terms and add  'filter' to its list of filters.
        
        
        println("Update sets for filter: \(filter.title)")
        for qset in qsets! {
            println("  \(qset.title)")
        }
        
    }
    
    private func updateTermsFromSet(fromSet: QSet, toSet: QuizletSet) {
        // HINT: use NSMutableOrderedSet replaceObjectsInRange()
    }
    
    /*
    func fetchFiltersForCurrentUser() {
        if (currentUser == nil) {
            NSLog("Invalid call to 'fetchUsers': currentUser is not set")
            return
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

    func saveContext(error: NSErrorPointer) -> Bool {
        if (moc.hasChanges) {
            return moc.save(error);
        } else {
            return true
        }
    }
    
    func validationMessages(anError: NSError) -> String? {
        if (anError.domain != "NSCocoaErrorDomain") {
            return nil
        }
        
        var errors: [NSError]?
        
        // multiple errors?
        if (anError.code == NSValidationMultipleErrorsError) {
            errors = anError.userInfo?[NSDetailedErrorsKey] as! [NSError]?
        } else {
            errors = [anError]
        }
        
        if (errors == nil || errors!.count == 0) {
            return nil
        }
        
        var messages = "Reason(s):\n"
        
        for error in errors! {
            var entityName = (error.userInfo!["NSValidationErrorObject"] as! NSManagedObject).entity.name
            var attributeName = error.userInfo!["NSValidationErrorKey"] as! String
            var msg: String
            switch (error.code) {
            case NSManagedObjectValidationError:
                msg = "Generic validation error."
            case NSValidationMissingMandatoryPropertyError:
                msg = String(format: "The attribute '%@' mustn't be empty.", attributeName)
            case NSValidationRelationshipLacksMinimumCountError:
                msg = String(format: "The relationship '%@' doesn't have enough entries.", attributeName)
            case NSValidationRelationshipExceedsMaximumCountError:
                msg = String(format: "The relationship '%@' has too many entries.", attributeName)
            case NSValidationRelationshipDeniedDeleteError:
                msg = String(format: "To delete, the relationship '%@' must be empty.", attributeName)
            case NSValidationNumberTooLargeError:
                msg = String(format: "The number of the attribute '%@' is too large.", attributeName)
            case NSValidationNumberTooSmallError:
                msg = String(format: "The number of the attribute '%@' is too small.", attributeName)
            case NSValidationDateTooLateError:
                msg = String(format: "The date of the attribute '%@' is too late.", attributeName)
            case NSValidationDateTooSoonError:
                msg = String(format: "The date of the attribute '%@' is too soon.", attributeName)
            case NSValidationInvalidDateError:
                msg = String(format: "The date of the attribute '%@' is invalid.", attributeName)
            case NSValidationStringTooLongError:
                msg = String(format: "The text of the attribute '%@' is too long.", attributeName)
            case NSValidationStringTooShortError:
                msg = String(format: "The text of the attribute '%@' is too short.", attributeName)
            case NSValidationStringPatternMatchingError:
                msg = String(format: "The text of the attribute '%@' doesn't match the required pattern.", attributeName)
            default:
                msg = String(format: "Unknown error (code %i).", error.code)
            }
            
            if (entityName != nil) {
                messages += entityName! + ": " + msg + "\n"
            } else {
                messages += msg + "\n"
            }
        }
        return messages
    }
}
