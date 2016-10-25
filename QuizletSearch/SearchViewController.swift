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
    case bySet = 0, bySetAtoZ, atoZ
}

class SearchViewController: TableContainerController, UISearchBarDelegate {
    
    @IBOutlet weak var sortStyle: UISegmentedControl!
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    var observedTableIndexViewWidth: CGFloat?
    
    var showActivityIndicator = true
    
    var animationBlock: ((CGPoint, _ completionHandler: @escaping () -> Void) -> Void)?
    var animationContext: WhooshAnimationContext?
    
    let SearchBarPlaceholderPrefix = "Search \""
    let SearchBarPlaceholderSuffix = "\" sets"
    
    // MARK: - Sorting
    
    var searchIndex: SearchIndex?
    var searchTerms: SearchedAndSorted = SortedSetsAndTerms()
    
    @IBAction func sortStyleChanged(_ sender: AnyObject) {
        trace("SearchViewController.sortStyleChanged executeSearchForQuery", searchBar.text)
        executeSearchForQuery(searchBar.text)
    }
    
    func currentSortSelection() -> SortSelection {
        return SortSelection(rawValue: sortStyle.selectedSegmentIndex)!
    }
    
    // MARK: - Export action
    
    @IBAction func exportSetData(_ sender: AnyObject) {
        if (searchIndex == nil) {
            return
        }
        
        var data = ""
        switch (currentSortSelection()) {
        case .atoZ:
            for set in searchIndex!.allTerms.AtoZ {
                for term in set.terms {
                    data.append(term.termForDisplay.string)
                    data.append("\t")
                    data.append(term.definitionForDisplay.string)
                    data.append("\n")
                }
            }
        case .bySet:
            for set in searchIndex!.allTerms.bySet {
                if (!data.isEmpty) {
                    data.append("\n")
                }
                data.append(set.title)
                data.append("\n")
                for term in set.terms {
                    data.append(term.termForDisplay.string)
                    data.append("\t")
                    data.append(term.definitionForDisplay.string)
                    data.append("\n")
                }
            }
        case .bySetAtoZ:
            for set in searchIndex!.allTerms.bySetAtoZ {
                if (!data.isEmpty) {
                    data.append("\n")
                }
                data.append(set.title)
                data.append("\n")
                for term in set.terms {
                    data.append(term.termForDisplay.string)
                    data.append("\t")
                    data.append(term.definitionForDisplay.string)
                    data.append("\n")
                }
            }
        }
        
        let activityViewController = UIActivityViewController(activityItems: [data], applicationActivities: nil)
        if let popoverPresentationController = activityViewController.popoverPresentationController {
            popoverPresentationController.barButtonItem = (sender as! UIBarButtonItem)
        }
        present(activityViewController, animated: true, completion: nil)
    }

    // MARK: - Search Bar
    
    // called when text changes (including clear)
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        trace("SearchViewController.searchBar:textDidChange executeSearchForQuery", searchBar.text)
        executeSearchForQuery(searchBar.text)
    }
    
    // Have the keyboard close when 'Return' is pressed
    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool // called before text changes
    {
        if (text == "\n") {
            searchBar.resignFirstResponder()
        }
        return true
    }
    
    func hideKeyboard(_ recognizer: UITapGestureRecognizer) {
        searchBar.resignFirstResponder()
    }

    // MARK: - View Controller
        
    override var shouldAutorotate : Bool {
        return true
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return .all
    }
    
//    override func loadView() {
//        super.loadView()
//        (UIApplication.sharedApplication().delegate as! AppDelegate).refreshAndRestartTimer(allowCellularAccess: true)
//    }
    
    override func viewDidLoad() {
        trace("SearchViewController viewDidLoad()")
        super.viewDidLoad()
        
        // Disable selections in the table
        tableView.allowsSelection = false
        
        // Dismiss keyboard when user touches the table
        let gestureRecognizer = UITapGestureRecognizer(target: self,  action: #selector(SearchViewController.hideKeyboard(_:)))
        gestureRecognizer.cancelsTouchesInView = false
        tableView.addGestureRecognizer(gestureRecognizer)
        
        // Dismiss the keyboard as soon as the user drags the table
        // tableView.keyboardDismissMode = .OnDrag
        
        // Allow the user to dismiss the keyboard by touch-dragging down to the bottom of the screen
        tableView.keyboardDismissMode = .interactive
        
        // Respond to dynamic type font changes
        NotificationCenter.default.addObserver(self,
            selector: #selector(SearchViewController.preferredContentSizeChanged(_:)),
            name: NSNotification.Name.UIContentSizeCategoryDidChange,
            object: nil)
        resetFonts()
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        let moc = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
        NotificationCenter.default.addObserver(self,
            selector: #selector(SearchViewController.contextDidSaveNotification(_:)),
            name: NSNotification.Name.NSManagedObjectContextDidSave,
            object: moc)

        // Workaround to make the search bar background non-translucent, eliminates some drawing artifacts
        searchBar.isTranslucent = true
        searchBar.isTranslucent = false
        if let searchBarColor = searchBar.barTintColor {
            searchBar.layer.borderWidth = 1.0
            searchBar.layer.borderColor = searchBarColor.cgColor
            searchBar.backgroundColor = searchBarColor
        }
        
        // Set the placeholder text to the name of the current set
        let dataModel = self.dataModel()
        if (dataModel.currentQuery != nil) {
            let title = dataModel.currentQuery!.title
            searchBar.placeholder = SearchBarPlaceholderPrefix + title + SearchBarPlaceholderSuffix
        }
        
        refreshTable(modified: false)
        isFirstViewDidLayoutSubviews = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.isNavigationBarHidden = true
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        headerHeightCache.removeAll(keepingCapacity: true)
        rowHeightCache.removeAll(keepingCapacity: true)
    }
    
    var isFirstViewDidLayoutSubviews = false
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if (!isFirstViewDidLayoutSubviews) { return }
        isFirstViewDidLayoutSubviews = false
        
        DispatchQueue.main.async(execute: {
            trace("SearchViewController.executeSearchForQuery from viewDidLayoutSubviews")
            self.searchIndex = SearchIndex(query: (UIApplication.shared.delegate as! AppDelegate).dataModel.currentQuery)
            self.showActivityIndicator = false
            self.executeSearchForQuery(self.searchBar.text)
        })
        
        // Cause the search bar's textfield to be positioned correctly
        searchBar.layoutIfNeeded()
        
        if (animationBlock != nil) {
            let targetPoint = hideTitleText()
            self.animationBlock!(targetPoint, {
                self.showTitleText()
            })
            self.animationBlock = nil
        }
    }
    
    // Called after the view was dismissed, covered or otherwise hidden.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.refreshControl.endRefreshing()
        headerHeightCache = [:]
        rowHeightCache = [:]
        isFirstViewDidLayoutSubviews = false
    }
    
    func hideTitleText() -> CGPoint {
        let searchTextField = Common.findTextField(self.searchBar)!
        let title = dataModel().currentQuery!.title

        // Set the title text to clearColor
        let attributedPlaceholder = NSMutableAttributedString(attributedString: searchTextField.attributedPlaceholder!)
        attributedPlaceholder.addAttribute(NSForegroundColorAttributeName, value: UIColor.clear, range: NSRange(location: (SearchBarPlaceholderPrefix as NSString).length, length: (title as NSString).length))
        searchTextField.attributedPlaceholder = attributedPlaceholder

        // Calculate the frame for the title text
        let absoluteOrigin = searchTextField.superview!.convert(searchTextField.frame.origin, to: UIApplication.shared.keyWindow!)
        let placeholderBounds = searchTextField.placeholderRect(forBounds: searchTextField.bounds)
        let fontAttributes = [NSFontAttributeName: searchTextField.font!]
        let prefixSize = SearchBarPlaceholderPrefix.size(attributes: fontAttributes)
        
        return CGPoint(x: absoluteOrigin.x + placeholderBounds.origin.x + prefixSize.width + 1, y: absoluteOrigin.y + placeholderBounds.origin.y)
    }
    
    func showTitleText() {
        let searchTextField = Common.findTextField(searchBar)!
        searchTextField.attributedPlaceholder = nil
        self.searchBar.placeholder = SearchBarPlaceholderPrefix + dataModel().currentQuery!.title + SearchBarPlaceholderSuffix
    }
    
    deinit {
        // Remove all 'self' observers
        NotificationCenter.default.removeObserver(self)
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    var preferredSearchFont: UIFont?
    var preferredBoldSearchFont: UIFont?
    
    func preferredContentSizeChanged(_ notification: Notification) {
        resetFonts()
        self.view.setNeedsLayout()
    }
    
    func resetFonts() {
        preferredSearchFont = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        preferredBoldSearchFont = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
        
        sizingCell.termLabel.font = preferredSearchFont
        sizingCell.definitionLabel.font = preferredSearchFont
        estimatedHeaderHeight = nil
        // estimatedHeight = nil
       
        sortStyle.setTitleTextAttributes([NSFontAttributeName: preferredSearchFont!], for: UIControlState())
        
        // Update the appearance of the search bar's textfield
        let searchTextField = Common.findTextField(self.searchBar)!
        searchTextField.font = preferredSearchFont
        searchTextField.autocapitalizationType = UITextAutocapitalizationType.none
        searchTextField.enablesReturnKeyAutomatically = false
    }
    
    // MARK: - Search View Controller
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        cancelRefresh()
        
        if (segue.identifier == "EditQuery") {
            let addQueryViewController = segue.destination.childViewControllers[0] as! AddQueryViewController
            addQueryViewController.configureForSave(dataModel().currentQuery!)
        }
        else if (segue.identifier == "SearchUnwind" /* && Common.isEmpty(searchBar.text) */) {
            searchBar.text = nil
            let queriesViewController = segue.destination as! QueriesViewController

            let sourcePoint = hideTitleText()

            let label = UILabel()
            let searchTextField = Common.findTextField(self.searchBar)!
            label.text = dataModel().currentQuery!.title
            label.font = searchTextField.font
            label.textColor = searchTextField.textColor
            label.textAlignment = searchTextField.textAlignment
            
            if (animationContext != nil) {
                animationContext!.cancel()
                animationContext = nil
            }
            
            if (WhooshAnimationEnabled) {
                queriesViewController.animationBlock = { (targetPoint: CGPoint, completionHandler: @escaping () -> Void) in
                    queriesViewController.animationContext = CommonAnimation.letterWhooshAnimationForLabel(label, sourcePoint: sourcePoint, targetPoint: targetPoint, style: .fadeIn, completionHandler: {
                        queriesViewController.animationContext = nil
                        self.showTitleText()
                        completionHandler()
                    })
                }
            }
        }
    }
    
    @IBAction func unwindFromEditQuery(_ segue: UIStoryboardSegue) {
        if (segue.identifier == "EditQuerySave") {
            let addQueryViewController = segue.source as! AddQueryViewController
            let modified = addQueryViewController.saveToQuery(dataModel().currentQuery!)
            refreshTable(modified: modified)
        }
        else if (segue.identifier == "EditQueryCancel") {
            refreshTable(modified: false)
        }
    }
    
    func dataModel() -> DataModel {
        return (UIApplication.shared.delegate as! AppDelegate).dataModel
    }
    
    func refreshTable(modified: Bool) {
        trace("refreshTable in SearchViewController modified:", modified)
        (UIApplication.shared.delegate as! AppDelegate).refreshAndRestartTimer(allowCellularAccess: true, modified: modified, completionHandler: { (qsets: [QSet]?) in
            self.refreshControl.endRefreshing()
        })
    }
    
    override func refreshTable() {
        self.refreshTable(modified: true)
    }
    
    func cancelRefresh() {
        (UIApplication.shared.delegate as! AppDelegate).cancelRefreshTimer()
        
        currentSearchOperation?.cancel()
    }
    
    // call back function by saveContext, support multi-thread
    func contextDidSaveNotification(_ notification: Notification) {
        let info = notification.userInfo! as [AnyHashable: Any]

        let termsChanged = SearchViewController.containsTerms(info[NSInsertedObjectsKey] as? NSSet)
            || SearchViewController.containsTerms(info[NSDeletedObjectsKey] as? NSSet)
            || SearchViewController.containsTerms(info[NSUpdatedObjectsKey] as? NSSet)

        if (termsChanged) {
            /*
            print("termsChanged: contextDidSaveNotification --"
                + " inserted: \((info[NSInsertedObjectsKey] as? NSSet)?.count)"
                + " deleted: \((info[NSDeletedObjectsKey] as? NSSet)?.count)"
                + " updated: \((info[NSUpdatedObjectsKey] as? NSSet)?.count)")
            
            if let inserted = info[NSInsertedObjectsKey] as? NSSet {
                for obj in inserted {
                    let managedObj = obj as! NSManagedObject
                    print("insert: \(managedObj)")
                }
            }
            if let deleted = info[NSDeletedObjectsKey] as? NSSet {
                for obj in deleted {
                    let managedObj = obj as! NSManagedObject
                    print("delete: \(managedObj)")
                }
            }
            if let updated = info[NSUpdatedObjectsKey] as? NSSet {
                for obj in updated {
                    let managedObj = obj as! NSManagedObject
                    print("update: \(managedObj)")
                }
            }
            */
            
            let searchIndex = SearchIndex(query: (UIApplication.shared.delegate as! AppDelegate).dataModel.currentQuery)
            
            // Note: need to call dispatch_sync on the main dispatch queue.  The UI update must happen in the main dispatch queue, and the contextDidSaveNotification cannot return until all objects have been updated.  If a deleted object is used after this method returns then the app will crash with a bad access error.
            dispatch_sync_main({
                trace("SearchViewController.contextDidSave executeSearchForQuery", self.searchBar.text)
                self.searchIndex = searchIndex
                self.executeSearchForQuery(self.searchBar.text)
            })
        }
    }
    
    class func containsTerms(_ managedObjectSet: NSSet?) -> Bool {
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
    
    lazy var searchQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Search queue"
        return queue
        }()
    
    var currentSearchOperation: SearchOperation?
    
    func executeSearchForQuery(_ queryString: String?) {
        trace("SearchViewController.executeSearchForQuery", queryString)
        currentSearchOperation?.cancel()
        
        if (searchIndex == nil) {
            return
        }
        
        let query = (queryString ?? "").lowercased().decomposeAndNormalize()
        if (query.string.isWhitespace()) {
            searchTerms = searchIndex!.allTerms
            self.tableView.reloadData()
        }
        else if (query.nsString.length <= searchIndex!.MaxCount) {
            var result: SearchedAndSorted? = searchIndex!.find(query.string)
            if (result == nil) {
                result = SearchedSetsAndTerms()
            }
            searchTerms = result!
            self.tableView.reloadData()
        }
        else {
            let s = query.nsString.substring(to: searchIndex!.MaxCount)
            var result = searchIndex!.find(s)
            if (result == nil) {
                result = IndexedSetsAndTerms()
            }
            else {
                let searchOp = SearchOperation(query: query, sortSelection: currentSortSelection(), allTerms: result!)
                searchOp.qualityOfService = QualityOfService.userInitiated
                
                searchOp.completionBlock = {
                    DispatchQueue.main.async(execute: {
                        if (searchOp.isCancelled) {
                            return
                        }
                        
                        self.searchTerms = searchOp.searchTerms
                        
                        /*
                        switch (searchOp.sortSelection) {
                        case .atoZ:
                            self.searchTerms.AtoZ = searchOp.searchTerms.AtoZ
                            // searchTerms.levenshteinMatch = searchOp.searchTerms.levenshteinMatch
                        // searchTerms.stringScoreMatch = searchOp.searchTerms.stringScoreMatch
                        case .bySet:
                            self.searchTerms.bySet = searchOp.searchTerms.bySet
                        case .bySetAtoZ:
                            self.searchTerms.bySetAtoZ = searchOp.searchTerms.bySetAtoZ
                        }
                        */
                        
                        self.tableView.reloadData()
                    })
                }
                
                currentSearchOperation = searchOp
                searchQueue.addOperation(searchOp)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // TODO: Dispose of any data model resources that can be refetched
    }
    
    // MARK: - Table view data source

    func numberOfSectionsInTableView(_ tableView: UITableView) -> Int {
        if (showActivityIndicator) {
            return 1
        }
        
        // Return the number of sections.
        var numberOfSections: Int
        switch (currentSortSelection()) {
        case .atoZ:
            numberOfSections = searchTerms.getAtoZCount()
            /*
            numberOfSections = 1
            if (searchTerms.levenshteinMatch.count > 0) {
                numberOfSections++
            }
            if (searchTerms.stringScoreMatch.count > 0) {
                numberOfSections++
            }
            */
        case .bySet:
            numberOfSections = searchTerms.getBySetCount()
        case .bySetAtoZ:
            numberOfSections = searchTerms.getBySetAtoZCount()
        }
        return numberOfSections
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (showActivityIndicator) {
            return 1
        }
        
        // Return the number of rows in the section.
        var numberOfRows: Int
        switch (currentSortSelection()) {
        case .atoZ:
            numberOfRows = searchTerms.getAtoZTermCount(index: section)
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
        case .bySet:
            numberOfRows = searchTerms.getBySetTermCount(index: section)
        case .bySetAtoZ:
            numberOfRows = searchTerms.getBySetAtoZTermCount(index: section)
        }
        return numberOfRows
    }

    //
    // Row
    //
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (showActivityIndicator) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell", for: indexPath)
            let activityIndicator = cell.contentView.viewWithTag(100) as! UIActivityIndicatorView
            activityIndicator.startAnimating()
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchTableViewCell", for: indexPath) as! SearchTableViewCell
        let searchTerm = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())
        configureCell(cell, searchTerm: searchTerm)
        return cell
    }
    
    lazy var highlightForegroundColor = UIColor(red: 25.0 / 255.0, green: 86.0 / 255.0, blue: 204.0 / 255.0, alpha: 1.0)
    lazy var highlightBackgroundColor = UIColor(red: 163.0 / 255.0, green: 205.0 / 255.0, blue: 254.0 / 255.0, alpha: 1.0)
    
    func configureCell(_ cell: SearchTableViewCell, searchTerm: SearchTerm) {
        let termForDisplay = searchTerm.sortTerm.termForDisplay.string
        let termText = NSMutableAttributedString(string: termForDisplay)
        for range in searchTerm.termRanges {
            termText.addAttribute(NSFontAttributeName, value: preferredBoldSearchFont!, range: range)
            termText.addAttribute(NSForegroundColorAttributeName, value: highlightForegroundColor, range: range)
        }
        cell.termLabel.font = preferredSearchFont
        cell.termLabel.attributedText = termText
        
        let definitionForDisplay = searchTerm.sortTerm.definitionForDisplay.string
        let definitionText = NSMutableAttributedString(string: definitionForDisplay)
        for range in searchTerm.definitionRanges {
            definitionText.addAttribute(NSFontAttributeName, value: preferredBoldSearchFont!, range: range)
            definitionText.addAttribute(NSForegroundColorAttributeName, value: highlightForegroundColor, range: range)
        }
        cell.definitionLabel.font = preferredSearchFont
        cell.definitionLabel.attributedText = definitionText
        
        let hasImage = false || false
        if (hasImage) {
            cell.accessoryView = UIImageView(image: nil)
        }
    }
    
    //
    // Row height
    //
    
    var rowHeightCache: [SortTerm: RowHeight] = [:]
    
    struct RowHeight {
        let height: CGFloat
        var isEstimate: Bool
        
        init(height: CGFloat, isEstimate: Bool) {
            self.height = height
            self.isEstimate = isEstimate
        }
    }
    
    lazy var sizingCell: SearchTableViewCell = {
        [unowned self] in
        return self.tableView.dequeueReusableCell(withIdentifier: "SearchTableViewCell") as! SearchTableViewCell
    }()
    
    /**
     * This method should make dynamically sizing table view cells work with iOS 7.  I have not been able
     * to test this because Xcode 7 does not support the iOS 7 simulator.
     */
    func tableView(_ tableView: UITableView, heightForRowAtIndexPath indexPath: IndexPath) -> CGFloat {
        if (showActivityIndicator) {
            return UITableViewAutomaticDimension
        }

        let searchTerm = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())
        var rh = rowHeightCache[searchTerm.sortTerm]
        if (rh == nil || rh!.isEstimate) {
            configureCell(sizingCell, searchTerm: searchTerm)
            rh = RowHeight(height: calculateRowHeight(sizingCell), isEstimate: false)
            if (rh!.height > 0) {
                rowHeightCache[searchTerm.sortTerm] = rh
            }
        }
        return rh!.height
    }
    
    func calculateRowHeight(_ cell: SearchTableViewCell) -> CGFloat {
        // Workaround: setting the bounds for multi-line DynamicLabel instances will cause the preferredMaxLayoutWidth to be set corretly when layoutIfNeeded() is called
        sizingCell.termLabel.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        sizingCell.definitionLabel.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)

        return calculateHeight(sizingCell)
    }
    
    func calculateHeight(_ cell: UITableViewCell) -> CGFloat {
        let indexWidth = Common.getIndexWidthForTableView(tableView, observedTableIndexViewWidth: &observedTableIndexViewWidth, checkTableIndex: true)
        cell.bounds = CGRect(x: 0.0, y: 0.0, width: self.tableView.frame.width - indexWidth, height: cell.bounds.height);
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        
        let height = cell.contentView.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height
        return height + 1.0 // Add 1.0 for the cell separator height
    }
    
    // var estimatedHeight: CGFloat?

    func tableView(_ tableView: UITableView,
                   estimatedHeightForRowAtIndexPath indexPath: IndexPath) -> CGFloat {
        if (showActivityIndicator) {
            return self.tableView(tableView, heightForRowAtIndexPath: indexPath)
        }
        
        // TODO: make sure performance is ok for large sets, may need to go back to quicker estimates
        // if (estimatedHeight == nil) {
        //    sizingCell.termLabel.font = preferredSearchFont
        //    sizingCell.termLabel.text = "Term"
        //    sizingCell.definitionLabel.font = preferredSearchFont
        //    sizingCell.definitionLabel.text = "Definition"
        //    estimatedHeight = calculateRowHeight(sizingCell)
        // }
        
        let searchTerm = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())
        var rh = rowHeightCache[searchTerm.sortTerm]
        if (rh == nil) {
            sizingCell.termLabel.text = searchTerm.sortTerm.termForDisplay.string
            sizingCell.termLabel.font = preferredSearchFont
            
            sizingCell.definitionLabel.text = searchTerm.sortTerm.definitionForDisplay.string
            sizingCell.definitionLabel.font = preferredSearchFont
            
            rh = RowHeight(height: calculateRowHeight(sizingCell), isEstimate: true)
            if (rh!.height > 0) {
                rowHeightCache[searchTerm.sortTerm] = rh
            }
        }
        return rh!.height
    }
    
    //
    // Header
    //
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchTableViewHeaderCell") as! SearchTableViewHeaderCell
        configureHeaderCell(cell, title: headerCellTitle(section: section))
        return cell
    }
    
    func headerCellTitle(section: Int) -> String? {
        var title: String?
        switch (currentSortSelection()) {
        case .atoZ:
            title = searchTerms.getAtoZTitle(index: section)
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
        case .bySet:
            title = searchTerms.getBySetTitle(index: section)
        case .bySetAtoZ:
            title = searchTerms.getBySetAtoZTitle(index: section)
        }
        return title
    }
    
    func configureHeaderCell(_ cell: SearchTableViewHeaderCell, title: String?) {
        cell.headerLabel.font = preferredSearchFont
        cell.headerLabel.text = title
        cell.backgroundColor = UIColor(red: 239, green: 239, blue: 239, alpha: 1.0)
    }
    
    //
    // Header height
    //
    
    var headerHeightCache: [String: CGFloat] = [:]
    
    lazy var headerSizingCell: SearchTableViewHeaderCell = {
        [unowned self] in
        return self.tableView.dequeueReusableCell(withIdentifier: "SearchTableViewHeaderCell") as! SearchTableViewHeaderCell
        }()
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if (showActivityIndicator) {
            return 0
        }
        
        let title = headerCellTitle(section: section)
        var height = headerHeightCache[title ?? ""]
        if (height == nil) {
            configureHeaderCell(headerSizingCell, title: title)
            height = calculateHeaderHeight(headerSizingCell)
            if (height! > 0) {
                headerHeightCache[title ?? ""] = height
            }
        }
        return height!
    }
    
    func calculateHeaderHeight(_ cell: SearchTableViewHeaderCell) -> CGFloat {
        // Use zero height for empty cells
        if (headerSizingCell.headerLabel.text == nil) {
            return 0
        }
        
        // Workaround: setting the bounds for multi-line DynamicLabel instances will cause the preferredMaxLayoutWidth to be set corretly when layoutIfNeeded() is called
        cell.headerLabel.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        
        return calculateHeight(cell)
    }

    var estimatedHeaderHeight: CGFloat?
    
    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        if (estimatedHeaderHeight == nil) {
            headerSizingCell.headerLabel.font = preferredSearchFont
            headerSizingCell.headerLabel.text = "Header"
            estimatedHeaderHeight = calculateHeaderHeight(headerSizingCell)
        }
        
        return estimatedHeaderHeight!
    }
    
    //
    // Table index
    //
    
    // returns the indexed titles that appear in the index list on the right side of the table view. For example, you can return an array of strings containing “A” to “Z”.
    func sectionIndexTitlesForTableView(_ tableView: UITableView) -> [String]? {
        var titles: [String]?
        
        switch (currentSortSelection()) {
        case .atoZ:
            titles = searchTerms.getAtoZSectionIndexTitles()
        case .bySet:
            titles = nil
        case .bySetAtoZ:
            titles = searchTerms.getBySetAtoZSectionIndexTitles()
        }
        
        return titles
    }
    
    // returns the section index that the table view should jump to when user taps a particular index.
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, atIndex index: Int) -> Int {
        return index
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

