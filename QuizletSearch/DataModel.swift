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
    var currentUser: User?
    var currentQuery: Query?
    
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
        
        print("ROOT USERS:")
        for user in userResult! {
            print("  \(user.name)")
            print("  QUERIES:")
            for query in user.queries {
                var f: Query = query as! Query
                print("    \(f.title)")
            }
        }
        */
        
        return root
    }()

    /*
    var queries: [Query]?
    
    var currentQuery: Query? {
        willSet {
            var newUser = newValue?.user
            if (newUser != currentUser) {
                currentUser = newUser
            }
        }
        
        didSet {
            // clear the existing query, if any
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
                currentQuery = currentUser!.queries.firstObject as? Query
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
        request.relationshipKeyPathsForPrefetching = ["queries"]
        
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
            newUser.copyFrom(userAccount)
            
            let query = newQueryForUser(newUser)
            query.title = "My Sets"
            newUser.queries = NSOrderedSet(object: query)

            let mutableUsers = root.users.mutableCopy() as! NSMutableOrderedSet
            mutableUsers.addObject(newUser)
            self.root.users = mutableUsers.copy() as! NSOrderedSet

            user = newUser
        }
        else {
            user!.copyFrom(userAccount)
        }
        
        if (currentUser != user) {
            currentUser = user
            self.quizletSession.currentUser = userAccount
            NSUserDefaults.standardUserDefaults().setObject(user!.id, forKey: "currentUser")
        }
        
        currentQuery = currentUser?.queries.firstObject as? Query
        return user!
    }
    
    func deleteUser(user: User) {
        moc.deleteObject(user)
    }
    
    func newQueryForUser(user: User) -> Query {
        let query = NSEntityDescription.insertNewObjectForEntityForName("Query",
            inManagedObjectContext: moc) as! Query
        query.title = ""
        query.query = ""
        query.creators = ""
        query.classes = ""
        query.includedSets = ""
        query.excludedSets = ""
        query.maxModifiedDate = 0
        query.user = user
        query.sets = NSSet()
        return query
    }
    
    func deleteQuery(query: Query) {
        moc.deleteObject(query)
    }
    
    func refreshModelForCurrentQuery(allowCellularAccess allowCellularAccess: Bool, completionHandler: ([QSet]?, Int) -> Void) {
        guard let q = currentQuery else {
            return
        }
        
        let pagers = QueryPagers(query: q)

        pagers.executeFullSearch(completionHandler: { (qsets: [QSet]?, termCount: Int) in
            self.updateTermsForQuery(q, qsets: qsets)
            completionHandler(qsets, termCount)
        })
    }
    
    class Creator {
        let username: String
        let folder: String?
        
        init(username: String, folder: String?) {
            self.username = username
            self.folder = folder
        }
        
        func isFavoritesFolder() -> Bool {
            return folder == "favorites"
        }
    }
    
    class func parseCreators(creatorsString: String) -> [Creator] {
        var creators = [Creator]()
        for c in creatorsString.componentsSeparatedByString(",") {
            let parts = c.componentsSeparatedByString(":")
            switch (parts.count) {
            case 1:
                creators.append(Creator(username: parts[0], folder: nil))
            case 2:
                creators.append(Creator(username: parts[0], folder: parts[1]))
            default:
                abort()
            }
        }
        return creators
    }
    
    func updateTermsForQuery(query: Query, qsets: [QSet]?) {
        if (qsets == nil || qsets!.count == 0) {
            return
        }
        
        defer {
            saveChanges()
        }
        
        // Put all of the queries' sets into a dictionary
        var existingSetsMap = [Int64: QuizletSet]()
        for set in query.sets {
            let quizletSet = set as! QuizletSet
            existingSetsMap[quizletSet.id] = quizletSet
        }
        
        // UPDATE: Update sets that are already members of the query and make a list of the sets that are not, to be fetched from other queries if they exist elsewhere in the cache or else created
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
        if (query.maxModifiedDate != maxModifiedDate) {
            query.maxModifiedDate = maxModifiedDate
        }
        
        if (existingSetsMap.count == 0 && setsToFetch.count == 0) {
            // Unnecessary to update the 'query.sets' relationships where there are no sets to add and no sets to delete
            return
        }
        
        let mutableQuerySets = query.sets.mutableCopy() as! NSMutableSet

        // DELETE: Remove the query reference from the sets remaining in 'existingSetsMap' (that have either been deleted from quizlet.com or no longer match this query) and delete them from the cache if they are not referenced by any other query
        for set in existingSetsMap.values {
            let mutableSet = set.queries.mutableCopy() as! NSMutableSet
            mutableSet.removeObject(query)
            set.queries = mutableSet.copy() as! NSSet
            if (set.queries.count == 0) {
                moc.deleteObject(set)
            }

            mutableQuerySets.removeObject(set)
        }
        
        // ADD: The 'setsToFetch' are to be fetched -- if a set already exists because it has been cached by a different query, then update its terms and add  'query' to its list of queries.  Otherwise create a new set.
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
                    
                    let mutableSet = quizletSet.queries.mutableCopy() as! NSMutableSet
                    mutableSet.addObject(query)
                    quizletSet.queries = mutableSet.copy() as! NSSet
                    
                    mutableQuerySets.addObject(quizletSet)
                } else {
                    let quizletSet = NSEntityDescription.insertNewObjectForEntityForName("QuizletSet", inManagedObjectContext: moc) as! QuizletSet
                    quizletSet.initFrom(qset, moc: moc)
                    quizletSet.queries = NSSet(object: query)
                    
                    mutableQuerySets.addObject(quizletSet)
                }
            }
        }
        
        query.sets = mutableQuerySets.copy() as! NSSet
    }
    
    /*
    func fetchQueriesForCurrentUser() {
        if (currentUser == nil) {
            NSLog("Invalid call to 'fetchUsers': currentUser is not set")
            return
        }

        let fetchRequest = NSFetchRequest(entityName: "Query")
        fetchRequest.predicate = NSPredicate(format: "user == %@", currentUser!)
        
        var error: NSError?
        let queries = moc.executeFetchRequest(fetchRequest, error: &error) as? [Query]
        if (users == nil) {
            NSLog("An error occurred while fetching the list of queries for user \(currentUser!.name): \(error), \(error?.userInfo)")
        }
        
        self.queries = queries
        return queries
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
