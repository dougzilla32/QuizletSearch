//
//  DataModel.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/27/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation
import CoreData

class DataModel: NSObject {
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
        
        var result: [Root]
        do {
            result = try self.moc.executeFetchRequest(request) as! [Root]
        } catch let error as NSError {
            NSLog("An error occurred while fetching the root: \(error), \(error.userInfo)")
            fatalError()
        }
        
        var root: Root
        if (result.count == 1) {
            root = result[0]
        } else if (result.count == 0) {
            root = NSEntityDescription.insertNewObjectForEntityForName("Root",
                inManagedObjectContext: self.moc) as! Root
            root.users = NSOrderedSet()
        } else {
            NSLog("Unexpected state when loading data model: result.count = \(result.count)")
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
        
        super.init()
        
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
        
        var users: [User]?
        do {
            users = try moc.executeFetchRequest(fetchRequest) as? [User]
        } catch let error as NSError {
            NSLog("An error occurred while fetching the list of users: \(error), \(error.userInfo)")
            users = nil
        }
        
        return users
    }
    
    func fetchUserWithId(userId: String) -> User? {
        let request = NSFetchRequest(entityName: "User")
        request.predicate = NSPredicate(format: "id == %@", userId)
        request.relationshipKeyPathsForPrefetching = ["filters"]
        
        var users: [User]?
        do {
            users = try moc.executeFetchRequest(request) as? [User]
        } catch let error as NSError {
            NSLog("An error occurred while fetching the list of users: \(error), \(error.userInfo)")
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
            let newUser = NSEntityDescription.insertNewObjectForEntityForName("User",
                inManagedObjectContext: moc) as! User
            newUser.root = self.root
            newUser.currentFilter = createDefaultFilterForUser(newUser)
            newUser.currentFilter.currentFilter = newUser
            newUser.filters = NSOrderedSet(object: newUser.currentFilter)

            let mutableUsers = root.users.mutableCopy() as! NSMutableOrderedSet
            mutableUsers.addObject(newUser)
            self.root.users = mutableUsers.copy() as! NSOrderedSet

            user = newUser
        }
        user!.copyFrom(userAccount)
        
        if (currentUser != user) {
            currentUser = user
            self.quizletSession.currentUser = userAccount
            NSUserDefaults.standardUserDefaults().setObject(user!.id, forKey: "currentUser")
        }
        
        return user!
    }
    
    func createDefaultFilterForUser(user: User) -> Filter {
        let filter = NSEntityDescription.insertNewObjectForEntityForName("Filter",
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
    
    func refreshModelForCurrentFilter(allowCellularAccess allowCellularAccess: Bool, completionHandler: ([QSet]?) -> Void) {
        if (currentUser == nil) {
            return
        }
        
        let currentFilter = currentUser!.currentFilter
        let filterType = FilterType(rawValue: currentFilter.type)
        if (filterType == nil) {
            NSLog("Invalid filter type found in data store: \(currentFilter.type)")
            completionHandler(nil)
            return
        }
        
        switch (filterType!) {
        case .CurrentUserAllSets:
            var getAllSetsForUserFunction = quizletSession.getAllSetsForUser
            if (Common.isSampleMode) {
                getAllSetsForUserFunction = quizletSession.getAllSampleSetsForUser
            }
            
            getAllSetsForUserFunction(currentUser!.name, modifiedSince: currentFilter.maxModifiedDate, allowCellularAccess: allowCellularAccess,
                completionHandler: { (qsets: [QSet]?) in
                    if (qsets != nil) {
                        self.updateTermsForFilter(currentFilter, qsets: qsets)
                    }
                    completionHandler(qsets)
            })
        case .CurrentUserFavorites:
            quizletSession.getFavoriteSetsForUser(currentUser!.name, modifiedSince: 0, allowCellularAccess: allowCellularAccess,
                completionHandler: { (qsets: [QSet]?) in
            })
        case .GeneralQuery:
            print("General Query")
        }
    }
    
    func updateTermsForFilter(filter: Filter, qsets: [QSet]?) {
        if (qsets == nil || qsets!.count == 0) {
            return
        }
        
        defer {
            saveChanges()
        }
        
        // Put all of the filter's sets into a dictionary
        var existingSetsMap = [Int64: QuizletSet]()
        for set in filter.sets {
            let quizletSet = set as! QuizletSet
            existingSetsMap[quizletSet.id] = quizletSet
        }
        
        // UPDATE: Update sets that are already members of the filter and make a list of the sets that are not, to be fetched from other filters if they exist elsewhere in the cache or else created
        var setsToFetch = [QSet]()
        var idsToFetch = [NSNumber]()
        var maxModifiedDate: Int64 = 0
        for qset in qsets! {
            let existingSet = existingSetsMap.removeValueForKey(qset.id)
            if (existingSet != nil) {
                existingSet!.copyFrom(qset, moc: moc)
            } else {
                setsToFetch.append(qset)
                idsToFetch.append(NSNumber(longLong: qset.id))
            }
            maxModifiedDate = max(qset.modifiedDate, maxModifiedDate)
        }
        if (filter.maxModifiedDate != maxModifiedDate) {
            filter.maxModifiedDate = maxModifiedDate
        }
        
        if (existingSetsMap.count == 0 && setsToFetch.count == 0) {
            // Unnecessary to update the 'filter.sets' relationships where there are no sets to add and no sets to delete
            return
        }
        
        let mutableFilterSets = filter.sets.mutableCopy() as! NSMutableSet

        // DELETE: Remove the filter reference from the sets remaining in 'existingSetsMap' (that have either been deleted from quizlet.com or no longer match this filter) and delete them from the cache if they are not referenced by any other filter
        for set in existingSetsMap.values {
            let mutableSet = set.filters.mutableCopy() as! NSMutableSet
            mutableSet.removeObject(filter)
            set.filters = mutableSet.copy() as! NSSet
            if (set.filters.count == 0) {
                moc.deleteObject(set)
            }

            mutableFilterSets.removeObject(set)
        }
        
        // ADD: The 'setsToFetch' are to be fetched -- if a set already exists because it has been cached by a different filter, then update its terms and add  'filter' to its list of filters.  Otherwise create a new set.
        if (setsToFetch.count > 0) {
            let updateSetsRequest = NSFetchRequest(entityName: "QuizletSet")
            updateSetsRequest.predicate = NSPredicate(format: "id IN %@", idsToFetch)
            
            var updateSetsResult: [QuizletSet]?
            do {
                updateSetsResult = try self.moc.executeFetchRequest(updateSetsRequest) as? [QuizletSet]
            } catch let error as NSError {
                NSLog("An error occurred while fetching sets: \(error), \(error.userInfo)")
                fatalError()
            }
            
            var updateSetsMap = [Int64: QuizletSet]()
            for set in updateSetsResult! {
                updateSetsMap[set.id] = set
            }
            
            for qset in setsToFetch {
                if let quizletSet = updateSetsMap[qset.id] {
                    quizletSet.copyFrom(qset, moc: moc)
                    
                    let mutableSet = quizletSet.filters.mutableCopy() as! NSMutableSet
                    mutableSet.addObject(filter)
                    quizletSet.filters = mutableSet.copy() as! NSSet
                    
                    mutableFilterSets.addObject(quizletSet)
                } else {
                    let quizletSet = NSEntityDescription.insertNewObjectForEntityForName("QuizletSet", inManagedObjectContext: moc) as! QuizletSet
                    quizletSet.initFrom(qset, moc: moc)
                    quizletSet.filters = NSSet(object: filter)
                    
                    mutableFilterSets.addObject(quizletSet)
                }
            }
        }
        
        filter.sets = mutableFilterSets.copy() as! NSSet
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
    
    func saveChanges() {
        if (moc.hasChanges) {
            do {
                try moc.save()
            } catch let error as NSError {
                NSLog("Save error \(error), \(error.userInfo)")
            }
        }
    }

    func save() throws {
        if (moc.hasChanges) {
            try moc.save()
        }
    }
    
    func validationMessages(anError: NSError) -> String? {
        if (anError.domain != "NSCocoaErrorDomain") {
            return nil
        }
        
        var errors: [NSError]?
        
        // multiple errors?
        if (anError.code == NSValidationMultipleErrorsError) {
            errors = anError.userInfo[NSDetailedErrorsKey] as! [NSError]?
        } else {
            errors = [anError]
        }
        
        if (errors == nil || errors!.count == 0) {
            return nil
        }
        
        var messages = "Reason(s):\n"
        
        for error in errors! {
            let entityName = (error.userInfo["NSValidationErrorObject"] as! NSManagedObject).entity.name
            let attributeName = error.userInfo["NSValidationErrorKey"] as! String
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
