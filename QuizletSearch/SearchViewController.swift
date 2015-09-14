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
    
    func hideKeyboard(recognizer: UITapGestureRecognizer) {
        searchBar.resignFirstResponder()
    }

    // MARK: - View Controller
        
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.All
    }

    override func loadView() {
        super.loadView()
        (UIApplication.sharedApplication().delegate as! AppDelegate).refreshAndRestartTimer(allowCellularAccess: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable selections in the table
        tableView.allowsSelection = false
        
        // Dismiss keyboard when user touches the table
        let gestureRecognizer = UITapGestureRecognizer(target: self,  action: "hideKeyboard:")
        gestureRecognizer.cancelsTouchesInView = false
        tableView.addGestureRecognizer(gestureRecognizer)
        
        // Respond to dynamic type font changes
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "preferredContentSizeChanged:",
            name: UIContentSizeCategoryDidChangeNotification,
            object: nil)
        resetFonts()
        
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
    
    var preferredSearchFont: UIFont?
    var preferredBoldSearchFont: UIFont?
    
    func preferredContentSizeChanged(notification: NSNotification) {
        resetFonts()
    }
    
    func resetFonts() {
        preferredSearchFont = Common.preferredSearchFontForTextStyle(UIFontTextStyleBody)
        preferredBoldSearchFont = Common.preferredSearchFontForTextStyle(UIFontTextStyleHeadline)
        
        sizingCell.termLabel!.font = preferredSearchFont
        sizingCell.definitionLabel!.font = preferredSearchFont
        estimatedHeaderHeight = nil
        estimatedHeight = nil
       
        sortStyle.setTitleTextAttributes([NSFontAttributeName: preferredSearchFont!], forState: UIControlState.Normal)
        
        // Update the appearance of the search bar's textfield
        let searchTextField: UITextField
        // appearanceWhenContainedInInstancesOfClasses causes a crash when loading the search view, not sure why this doesn't work
        // if #available(iOS 9.0, *) {
        //     searchTextField = UITextField.appearanceWhenContainedInInstancesOfClasses([UISearchBar.self])
        // } else {
            // Fallback on earlier versions
            searchTextField = Common.findTextField(self.searchBar)!
        // }
        searchTextField.font = preferredSearchFont
        searchTextField.autocapitalizationType = UITextAutocapitalizationType.None
        searchTextField.enablesReturnKeyAutomatically = false

        self.view.setNeedsLayout()
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
        let info = notification.userInfo! as [NSObject: AnyObject]

        let termsChanged = SearchViewController.containsTerms(info[NSInsertedObjectsKey] as? NSSet)
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
            
            let sortedTerms = SearchViewController.initSortedTerms()
            
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
            let managedObject = object as! NSManagedObject
            if (managedObject.entity.name == "QuizletSet" || managedObject.entity.name == "Term") {
                return true
            }
        }
        return false
    }
    
    class func initSortedTerms() -> SortedTerms<SortTerm> {
        let dataModel = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel
        
        var AtoZterms: [SortTerm] = []
        var AtoZ: [SortSet<SortTerm>] = []
        var bySet: [SortSet<SortTerm>] = []
        var bySetAtoZ: [SortSet<SortTerm>] = []
        
        if let filter = dataModel.currentUser?.currentFilter {
            for set in filter.sets {
                let quizletSet = set as! QuizletSet
                var termsForSet = [SortTerm]()
                
                for term in quizletSet.terms {
                    let term = SortTerm(term: term as! Term)
                    AtoZterms.append(term)
                    termsForSet.append(term)
                }
                
                // Use native term order for 'bySet'
                bySet.append(SortSet(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))

                // Use alphabetically sorted terms for 'bySetAtoZ'
                termsForSet.sortInPlace(termComparator)
                bySetAtoZ.append(SortSet(title: quizletSet.title, terms: termsForSet, createdDate: quizletSet.createdDate))
            }
            
            AtoZ = collateAtoZ(AtoZterms)
            // sort(&AtoZterms, termComparator)
            
            bySet.sortInPlace({ (s1: SortSet<SortTerm>, s2: SortSet<SortTerm>) -> Bool in
                return s1.createdDate > s2.createdDate
            })
            
            bySetAtoZ.sortInPlace({ (s1: SortSet<SortTerm>, s2: SortSet<SortTerm>) -> Bool in
                return s1.title.compare(s2.title, options: [NSStringCompareOptions.CaseInsensitiveSearch, NSStringCompareOptions.NumericSearch]) != .OrderedDescending
            })
        }
        
        return SortedTerms(AtoZ: AtoZ, bySet: bySet, bySetAtoZ: bySetAtoZ)
    }
    
    class func collateAtoZ(var AtoZterms: [SortTerm]) -> [SortSet<SortTerm>] {
        AtoZterms.sortInPlace(termComparator)

        var currentCharacter: Character? = nil
        var currentTerms: [SortTerm]? = nil
        var AtoZbySet: [SortSet<SortTerm>] = []

        for term in AtoZterms {
            var text = term.termForDisplay.string
            //var text = term.definitionForDisplay.string
            text = text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            
            var firstCharacter: Character
            if (text.isEmpty) {
                firstCharacter = " "
            }
            else {
                firstCharacter = text[text.startIndex]
                
                // Use '9' as the index view title for all numbers greater than 9
                if "0"..."9" ~= firstCharacter {
                    let next = text.startIndex.successor()
                    if (next != text.endIndex) {
                        let secondCharacter = text[next]
                        if ("0"..."9" ~= secondCharacter) {
                            firstCharacter = "9"
                        }
                    }
                }
                
                firstCharacter = Common.toUppercase(firstCharacter)
            }
            
            if (currentCharacter != firstCharacter) {
                if (currentTerms != nil) {
                    AtoZbySet.append(SortSet(title: "\(currentCharacter!)", terms: currentTerms!, createdDate: 0))
                }
                currentTerms = []
                currentCharacter = firstCharacter
            }
            currentTerms!.append(term)
        }
        
        if (currentTerms != nil) {
            AtoZbySet.append(SortSet(title: "\(currentCharacter!)", terms: currentTerms!, createdDate: 0))
        }
        
        return AtoZbySet
    }
    
    class func termComparator(t1: SortTerm, t2: SortTerm) -> Bool {
        switch (t1.termForDisplay.string.compare(t2.termForDisplay.string, options: [NSStringCompareOptions.CaseInsensitiveSearch, NSStringCompareOptions.NumericSearch])) {
        case .OrderedAscending:
            return true
        case .OrderedDescending:
            return false
        case .OrderedSame:
            return t1.definitionForDisplay.string.compare(t2.definitionForDisplay.string, options: [NSStringCompareOptions.CaseInsensitiveSearch, NSStringCompareOptions.NumericSearch]) != .OrderedDescending
        }
    }
    
    lazy var searchQueue: NSOperationQueue = {
        var queue = NSOperationQueue()
        queue.name = "Search queue"
        return queue
        }()
    
    var currentSearchOperation: SearchOperation?
    
    func executeSearchForQuery(query: String?) {
        currentSearchOperation?.cancel()
        
        let searchOp = SearchOperation(query: query == nil ? "" : query!, sortSelection: currentSortSelection(), sortedTerms: sortedTerms)
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // TODO: Dispose of any data model resources that can be refetched
    }
    
    // MARK: - Table view controller
    
    // The UITableViewController deselects the currently selected row when the table becomes visible.  We are not subclassing UITableViewController because we want to add a custom filter bar, and the UITableViewController does not allow for this.
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let path = tableView.indexPathForSelectedRow {
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
            numberOfSections = searchTerms.AtoZ.count
            /*
            numberOfSections = 1
            if (searchTerms.levenshteinMatch.count > 0) {
                numberOfSections++
            }
            if (searchTerms.stringScoreMatch.count > 0) {
                numberOfSections++
            }
            */
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
            numberOfRows = searchTerms.AtoZ[section].terms.count
            /*
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
            */
        case .BySet:
            numberOfRows = searchTerms.bySet[section].terms.count
        case .BySetAtoZ:
            numberOfRows = searchTerms.bySetAtoZ[section].terms.count
        }
        return numberOfRows
    }

    func configureHeaderCell(cell: SearchTableViewHeaderCell, section: Int) {
        var title: String?
        switch (currentSortSelection()) {
        case .AtoZ:
            title = searchTerms.AtoZ[section].title
            /*
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
            */
        case .BySet:
            title = searchTerms.bySet[section].title
        case .BySetAtoZ:
            title = searchTerms.bySetAtoZ[section].title
        }
        
        cell.headerLabel!.font = preferredSearchFont
        cell.headerLabel!.text = title
        cell.backgroundColor = UIColor(red: 239, green: 239, blue: 239, alpha: 1.0)
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = tableView.dequeueReusableCellWithIdentifier("SearchTableViewHeaderCell") as! SearchTableViewHeaderCell
        configureHeaderCell(cell, section: section)
        return cell
    }
    
    lazy var headerSizingCell: SearchTableViewHeaderCell = {
        return self.tableView.dequeueReusableCellWithIdentifier("SearchTableViewHeaderCell") as! SearchTableViewHeaderCell
        }()
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        configureHeaderCell(headerSizingCell, section: section)
        if (headerSizingCell.headerLabel!.text == nil) {
            return 0
        }
        
        headerSizingCell.bounds = CGRectMake(0.0, 0.0, CGRectGetWidth(self.tableView.frame) - getIndexViewWidth(), CGRectGetHeight(sizingCell.bounds));
        headerSizingCell.setNeedsLayout()
        headerSizingCell.layoutIfNeeded()
        
        let size = headerSizingCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        return size.height + 1.0 // Add 1.0 for the cell separator height
    }

    var estimatedHeaderHeight: CGFloat?
    
    func tableView(tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        if (estimatedHeaderHeight == nil) {
            headerSizingCell.headerLabel!.font = preferredSearchFont
            headerSizingCell.headerLabel!.text = "Header"
            
            headerSizingCell.bounds = CGRectMake(0.0, 0.0, CGRectGetWidth(self.tableView.frame) - getIndexViewWidth(), CGRectGetHeight(sizingCell.bounds));
            headerSizingCell.setNeedsLayout()
            headerSizingCell.layoutIfNeeded()
            
            let size = headerSizingCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
            estimatedHeaderHeight = size.height + 1.0 // Add 1.0 for the cell separator height
        }
        
        return estimatedHeaderHeight!
        
    }
    
    lazy var highlightForegroundColor = UIColor(red: 25.0 / 255.0, green: 86.0 / 255.0, blue: 204.0 / 255.0, alpha: 1.0)
    lazy var highlightBackgroundColor = UIColor(red: 163.0 / 255.0, green: 205.0 / 255.0, blue: 254.0 / 255.0, alpha: 1.0)
    
    func configureCell(cell: SearchTableViewCell, atIndexPath indexPath: NSIndexPath) {
        let searchTerm = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())
        
        let termForDisplay = searchTerm.sortTerm.termForDisplay.string
        let termText = NSMutableAttributedString(string: termForDisplay)
        for range in searchTerm.termRanges {
            termText.addAttribute(NSFontAttributeName, value: preferredBoldSearchFont!, range: range)
            termText.addAttribute(NSForegroundColorAttributeName, value: highlightForegroundColor, range: range)
        }
        cell.termLabel!.font = preferredSearchFont
        cell.termLabel!.attributedText = termText
        
        let definitionForDisplay = searchTerm.sortTerm.definitionForDisplay.string
        let definitionText = NSMutableAttributedString(string: definitionForDisplay)
        for range in searchTerm.definitionRanges {
            definitionText.addAttribute(NSFontAttributeName, value: preferredBoldSearchFont!, range: range)
            definitionText.addAttribute(NSForegroundColorAttributeName, value: highlightForegroundColor, range: range)
        }
        cell.definitionLabel!.font = preferredSearchFont
        cell.definitionLabel!.attributedText = definitionText
        
        let hasImage = false || false
        if (hasImage) {
            cell.accessoryView = UIImageView(image: nil)
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SearchTableViewCell", forIndexPath: indexPath) as! SearchTableViewCell
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    lazy var sizingCell: SearchTableViewCell = {
        return self.tableView.dequeueReusableCellWithIdentifier("SearchTableViewCell") as! SearchTableViewCell
    }()
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {

        configureCell(sizingCell, atIndexPath:indexPath)
        
        sizingCell.bounds = CGRectMake(0.0, 0.0, CGRectGetWidth(self.tableView.frame) - getIndexViewWidth(), CGRectGetHeight(sizingCell.bounds));
        sizingCell.setNeedsLayout()
        sizingCell.layoutIfNeeded()
        
        let size = sizingCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        return size.height + 1.0 // Add 1.0 for the cell separator height
    }

    var estimatedHeight: CGFloat?
    
    func tableView(tableView: UITableView,
        estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {

        if (estimatedHeight == nil) {
            sizingCell.termLabel!.font = preferredSearchFont
            sizingCell.termLabel!.text = "Term"
            
            sizingCell.definitionLabel!.font = preferredSearchFont
            sizingCell.definitionLabel!.text = "Definition"
            
            sizingCell.bounds = CGRectMake(0.0, 0.0, CGRectGetWidth(self.tableView.frame) - getIndexViewWidth(), CGRectGetHeight(sizingCell.bounds));
            sizingCell.setNeedsLayout()
            sizingCell.layoutIfNeeded()
            
            let size = sizingCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
            estimatedHeight = size.height + 1.0 // Add 1.0 for the cell separator height
        }
            
        return estimatedHeight!
    }
    
    class func truncateText(var text: String, toLength: Int) -> String {
        let index = text.startIndex.advancedBy(toLength, limit: text.endIndex)
        if (index != text.endIndex) {
            text = text.substringToIndex(index)
            text = "\(text)..."
        }
        return text
    }

    // returns the indexed titles that appear in the index list on the right side of the table view. For example, you can return an array of strings containing “A” to “Z”.
    func sectionIndexTitlesForTableView(tableView: UITableView) -> [String]? {
        var titles: [String]?
        
        switch (currentSortSelection()) {
        case .AtoZ:
            titles = []
            for section in searchTerms.AtoZ {
                titles!.append(section.title)
            }
        case .BySet:
            titles = []
            for _ in searchTerms.bySetAtoZ {
                titles!.append(".")
            }
        case .BySetAtoZ:
            titles = []
            for section in searchTerms.bySetAtoZ {
                var firstCharacter = Common.firstNonWhitespaceCharacter(section.title)
                if (firstCharacter == nil) {
                    firstCharacter = " "
                }
                titles!.append("\(firstCharacter!)")
            }
        }
        
        return titles
    }
    
    // returns the section index that the table view should jump to when user taps a particular index.
    func tableView(tableView: UITableView, sectionForSectionIndexTitle title: String, atIndex index: Int) -> Int {
        return index
    }
    
    func getIndexViewWidth() -> CGFloat {
        var width: CGFloat
        
        // TODO: this width changes for different hardware configurations.  "15" works for iPhone 6.
        switch (currentSortSelection()) {
        case .AtoZ:
            // From experimenting I know the correct value to be 15
            // smaller values fail for "used... 를" (2nd largest font size)
            // width = 14: fails for "comes after the *noun*..." (2nd largest font size)
            width = 15 // OK!
            // width = 16 // fails for "attached to a place and indicates going to a destination" (largest font size)
            // width = 17: fails for "we went to the zoo..." (2nd largest font size)
        case .BySet:
            width = 0
        case .BySetAtoZ:
            width = 0
        }

        return width
    }

    /*
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */
}

