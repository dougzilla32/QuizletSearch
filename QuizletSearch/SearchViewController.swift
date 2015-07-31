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

enum SortSelection: Int {
    case AtoZ = 0, BySet, BySetAtoZ
}

class SearchTerm {
    let term: Term
    let score: Double
    let termRanges: [Range<String.Index>]?
    let definitionRanges: [Range<String.Index>]?
    
    init(term: Term, score: Double = 0.0, termRanges: [Range<String.Index>]? = nil, definitionRanges: [Range<String.Index>]? = nil) {
        self.term = term
        self.score = score
        self.termRanges = termRanges
        self.definitionRanges = definitionRanges
    }
}

class SortSet<T> {
    let title: String
    let terms: [T]
    let createdDate: Int64
    
    init(title: String, terms: [T], createdDate: Int64) {
        self.title = title
        self.terms = terms
        self.createdDate = createdDate
    }
}

class SortedTerms<T> {
    var AtoZ: [T]
    var bySet: [SortSet<T>]
    var bySetAtoZ: [SortSet<T>]
    
    var levenshteinMatch: [T] = []
    var stringScoreMatch: [T] = []
    
    init() {
        AtoZ = []
        bySet = []
        bySetAtoZ = []
    }
    
    init(AtoZ: [T], bySet: [SortSet<T>], bySetAtoZ: [SortSet<T>]) {
        self.AtoZ = AtoZ
        self.bySet = bySet
        self.bySetAtoZ = bySetAtoZ
    }
    
    func termForPath(indexPath: NSIndexPath, sortSelection: SortSelection) -> T {
        var term: T
        switch (sortSelection) {
        case .AtoZ:
            switch (indexPath.section) {
            case 0:
                term = AtoZ[indexPath.row]
            case 1:
                term = (levenshteinMatch.count > 0) ? levenshteinMatch[indexPath.row] : stringScoreMatch[indexPath.row]
            case 2:
                term = stringScoreMatch[indexPath.row]
            default:
                abort()
            }
        case .BySet:
            term = bySet[indexPath.section].terms[indexPath.row]
        case .BySetAtoZ:
            term = bySetAtoZ[indexPath.section].terms[indexPath.row]
        }
        return term
    }
}

class SearchViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var sortStyle: UISegmentedControl!
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    var refreshControl: UIRefreshControl!
    
    // MARK: - Sorting
    
    var sortedTerms: SortedTerms<Term> = SortedTerms<Term>()
    var searchTerms: SortedTerms<SearchTerm> = SortedTerms<SearchTerm>()
    
    @IBAction func sortStyleChanged(sender: AnyObject) {
        updateSearchTermsForQuery(searchBar.text)
    }
    
    func currentSortSelection() -> SortSelection {
        return SortSelection(rawValue: sortStyle.selectedSegmentIndex)!
    }
    
    // MARK: - Search Bar
    
    // called when text changes (including clear)
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        updateSearchTermsForQuery(searchBar.text)
    }
    
    // Have the keyboard close when 'Return' is pressed
    func searchBar(searchBar: UISearchBar, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool // called before text changes
    {
        if (text == "\n") {
            searchBar.resignFirstResponder()
        }
        return true
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
        
        let font = Common.preferredSystemFontForTextStyle(UIFontTextStyleBody)
        sortStyle.setTitleTextAttributes([NSFontAttributeName: font!], forState: UIControlState.Normal)
        
        // TODO: set the font for the text field as follows after upgrading to XCode 7
        // UITextField.appearanceWhenContainedInInstancesOfClasses([UISearchBar.Type]).font = UIFont(name: "Helvetica", size: 24)
        Common.findTextFieldAndUpdateFont(self.searchBar)
        // if let searchField = self.searchBar.valueForKey("_searchField") as? UITextField {
        //     searchField.font = preferredFontForTextStyle(UIFontTextStyleBody)
        // }

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

        // Dismiss the keyboard as soon as the user drags the table
        // tableView.keyboardDismissMode = .OnDrag

        // Allow the user to dismiss the keyboard by touch-dragging down to the bottom of the screen
        tableView.keyboardDismissMode = .Interactive
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
    
    class func initSortedTerms() -> SortedTerms<Term> {
        let dataModel = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel
        
        var AtoZ: [Term] = []
        var bySet: [SortSet<Term>] = []
        var bySetAtoZ: [SortSet<Term>] = []
        
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
            
            sort(&bySet, { (s1: SortSet<Term>, s2: SortSet<Term>) -> Bool in
                return s1.createdDate > s2.createdDate
            })
            
            sort(&bySetAtoZ, { (s1: SortSet<Term>, s2: SortSet<Term>) -> Bool in
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
            searchTerms.AtoZ = searchTermsForQuery(query, terms: sortedTerms.AtoZ)
            // searchTerms.levenshteinMatch = SearchViewController.levenshteinMatchForQuery(query, terms: sortedTerms.AtoZ)
            // searchTerms.stringScoreMatch = SearchViewController.stringScoreMatchForQuery(query, terms: sortedTerms.AtoZ)
        case .BySet:
            searchTerms.bySet = searchTermsBySetForQuery(query, termsBySet: sortedTerms.bySet)
        case .BySetAtoZ:
            searchTerms.bySetAtoZ = searchTermsBySetForQuery(query, termsBySet: sortedTerms.bySetAtoZ)
        }

        tableView.reloadData()
    }
    
    var rangeOfStringMethod = String.rangeOfStringWithOptions
    // var rangeOfStringMethod = String.rangeOfStringWithWhitespace
    // var rangeOfStringMethod = String.rangeOfOverlappingUnicharsInString
    
    func searchTermsForQuery(query: String, terms: [Term]) -> [SearchTerm] {
        var searchTerms: [SearchTerm] = []
        if (query.isWhitespace()) {
            for term in terms {
                searchTerms.append(SearchTerm(term: term))
            }
        } else {
            var options =  NSStringCompareOptions.CaseInsensitiveSearch | NSStringCompareOptions.WhitespaceInsensitiveSearch
            for term in terms {
                var termRange = rangeOfStringMethod(term.term)(query, options: options)
                var definitionRange = rangeOfStringMethod(term.definition)(query, options: options)
                if (termRange != nil || definitionRange != nil) {
                    searchTerms.append(SearchTerm(term: term,
                        score: 0.0,
                        termRanges: termRange != nil ? [termRange!] : nil,
                        definitionRanges: definitionRange != nil ? [definitionRange!] : nil))
                }
            }
        }
        return searchTerms
    }
    
    class func levenshteinMatchForQuery(query: String, terms: [Term]) -> [SearchTerm] {
        var levenshteinMatch: [SearchTerm] = []
        if (!query.isWhitespace()) {
            for term in terms {
                var termScore = computeLevenshteinScore(query, term.term)
                var definitionScore = computeLevenshteinScore(query, term.definition)
                
                if (termScore > 0.70 || definitionScore > 0.70) {
                    levenshteinMatch.append(SearchTerm(term: term, score: max(termScore, definitionScore)))
                }
            }
        }
        return levenshteinMatch
    }
    
    class func stringScoreMatchForQuery(query: String, terms: [Term]) -> [SearchTerm] {
        var stringScoreMatch: [SearchTerm] = []
        if (!query.isWhitespace()) {
            for term in terms {
                var termScore = term.term.scoreAgainst(query)
                var definitionScore = term.definition.scoreAgainst(query)
                
                if (termScore > 0.70 || definitionScore > 0.70) {
                    stringScoreMatch.append(SearchTerm(term: term, score: max(termScore, definitionScore)))
                }
            }
        }
        return stringScoreMatch
    }
    
    func searchTermsBySetForQuery(query: String, termsBySet: [SortSet<Term>]) -> [SortSet<SearchTerm>] {
        var searchTermsBySet: [SortSet<SearchTerm>] = []
        if (query.isWhitespace()) {
            for quizletSet in termsBySet {
                var termsForSet = [SearchTerm]()
                for term in quizletSet.terms {
                    termsForSet.append(SearchTerm(term: term))
                }
                searchTermsBySet.append(SortSet<SearchTerm>(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))
            }
        } else {
            // var bmp = BoyerMoorePattern(pattern: query)
            for quizletSet in termsBySet {
                var termsForSet = [SearchTerm]()

                /*
                for term in quizletSet.terms {
                    if (term.term.findIndexOf(pattern: bmp) != nil || term.definition.findIndexOf(pattern: bmp) != nil) {
                        termsForSet.append(term)
                    }
                }
                */
                
                for term in quizletSet.terms {
                    var options = NSStringCompareOptions.CaseInsensitiveSearch
                    var termRange = rangeOfStringMethod(term.term)(query, options: options)
                    var definitionRange = rangeOfStringMethod(term.definition)(query, options: options)
                    if (termRange != nil || definitionRange != nil) {
                        termsForSet.append(SearchTerm(term: term,
                            score: 0.0,
                            termRanges: termRange != nil ? [termRange!] : nil,
                            definitionRanges: definitionRange != nil ? [definitionRange!] : nil))
                    }
                }
                
                if (termsForSet.count > 0) {
                    searchTermsBySet.append(SortSet<SearchTerm>(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))
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
            if (searchTerms.levenshteinMatch.count > 0) {
                numberOfSections++
            }
            if (searchTerms.stringScoreMatch.count > 0) {
                numberOfSections++
            }
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
            switch (section) {
            case 0:
                numberOfRows = searchTerms.AtoZ.count
            case 1:
                numberOfRows = (searchTerms.levenshteinMatch.count > 0) ? searchTerms.levenshteinMatch.count : searchTerms.stringScoreMatch.count
            case 2:
                numberOfRows = searchTerms.stringScoreMatch.count
            default:
                numberOfRows = 0
            }
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
            switch (section) {
            case 0:
                title = nil
            case 1:
                title = (searchTerms.levenshteinMatch.count > 0) ? "Levenshtein Matches" : "String Score Matches"
            case 2:
                title = "String Score Matches"
            default:
                title = nil
            }
        case .BySet:
            title = searchTerms.bySet[section].title
        case .BySetAtoZ:
            title = searchTerms.bySetAtoZ[section].title
        }
        return title
    }

    // TODO: visually distinguish between the term and definition -- perhaps by font size, perhaps by color
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("termAndDefinition", forIndexPath: indexPath) as! UITableViewCell
        
        var searchTerm = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())

        var termText = NSMutableAttributedString(string: searchTerm.term.term + "\n")
        if (searchTerm.termRanges != nil) {
            for r in searchTerm.termRanges! {
                termText.addAttribute(NSBackgroundColorAttributeName, value: UIColor.yellowColor(), range: Common.stringRangeToNSRange(searchTerm.term.term, range: r))
            }
        }
        
        var definitionText = NSMutableAttributedString(string: searchTerm.term.definition)
        if (searchTerm.definitionRanges != nil) {
            for r in searchTerm.definitionRanges! {
                definitionText.addAttribute(NSBackgroundColorAttributeName, value: UIColor.yellowColor(), range: Common.stringRangeToNSRange(searchTerm.term.term, range: r))
            }
        }

        termText.appendAttributedString(definitionText)
        
        var termLabel = cell.viewWithTag(10) as! UILabel
        termLabel.font = Common.preferredSearchFontForTextStyle(UIFontTextStyleBody)
        termLabel.attributedText = termText
        termLabel.lineBreakMode = .ByWordWrapping
        termLabel.numberOfLines = 0
        
        var hasImage = false || false
        if (hasImage) {
            cell.accessoryView = UIImageView(image: nil)
        }
    
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        var searchTerm = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())

        var text = "\(searchTerm.term.term)\n\(searchTerm.term.definition)"
        var width = tableView.frame.width - 16 // margin of 8 pixels on each side of the cell
        var font = Common.preferredSearchFontForTextStyle(UIFontTextStyleBody)

        var attributedText = NSAttributedString(string: text, attributes: [NSFontAttributeName: font!])
        var rect = attributedText.boundingRectWithSize(CGSizeMake(width, CGFloat.max),
            options: NSStringDrawingOptions.UsesLineFragmentOrigin | NSStringDrawingOptions.UsesFontLeading,
            context: nil)
        var size = rect.size
        
        return size.height + 6
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

