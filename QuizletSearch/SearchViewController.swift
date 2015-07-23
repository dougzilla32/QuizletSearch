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

class SearchViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var sortStyle: UISegmentedControl!
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    var refreshControl: UIRefreshControl!
    
    // MARK: - Sorting
    
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
    
    // MARK: - Search Bar
    
    // called when text changes (including clear)
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String)    {
        updateSearchTermsForQuery(searchBar.text)
    }
    
    // MARK: - View Controller
        
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> Int {
        return Int(UIInterfaceOrientationMask.All.rawValue)
    }

    override func loadView() {
        super.loadView()
        (UIApplication.sharedApplication().delegate as! AppDelegate).refreshAndRestartTimer(allowCellularAccess: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // TODO: set the font for the text field as follows after upgrading to XCode 7
        // UITextField.appearanceWhenContainedInInstancesOfClasses([UISearchBar.Type]).font = UIFont(name: "Helvetica", size: 24)

        // Initialize the refresh control -- this is necessary because we aren't using a UITableViewController.  Normally you would set "Refreshing" to "Enabled" on the table view controller.  So instead we are initializing it programatically.
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "refreshTable", forControlEvents: UIControlEvents.ValueChanged)
        tableView.addSubview(refreshControl)
        tableView.sendSubviewToBack(refreshControl)

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        sortedTerms = SearchViewController.initSortedTerms()
        updateSearchTermsForQuery(searchBar.text)
        
        // Register for keyboard show and hide notifications, to adjust the table view when the keyboard is showing
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)

        let moc = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "contextDidSaveNotification:",
            name: NSManagedObjectContextDidSaveNotification,
            object: moc)
    }
    
    // Called after the view was dismissed, covered or otherwise hidden.
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        self.refreshControl.endRefreshing()
    }
    
    // MARK: - Search View Controller
    
    @IBAction func unwindToSearchView(segue: UIStoryboardSegue) {
        (UIApplication.sharedApplication().delegate as! AppDelegate).refreshAndRestartTimer(allowCellularAccess: true)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
 
    func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
    
            var contentInsets: UIEdgeInsets
            if (UIInterfaceOrientationIsPortrait(UIApplication.sharedApplication().statusBarOrientation)) {
                contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height, 0.0);
            } else {
                contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.width, 0.0);
            }
    
            self.tableView.contentInset = contentInsets;
            self.tableView.scrollIndicatorInsets = contentInsets;
        }
    }

    func keyboardWillHide(notification: NSNotification) {
        self.tableView.contentInset = UIEdgeInsetsZero
        self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero
    }
    
    func refreshTable() {
        (UIApplication.sharedApplication().delegate as! AppDelegate).refreshAndRestartTimer(allowCellularAccess: true, completionHandler: { (qsets: [QSet]?) in
            self.refreshControl.endRefreshing()
        })
    }
    
    // call back function by saveContext, support multi-thread
    func contextDidSaveNotification(notification: NSNotification) {
        let sender = notification.object as! NSManagedObjectContext
        let info = notification.userInfo! as [NSObject: AnyObject]

        var termsChanged = SearchViewController.containsTerms(info[NSInsertedObjectsKey] as? NSSet)
            || SearchViewController.containsTerms(info[NSDeletedObjectsKey] as? NSSet)
            || SearchViewController.containsTerms(info[NSUpdatedObjectsKey] as? NSSet)

        if (termsChanged) {
            /*
            println("termsChanged: contextDidSaveNotification --"
                + " inserted: \((info[NSInsertedObjectsKey] as? NSSet)?.count)"
                + " deleted: \((info[NSDeletedObjectsKey] as? NSSet)?.count)"
                + " updated: \((info[NSUpdatedObjectsKey] as? NSSet)?.count)")
            
            if let inserted = info[NSInsertedObjectsKey] as? NSSet {
                for obj in inserted {
                    let managedObj = obj as! NSManagedObject
                    println("insert: \(managedObj)")
                }
            }
            if let deleted = info[NSDeletedObjectsKey] as? NSSet {
                for obj in deleted {
                    let managedObj = obj as! NSManagedObject
                    println("delete: \(managedObj)")
                }
            }
            if let updated = info[NSUpdatedObjectsKey] as? NSSet {
                for obj in updated {
                    let managedObj = obj as! NSManagedObject
                    println("update: \(managedObj)")
                }
            }
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
                return s1.title.compare(s2.title, options: NSStringCompareOptions.CaseInsensitiveSearch | NSStringCompareOptions.NumericSearch) != .OrderedDescending
            })
        }
        
        return SortedTerms(AtoZ: AtoZ, bySet: bySet, bySetAtoZ: bySetAtoZ)
    }
    
    class func termComparator(t1: Term, t2: Term) -> Bool {
        switch (t1.term.compare(t2.term, options: NSStringCompareOptions.CaseInsensitiveSearch | NSStringCompareOptions.NumericSearch)) {
        case .OrderedAscending:
            return true
        case .OrderedDescending:
            return false
        case .OrderedSame:
            return t1.definition.compare(t2.definition, options: NSStringCompareOptions.CaseInsensitiveSearch | NSStringCompareOptions.NumericSearch) != .OrderedDescending
        }
    }
    
    func updateSearchTermsForQuery(query: String) {
        // TODO: possibly put this on the QOS_CLASS_USER_INITIATED queue, test if there is noticable lag for a keystroke.  And try it with and without the queue, see if there is a discernable difference
        
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
            /*
            var bmp = BoyerMoorePattern(pattern: query)
            for term in terms {
                if (term.term.findIndexOf(pattern: bmp) != nil || term.definition.findIndexOf(pattern: bmp) != nil) {
                    searchTerms.append(term)
                }
            }
            */
            
            for term in terms {
                if (term.term.rangeOfString(query, options: NSStringCompareOptions.CaseInsensitiveSearch) != nil || term.definition.rangeOfString(query, options: NSStringCompareOptions.CaseInsensitiveSearch) != nil) {
                    searchTerms.append(term)
                }
            }
        }
        return searchTerms
    }
    
    class func searchTermsBySetForQuery(query: String, termsBySet: [SortSet]) -> [SortSet] {
        var searchTermsBySet: [SortSet]
        if (query.isEmpty) {
            searchTermsBySet = termsBySet
        } else {
            searchTermsBySet = []
            // var bmp = BoyerMoorePattern(pattern: query)
            for quizletSet in termsBySet {
                var termsForSet = [Term]()

                /*
                for term in quizletSet.terms {
                    if (term.term.findIndexOf(pattern: bmp) != nil || term.definition.findIndexOf(pattern: bmp) != nil) {
                        termsForSet.append(term)
                    }
                }
                */
                
                for term in quizletSet.terms {
                    if (term.term.rangeOfString(query, options: NSStringCompareOptions.CaseInsensitiveSearch) != nil || term.definition.rangeOfString(query, options: NSStringCompareOptions.CaseInsensitiveSearch) != nil) {
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
        // TODO: Dispose of any data model resources that can be refetched
    }
    
    // MARK: - Table view controller
    
    // The UITableViewController deselects the currently selected row when the table becomes visible.  We are not subclassing UITableViewController because we want to add a custom filter bar, and the UITableViewController does not allow for this.
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let path = tableView.indexPathForSelectedRow() {
            tableView.deselectRowAtIndexPath(path, animated: true)
        }
    }
    
    // The UITableViewController flashes the scrollbar when the table becomes visible.
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
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

    // TODO: visually distinguish between the term and definition -- perhaps by font size, perhaps by color
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        UIApplication.sharedApplication().preferredContentSizeCategory
        
        let cell = tableView.dequeueReusableCellWithIdentifier("termAndDefinition", forIndexPath: indexPath) as! UITableViewCell
        
        var term = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())

        var termLabel = cell.viewWithTag(10) as! UILabel
        termLabel.font = preferredFontForTextStyle(UIFontTextStyleBody)
        termLabel.text = "\(term.term)\n\(term.definition)"
        termLabel.lineBreakMode = .ByWordWrapping
        termLabel.numberOfLines = 0
        
        var hasImage = false || false
        if (hasImage) {
            cell.accessoryView = UIImageView(image: nil)
        }
    
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        var term = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())

        var text = "\(term.term)\n\(term.definition)"
        var width = tableView.frame.width - 16 // margin of 8 pixels on each side of the cell
        var font = preferredFontForTextStyle(UIFontTextStyleBody)

        var attributedText = NSAttributedString(string: text, attributes: [NSFontAttributeName: font!])
        var rect = attributedText.boundingRectWithSize(CGSizeMake(width, CGFloat.max),
            options: NSStringDrawingOptions.UsesLineFragmentOrigin | NSStringDrawingOptions.UsesFontLeading,
            context: nil)
        var size = rect.size
        
        return size.height + 6
    }

    func preferredFontForTextStyle(textStyle: String) -> UIFont? {
        // choose the font size
        let fontSize: CGFloat
        var contentSize = UIApplication.sharedApplication().preferredContentSizeCategory
        
        switch (contentSize) {
        case UIContentSizeCategoryExtraSmall:
            fontSize = 12.0
        case UIContentSizeCategoryExtraSmall:
            fontSize = 12.0
        case UIContentSizeCategorySmall:
            fontSize = 14.0
        case UIContentSizeCategoryMedium:
            fontSize = 16.0
        case UIContentSizeCategoryLarge:
            fontSize = 18.0
        case UIContentSizeCategoryExtraLarge:
            fontSize = 20.0
        case UIContentSizeCategoryExtraExtraLarge:
            fontSize = 22.0
        case UIContentSizeCategoryExtraExtraExtraLarge:
            fontSize = 24.0
        default:
            fontSize = 16.0
        }
        
        // choose the font weight
        if (textStyle == UIFontTextStyleHeadline || textStyle == UIFontTextStyleSubheadline) {
            return UIFont(name: "Arial-Bold", size: fontSize)
        } else {
            return UIFont(name: "Arial", size: fontSize)
        }
    }
    
    /*
    TODO: A-Z sections with indexes?

    sectionIndexTitlesForTableView: method – returns the indexed titles that appear in the index list on the right side of the table view. For example, you can return an array of strings containing “A” to “Z”.
    
    sectionForSectionIndexTitle: method – returns the section index that the table view should jump to when user taps a particular index.
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

