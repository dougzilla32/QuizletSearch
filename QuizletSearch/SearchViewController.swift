//
//  SearchViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/29/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit
import CoreData
import Foundation

// TODO: updates to termsAtoZ, termsBySet, searchTermsAtoZ, searchTermsBySet and searchTermsBySetAtoZ are not thread safe
class SearchViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var sortStyle: UISegmentedControl!
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    enum SortSelection: Int {
        case AtoZ = 0, BySet, BySetAtoZ
    }
    
    class SortSet {
        let title: String
        let terms: [Term]
        let createdDate: Int64
        
        init(title: String, terms: [Term], createdDate: Int64) {
            self.title = title
            self.terms = terms
            self.createdDate = createdDate
        }
    }
    
    class SortedTerms {
        var AtoZ: [Term]
        var bySet: [SortSet]
        var bySetAtoZ: [SortSet]
        
        init(AtoZ: [Term], bySet: [SortSet], bySetAtoZ: [SortSet]) {
            self.AtoZ = AtoZ
            self.bySet = bySet
            self.bySetAtoZ = bySetAtoZ
        }
        
        func termForPath(indexPath: NSIndexPath, sortSelection: SortSelection) -> Term {
            var term: Term
            switch (sortSelection) {
            case .AtoZ:
                term = AtoZ[indexPath.row]
            case .BySet:
                term = bySet[indexPath.section].terms[indexPath.row]
            case .BySetAtoZ:
                term = bySetAtoZ[indexPath.section].terms[indexPath.row]
            }
            return term
        }
    }
    
    var sortedTerms: SortedTerms = SortedTerms(AtoZ: [], bySet: [], bySetAtoZ: [])
    var searchTerms: SortedTerms = SortedTerms(AtoZ: [], bySet: [], bySetAtoZ: [])
    
    @IBAction func sortStyleChanged(sender: AnyObject) {
        updateSearchTermsForQuery(searchBar.text)
    }
    
    func currentSortSelection() -> SortSelection {
        return SortSelection(rawValue: sortStyle.selectedSegmentIndex)!
    }
    
    // TODO: fix this to work for Korean input -- the characters are combined after shouldChangeTextInRange is called
    func searchBar(searchBar: UISearchBar, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {

        // var newText = (searchBar.text as NSString).stringByReplacingCharactersInRange(range, withString: text)

        // FIXME: this is a hack -- may need to switch to a textfield to get an "Editing Changed" notification when a key is pressed and after Korean character coalesce has happened (haven't tested yet, supposed to work: http://stackoverflow.com/questions/7010547/uitextfield-text-change-event )
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(10000000)), dispatch_get_main_queue(), {
            self.updateSearchTermsForQuery(searchBar.text)
            })

        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        sortedTerms = SearchViewController.initSortedTerms()
        updateSearchTermsForQuery(searchBar.text)
        
        let moc = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "contextDidSaveNotification:",
            name: NSManagedObjectContextDidSaveNotification,
            object: moc)
    }
    
    // call back function by saveContext, support multi-thread
    func contextDidSaveNotification(notification: NSNotification) {
        // TODO: remove debugging println
        // println("contextDidSaveNotification")
        let sender = notification.object as! NSManagedObjectContext
        let info = notification.userInfo! as [NSObject: AnyObject]

        var termsChanged = SearchViewController.containsTerms(info[NSInsertedObjectsKey] as? NSSet)
            || SearchViewController.containsTerms(info[NSDeletedObjectsKey] as? NSSet)
            || SearchViewController.containsTerms(info[NSUpdatedObjectsKey] as? NSSet)

        if (termsChanged) {
            /* TODO: remove debugging println
            println("termsChanged: contextDidSaveNotification --"
                + " inserted: \((info[NSInsertedObjectsKey] as? NSSet)?.count)"
                + " deleted: \((info[NSDeletedObjectsKey] as? NSSet)?.count)"
                + " updated: \((info[NSUpdatedObjectsKey] as? NSSet)?.count)")
            */
            
            var sortedTerms = SearchViewController.initSortedTerms()
            
            // Note: need to call dispatch_sync on the main dispatch queue.  The UI update must happen in the main dispatch queue, and the contextDidSaveNotification cannot return until all objects have been updated.  If a deleted object is used after this method returns then the app will crash with a bad access error.
            dispatch_sync(dispatch_get_main_queue(), {
                self.sortedTerms = sortedTerms
                self.updateSearchTermsForQuery(self.searchBar.text)
            });
        }
    }
    
    class func containsTerms(managedObjectSet: NSSet?) -> Bool {
        if (managedObjectSet == nil) {
            return false
        }
        for object in managedObjectSet! {
            var managedObject = object as! NSManagedObject
            if (managedObject.entity.name == "QuizletSet" || managedObject.entity.name == "Term") {
                return true
            }
        }
        return false
    }
    
    class func initSortedTerms() -> SortedTerms {
        let dataModel = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel
        
        var AtoZ: [Term] = []
        var bySet: [SortSet] = []
        var bySetAtoZ: [SortSet] = []
        
        if let filter = dataModel.currentUser?.currentFilter {
            for set  in filter.sets {
                var quizletSet = set as! QuizletSet
                var termsForSet = [Term]()
                
                for term in quizletSet.terms {
                    var term = (term as! Term)
                    AtoZ.append(term)
                    termsForSet.append(term)
                }
                
                // Use native term order for 'bySet'
                bySet.append(SortSet(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))

                // Use alphabetically sorted terms for 'bySetAtoZ'
                sort(&termsForSet, termComparator)
                bySetAtoZ.append(SortSet(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))
            }
            
            sort(&AtoZ, termComparator)
            
            sort(&bySet, { (s1: SortSet, s2: SortSet) -> Bool in
                return s1.createdDate > s2.createdDate
            })
            
            sort(&bySetAtoZ, { (s1: SortSet, s2: SortSet) -> Bool in
                return s1.title < s2.title
            })
        }
        
        return SortedTerms(AtoZ: AtoZ, bySet: bySet, bySetAtoZ: bySetAtoZ)
    }
    
    class func termComparator(t1: Term, t2: Term) -> Bool {
        switch (t1.term.compare(t2.term)) {
        case .OrderedAscending:
            return true
        case .OrderedDescending:
            return false
        case .OrderedSame:
            return t1.definition < t2.definition
        }
    }
    
    func updateSearchTermsForQuery(query: String) {
        // TODO: put this on the QOS_CLASS_USER_INITIATED queue
        
        switch (currentSortSelection()) {
        case .AtoZ:
            searchTerms.AtoZ = SearchViewController.searchTermsForQuery(query, terms: sortedTerms.AtoZ)
        case .BySet:
            searchTerms.bySet = SearchViewController.searchTermsBySetForQuery(query, termsBySet: sortedTerms.bySet)
        case .BySetAtoZ:
            searchTerms.bySetAtoZ = SearchViewController.searchTermsBySetForQuery(query, termsBySet: sortedTerms.bySetAtoZ)
        }

        tableView.reloadData()
    }
    
    class func searchTermsForQuery(query: String, terms: [Term]) -> [Term] {
        var searchTerms: [Term]
        if (query.isEmpty) {
            searchTerms = terms
        } else {
            searchTerms = []
            var bmp = BoyerMoorePattern(pattern: query)
            for term in terms {
                if (term.term.findIndexOf(pattern: bmp) != nil || term.definition.findIndexOf(pattern: bmp) != nil) {
                    searchTerms.append(term)
                }
            }
            
            /*
            for term in termsAtoZ {
            if (term.term.rangeOfString(text) != nil || term.definition.rangeOfString(text) != nil) {
            searchTermsAtoZ.append(term)
            }
            }
            */
        }
        return searchTerms
    }
    
    class func searchTermsBySetForQuery(query: String, termsBySet: [SortSet]) -> [SortSet] {
        var searchTermsBySet: [SortSet]
        if (query.isEmpty) {
            searchTermsBySet = termsBySet
        } else {
            searchTermsBySet = []
            var bmp = BoyerMoorePattern(pattern: query)
            for quizletSet in termsBySet {
                var termsForSet = [Term]()
                for term in quizletSet.terms {
                    if (term.term.findIndexOf(pattern: bmp) != nil || term.definition.findIndexOf(pattern: bmp) != nil) {
                        termsForSet.append(term)
                    }
                }
                if (termsForSet.count > 0) {
                    searchTermsBySet.append(SortSet(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))
                }
            }
        }
        return searchTermsBySet
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view controller
    
    // The UITableViewController deselects the currently selected row when the table becomes visible.  We are not subclassing UITableViewController because we want to add a custom filter bar, and the UITableViewController does not allow for this.
    override func viewWillAppear(animated: Bool) {
        if let path = tableView.indexPathForSelectedRow() {
            tableView.deselectRowAtIndexPath(path, animated: true)
        }
    }
    
    // The UITableViewController flashes the scrollbar when the table becomes visible.
    override func viewDidAppear(animated: Bool) {
        tableView.flashScrollIndicators()
    }
    
    // The UITableViewController invokes setEditing when startEditing is called.
    func startEditing() {
        setEditing(true, animated: true)
    }
    
    // MARK: - Table view data source
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        var numberOfSections: Int
        switch (currentSortSelection()) {
        case .AtoZ:
            numberOfSections = 1
        case .BySet:
            numberOfSections = searchTerms.bySet.count
        case .BySetAtoZ:
            numberOfSections = searchTerms.bySetAtoZ.count
        }
        return numberOfSections
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        var numberOfRows: Int
        switch (currentSortSelection()) {
        case .AtoZ:
            numberOfRows = searchTerms.AtoZ.count
        case .BySet:
            numberOfRows = searchTerms.bySet[section].terms.count
        case .BySetAtoZ:
            numberOfRows = searchTerms.bySetAtoZ[section].terms.count
        }
        return numberOfRows
    }

    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // fixed font style. use custom view (UILabel) if you want something different
        var title: String?
        switch (currentSortSelection()) {
        case .AtoZ:
            title = nil
        case .BySet:
            title = searchTerms.bySet[section].title
        case .BySetAtoZ:
            title = searchTerms.bySetAtoZ[section].title
        }
        return title
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("termAndDefinition", forIndexPath: indexPath) as! UITableViewCell
        
        var term = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())

        cell.textLabel!.text = "\(term.term)\n\(term.definition)"
        cell.textLabel!.lineBreakMode = .ByWordWrapping
        cell.textLabel!.numberOfLines = 0
        
        var hasImage = false || false
        if (hasImage) {
            cell.accessoryView = UIImageView(image: nil)
        }
    
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        var term = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())

        var text = "\(term.term)\n\(term.definition)"
        // TODO: change to get proper width from table
        var width = CGFloat(200)
        var font = UIFont.boldSystemFontOfSize(14.0)

        var attributedText = NSAttributedString(string: text, attributes: [NSFontAttributeName: font])
        var rect = attributedText.boundingRectWithSize(CGSizeMake(width, CGFloat.max),
            options: NSStringDrawingOptions.UsesLineFragmentOrigin,
            context: nil)
        var size = rect.size
        
        return size.height + 10
    }

    /*
    Basically, to add sections and an index list in the UITableView, you need to deal with these methods as defined in UITableViewDataSource protocol:

    numberOfSectionsInTableView: method – returns the total number of sections in the table view. Usually we set the number of section to 1. If you want to have multiple sections, set this value to a larger number.
    
    titleForHeaderInSection: method – returns the header titles for different sections. This method is optional if you do not assign titles for the section.
    
    numberOfRowsInSection: method – returns the total number of rows in a specific section
    
    cellForRowAtIndexPath: method – this method shouldn’t be new to you if you know how to display data in UITableView. It returns the table data for a particular section.
    
    sectionIndexTitlesForTableView: method – returns the indexed titles that appear in the index list on the right side of the table view. For example, you can return an array of strings containing “A” to “Z”.
    
    sectionForSectionIndexTitle: method – returns the section index that the table view should jump to when user taps a particular index.
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    // Return NO if you do not want the specified item to be editable.
    return true
    }
    */
    
    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete {
    // Delete the row from the data source
    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    } else if editingStyle == .Insert {
    // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
    }
    */
    
    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
    
    }
    */
    
    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    // Return NO if you do not want the item to be re-orderable.
    return true
    }
    */
    
    /*
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    }
    */
    
}

