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

class SortTerm {
    let termForDisplay: StringWithBoundaries
    let definitionForDisplay: StringWithBoundaries
    
    let termForCompare: StringWithBoundaries
    let definitionForCompare: StringWithBoundaries

    init(term: Term) {
        self.termForDisplay = StringWithBoundaries(string: term.term)
        self.definitionForDisplay = StringWithBoundaries(string: term.definition)
        
        self.termForCompare = term.term.lowercaseString.decomposeAndNormalize()
        self.definitionForCompare = term.definition.lowercaseString.decomposeAndNormalize()
    }
}

class SearchTerm {
    let sortTerm: SortTerm
    let score: Double
    let termRanges: [NSRange]
    let definitionRanges: [NSRange]
    
    init(sortTerm: SortTerm, score: Double = 0.0, termRanges: [NSRange] = [], definitionRanges: [NSRange] = []) {
        self.sortTerm = sortTerm
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
    
    var sortedTerms = SortedTerms<SortTerm>()
    var searchTerms = SortedTerms<SearchTerm>()
    
    @IBAction func sortStyleChanged(sender: AnyObject) {
        executeSearchForQuery(searchBar.text)
    }
    
    func currentSortSelection() -> SortSelection {
        return SortSelection(rawValue: sortStyle.selectedSegmentIndex)!
    }
    
    // MARK: - Search Bar
    
    // called when text changes (including clear)
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        executeSearchForQuery(searchBar.text)
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
        executeSearchForQuery(searchBar.text)
        
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
                self.executeSearchForQuery(self.searchBar.text)
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
    
    class func initSortedTerms() -> SortedTerms<SortTerm> {
        let dataModel = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel
        
        var AtoZ: [SortTerm] = []
        var bySet: [SortSet<SortTerm>] = []
        var bySetAtoZ: [SortSet<SortTerm>] = []
        
        if let filter = dataModel.currentUser?.currentFilter {
            for set  in filter.sets {
                var quizletSet = set as! QuizletSet
                var termsForSet = [SortTerm]()
                
                for term in quizletSet.terms {
                    var term = SortTerm(term: term as! Term)
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
            
            sort(&bySet, { (s1: SortSet<SortTerm>, s2: SortSet<SortTerm>) -> Bool in
                return s1.createdDate > s2.createdDate
            })
            
            sort(&bySetAtoZ, { (s1: SortSet<SortTerm>, s2: SortSet<SortTerm>) -> Bool in
                return s1.title.compare(s2.title, options: NSStringCompareOptions.CaseInsensitiveSearch | NSStringCompareOptions.NumericSearch) != .OrderedDescending
            })
        }
        
        return SortedTerms(AtoZ: AtoZ, bySet: bySet, bySetAtoZ: bySetAtoZ)
    }
    
    class func termComparator(t1: SortTerm, t2: SortTerm) -> Bool {
        switch (t1.termForDisplay.string.compare(t2.termForDisplay.string, options: NSStringCompareOptions.CaseInsensitiveSearch | NSStringCompareOptions.NumericSearch)) {
        case .OrderedAscending:
            return true
        case .OrderedDescending:
            return false
        case .OrderedSame:
            return t1.definitionForDisplay.string.compare(t2.definitionForDisplay.string, options: NSStringCompareOptions.CaseInsensitiveSearch | NSStringCompareOptions.NumericSearch) != .OrderedDescending
        }
    }
    
    func executeSearchForQuery(var query: String) {
        currentSearchOperation?.cancel()
        
        let searchOp = SearchOperation(query: query, sortSelection: currentSortSelection(), sortedTerms: sortedTerms)
        searchOp.qualityOfService = NSQualityOfService.UserInitiated

        searchOp.completionBlock = {
            dispatch_async(dispatch_get_main_queue(), {
                if (searchOp.cancelled) {
                    return
                }
                
                switch (searchOp.sortSelection) {
                case .AtoZ:
                    self.searchTerms.AtoZ = searchOp.searchTerms.AtoZ
                    // searchTerms.levenshteinMatch = searchOp.searchTerms.levenshteinMatch
                    // searchTerms.stringScoreMatch = searchOp.searchTerms.stringScoreMatch
                case .BySet:
                    self.searchTerms.bySet = searchOp.searchTerms.bySet
                case .BySetAtoZ:
                    self.searchTerms.bySetAtoZ = searchOp.searchTerms.bySetAtoZ
                }
                self.tableView.reloadData()
            })
        }

        currentSearchOperation = searchOp
        searchQueue.addOperation(searchOp)
    }
    
    lazy var searchQueue: NSOperationQueue = {
        var queue = NSOperationQueue()
        queue.name = "Search queue"
        return queue
        }()

    var currentSearchOperation: SearchOperation?
    
    class SearchOperation: NSOperation {
        let query: String
        let sortSelection: SortSelection
        let sortedTerms: SortedTerms<SortTerm>
        
        let searchTerms = SortedTerms<SearchTerm>()
        
        init(query: String, sortSelection: SortSelection, sortedTerms: SortedTerms<SortTerm>) {
            self.query = query
            self.sortSelection = sortSelection
            self.sortedTerms = sortedTerms
        }
        
        override func main() {
           updateSearchTermsForQuery(query)
        }
    
        func updateSearchTermsForQuery(var queryString: String) {
            var query = queryString.lowercaseString.decomposeAndNormalize()
            
            if (self.cancelled) {
                return
            }

            switch (sortSelection) {
            case .AtoZ:
                searchTerms.AtoZ = searchTermsForQuery(query, terms: sortedTerms.AtoZ)
                // searchTerms.levenshteinMatch = SearchViewController.levenshteinMatchForQuery(query, terms: sortedTerms.AtoZ)
                // searchTerms.stringScoreMatch = SearchViewController.stringScoreMatchForQuery(query, terms: sortedTerms.AtoZ)
            case .BySet:
                searchTerms.bySet = searchTermsBySetForQuery(query, termsBySet: sortedTerms.bySet)
            case .BySetAtoZ:
                searchTerms.bySetAtoZ = searchTermsBySetForQuery(query, termsBySet: sortedTerms.bySetAtoZ)
            }
        }
        
        func searchTermsForQuery(query: StringWithBoundaries, terms: [SortTerm]) -> [SearchTerm] {
            var searchTerms: [SearchTerm] = []
            if (query.string.isWhitespace()) {
                for term in terms {
                    searchTerms.append(SearchTerm(sortTerm: term))
                }
            } else {
                var options = NSStringCompareOptions.WhitespaceInsensitiveSearch

                for term in terms {
                    if (self.cancelled) {
                        return []
                    }
                    
                    var termRanges = String.characterRangesOfUnichars(term.termForCompare, targetString: query, options: options)
                    var definitionRanges = String.characterRangesOfUnichars(term.definitionForCompare, targetString: query, options: options)
                    
                    if (termRanges.count > 0 || definitionRanges.count > 0) {
                        searchTerms.append(SearchTerm(sortTerm: term,
                            score: 0.0,
                            termRanges: term.termForDisplay.characterRangesToUnicharRanges(termRanges),
                            definitionRanges: term.definitionForDisplay.characterRangesToUnicharRanges(definitionRanges)))
                    }
                }
            }
            return searchTerms
        }

        func searchTermsBySetForQuery(query: StringWithBoundaries, termsBySet: [SortSet<SortTerm>]) -> [SortSet<SearchTerm>] {
            var searchTermsBySet: [SortSet<SearchTerm>] = []
            if (query.string.isWhitespace()) {
                for quizletSet in termsBySet {
                    var termsForSet = [SearchTerm]()
                    for term in quizletSet.terms {
                        termsForSet.append(SearchTerm(sortTerm: term))
                    }
                    searchTermsBySet.append(SortSet<SearchTerm>(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))
                }
            } else {
                for quizletSet in termsBySet {
                    var termsForSet = [SearchTerm]()
                    
                    for term in quizletSet.terms {
                        if (self.cancelled) {
                            return []
                        }
                        
                        var options = NSStringCompareOptions.WhitespaceInsensitiveSearch
                        var termRanges = String.characterRangesOfUnichars(term.termForCompare, targetString: query, options: options)
                        var definitionRanges = String.characterRangesOfUnichars(term.definitionForCompare, targetString: query, options: options)
                        
                        if (termRanges.count > 0 || definitionRanges.count > 0) {
                            termsForSet.append(SearchTerm(sortTerm: term,
                                score: 0.0,
                                termRanges: term.termForDisplay.characterRangesToUnicharRanges(termRanges),
                                definitionRanges: term.definitionForDisplay.characterRangesToUnicharRanges(definitionRanges)))
                        }
                    }
                    
                    if (termsForSet.count > 0) {
                        searchTermsBySet.append(SortSet<SearchTerm>(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))
                    }
                }
            }
            return searchTermsBySet
        }

        class func levenshteinMatchForQuery(query: String, sortTerms: [SortTerm]) -> [SearchTerm] {
            var levenshteinMatch: [SearchTerm] = []
            if (!query.isWhitespace()) {
                for sortTerm in sortTerms {
                    var termScore = computeLevenshteinScore(query, sortTerm.termForDisplay.string)
                    var definitionScore = computeLevenshteinScore(query, sortTerm.definitionForDisplay.string)
                    
                    if (termScore > 0.70 || definitionScore > 0.70) {
                        levenshteinMatch.append(SearchTerm(sortTerm: sortTerm, score: max(termScore, definitionScore)))
                    }
                }
            }
            return levenshteinMatch
        }
        
        class func stringScoreMatchForQuery(query: String, sortTerms: [SortTerm]) -> [SearchTerm] {
            var stringScoreMatch: [SearchTerm] = []
            if (!query.isWhitespace()) {
                for sortTerm in sortTerms {
                    var lowercaseQuery = query.lowercaseString
                    var termScore = sortTerm.termForDisplay.string.scoreAgainst(lowercaseQuery)
                    var definitionScore = sortTerm.definitionForDisplay.string.scoreAgainst(lowercaseQuery)
                    
                    if (termScore > 0.70 || definitionScore > 0.70) {
                        stringScoreMatch.append(SearchTerm(sortTerm: sortTerm, score: max(termScore, definitionScore)))
                    }
                }
            }
            return stringScoreMatch
        }
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

        var termText = NSMutableAttributedString(string: searchTerm.sortTerm.termForDisplay.string + "\n")
        for r in searchTerm.termRanges {
            termText.addAttribute(NSBackgroundColorAttributeName, value: UIColor.yellowColor(), range: r)
        }
        
        var definitionText = NSMutableAttributedString(string: searchTerm.sortTerm.definitionForDisplay.string)
        for r in searchTerm.definitionRanges {
            definitionText.addAttribute(NSBackgroundColorAttributeName, value: UIColor.yellowColor(), range: r)
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

        var text = "\(searchTerm.sortTerm.termForDisplay)\n\(searchTerm.sortTerm.definitionForDisplay)"
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

