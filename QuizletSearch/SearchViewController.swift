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

class SearchViewController: TableViewControllerBase, UITableViewDelegate, UIScrollViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var sortStyle: UISegmentedControl!
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    var searchBarBecomesFirstResponder = false
    
    var observedTableIndexViewWidth: CGFloat?
    
    var showActivityIndicator = true
    
    var animationBlock: ((CGPoint, _ completionHandler: @escaping () -> Void) -> Void)?
    var animationContext: WhooshAnimationContext?
    
    let SearchBarPlaceholderPrefix = "Search \""
    let SearchBarPlaceholderSuffix = "\" terms"
    
    // MARK: - Sorting
    
    var searchIndex: SearchIndex?
    var searchTerms: SearchedAndSorted = SortedSetsAndTerms()
    
    struct TermHeight {
        let height: CGFloat
        let termIsTaller: Bool
    }
    
    var termHeightCache: [SortTerm: TermHeight] = [:]
    var headerHeightCache: [String: CGFloat] = [:]
    
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
        
        let data: String
        switch (currentSortSelection()) {
        case .atoZ:
            data = searchTerms.exportAtoZ()
        case .bySet:
            data = searchTerms.exportBySet()
        case .bySetAtoZ:
            data = searchTerms.exportBySetAtoZ()
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
    
    // Have the keyboard close when 'Search' is pressed
    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool // called before text changes
    {
        if (text == "\n") {
            searchBar.resignFirstResponder()
        }
        return true
    }
    
    // MARK: - View Controller
        
    override var shouldAutorotate : Bool {
        return true
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return .all
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.isNavigationBarHidden = true
        
        if (searchBarBecomesFirstResponder) {
            searchBar.becomeFirstResponder()
        }
    }
    
    override func viewDidLoad() {
        trace("SearchViewController viewDidLoad()")
        super.viewDidLoad()
        
        // Enable selections in the table
        tableView.allowsSelection = true
        
        // Allow the user to dismiss the keyboard by touch-dragging down to the bottom of the screen
        tableView.keyboardDismissMode = .interactive
        
        // Respond to dynamic type font changes
        NotificationCenter.default.addObserver(self,
            selector: #selector(SearchViewController.preferredContentSizeChanged(_:)),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil)
        resetFonts()
        
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
    
    var isFirstViewDidLayoutSubviews = false
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if (!isFirstViewDidLayoutSubviews) { return }
        isFirstViewDidLayoutSubviews = false
        
        termHeightCache.removeAll(keepingCapacity: true)
        headerHeightCache.removeAll(keepingCapacity: true)

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
    
    // Called when the view has been fully transitioned onto the screen. Default does nothing
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    // Called after the view was dismissed, covered or otherwise hidden.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.refreshControl.endRefreshing()
    }
    
    func hideTitleText() -> CGPoint {
        let searchTextField = Common.findTextField(self.searchBar)!
        let title = dataModel().currentQuery!.title

        // Set the title text to clearColor
        let attributedPlaceholder = NSMutableAttributedString(attributedString: searchTextField.attributedPlaceholder!)
        attributedPlaceholder.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.clear, range: NSRange(location: (SearchBarPlaceholderPrefix as NSString).length, length: (title as NSString).length))
        searchTextField.attributedPlaceholder = attributedPlaceholder

        // Calculate the frame for the title text
        let absoluteOrigin = searchTextField.superview!.convert(searchTextField.frame.origin, to: UIApplication.shared.keyWindow!)
        let placeholderBounds = searchTextField.placeholderRect(forBounds: searchTextField.bounds)
        let fontAttributes = [NSAttributedString.Key.font: searchTextField.font!]
        let prefixSize = SearchBarPlaceholderPrefix.size(withAttributes: fontAttributes)
        
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
    
    @objc func preferredContentSizeChanged(_ notification: Notification) {
        resetFonts()
        self.view.setNeedsLayout()
    }
    
    func resetFonts() {
        preferredSearchFont = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
        preferredBoldSearchFont = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
        
        termSizingCell.termLabel.font = preferredSearchFont
        termSizingCell.definitionLabel.font = preferredSearchFont
        definitionSizingCell.termLabel.font = preferredSearchFont
        definitionSizingCell.definitionLabel.font = preferredSearchFont

        estimatedHeaderHeight = nil
        estimatedHeight = nil
       
        sortStyle.setTitleTextAttributes([NSAttributedString.Key.font: preferredSearchFont!], for: UIControl.State())
        
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
            let addQueryViewController = segue.destination.children[0] as! AddQueryViewController
            addQueryViewController.configureForSave(dataModel().currentQuery!)
        }
        else if (segue.identifier == "SearchUnwind" /* && Common.isEmpty(searchBar.text) */) {
            searchBar.text = nil
            
            if (WhooshAnimationEnabled) {
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
    @objc func contextDidSaveNotification(_ notification: Notification) {
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
            dispatchSyncMain({
                trace("SearchViewController.contextDidSave executeSearchForQuery", self.searchBar.text)
                self.searchIndex = searchIndex
                
                termHeightCache.removeAll(keepingCapacity: true)
                headerHeightCache.removeAll(keepingCapacity: true)

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
        else if (SearchIndexEnabled && query.nsString.length <= searchIndex!.MaxCount) {
            var result: SearchedAndSorted? = searchIndex!.find(query.string)
            if (result == nil) {
                result = SearchedSetsAndTerms()
            }
            searchTerms = result!
            self.tableView.reloadData()
        }
        else {
            let searchOp: SearchOperation?
            if (SearchIndexEnabled) {
                let s = query.nsString.substring(to: searchIndex!.MaxCount)
                var result = searchIndex!.find(s)
                if (result == nil) {
                    result = IndexedSetsAndTerms()
                    searchOp = nil
                }
                else {
                    searchOp = SearchOperation(query: query, sortSelection: currentSortSelection(), allTermsIndexed: result!)
                }
            }
            else {
                searchOp = SearchOperation(query: query, sortSelection: currentSortSelection(), allTermsSorted: searchIndex!.allTerms)
            }
            
            if (searchOp != nil) {
                searchOp!.qualityOfService = QualityOfService.userInitiated
                searchOp!.completionBlock = {
                    DispatchQueue.main.async(execute: {
                        if (searchOp!.isCancelled) {
                            return
                        }
                        
                        self.searchTerms = searchOp!.searchTerms
                        self.tableView.reloadData()
                    })
                }
                
                currentSearchOperation = searchOp!
                searchQueue.addOperation(searchOp!)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Table view data source

    // Called after the user changes the selection.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let searchTerm = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())

        Common.launchQuizletForSet(id: searchTerm.sortTerm.setId, deadline: .now() + 0.5, execute: {
            tableView.deselectRow(at: indexPath, animated: false)
        })
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (showActivityIndicator) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell", for: indexPath)
            let activityIndicator = cell.contentView.viewWithTag(100) as! UIActivityIndicatorView
            activityIndicator.startAnimating()
            return cell
        }

        let searchTerm = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())
        var termHeight = termHeightCache[searchTerm.sortTerm]
        if (termHeight == nil) {
            _ = self.tableView(tableView, heightForRowAt: indexPath)
            termHeight = termHeightCache[searchTerm.sortTerm]
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchTableViewCell", for: indexPath) as! SearchTableViewCell
        
        // Force the label heights to the max of their respective heights, otherwise some rows will be too short.  AutoLayout has problems
        // getting the height correct for the two labels together (I think because of the text wrapping in the labels).
        SearchViewController.updateHeightConstraint(label: cell.termLabel, height: termHeight!.height)
        SearchViewController.updateHeightConstraint(label: cell.definitionLabel, height: termHeight!.height)
        
        configureCell(cell, searchTerm: searchTerm, useTerm: true, useDefinition: true)
        return cell
    }
    
    class func updateHeightConstraint(label: UILabel, height: CGFloat) {
        var foundHeight = false
        for c in label.constraints {
            if (c.firstAttribute == .height) {
                foundHeight = true
                c.constant = height
                break
            }
        }
        if (!foundHeight) {
            label.addConstraint(NSLayoutConstraint(item: label, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: height))
        }
    }
    
    lazy var highlightForegroundColor = UIColor(red: 25.0 / 255.0, green: 86.0 / 255.0, blue: 204.0 / 255.0, alpha: 1.0)
    lazy var highlightBackgroundColor = UIColor(red: 217.0 / 255.0, green: 232.0 / 255.0, blue: 251.0 / 255.0, alpha: 1.0)
    
    func configureCell(_ cell: SearchTableViewCell, searchTerm: SearchTerm, useTerm: Bool, useDefinition: Bool) {
        let termForDisplay = useTerm ? searchTerm.sortTerm.termForDisplay.string : ""
        let termText = NSMutableAttributedString(string: termForDisplay)
        if (useTerm) {
            for range in searchTerm.termRanges {
                termText.addAttribute(NSAttributedString.Key.font, value: preferredBoldSearchFont!, range: range)
                termText.addAttribute(NSAttributedString.Key.foregroundColor, value: highlightForegroundColor, range: range)
                termText.addAttribute(NSAttributedString.Key.backgroundColor, value: highlightBackgroundColor, range: range)
            }
        }
        cell.termLabel.font = preferredSearchFont
        cell.termLabel.attributedText = termText
        
        let definitionForDisplay = useDefinition ? searchTerm.sortTerm.definitionForDisplay.string : ""
        let definitionText = NSMutableAttributedString(string: definitionForDisplay)
        if (useDefinition) {
            for range in searchTerm.definitionRanges {
                definitionText.addAttribute(NSAttributedString.Key.font, value: preferredBoldSearchFont!, range: range)
                definitionText.addAttribute(NSAttributedString.Key.foregroundColor, value: highlightForegroundColor, range: range)
                definitionText.addAttribute(NSAttributedString.Key.backgroundColor, value: highlightBackgroundColor, range: range)
            }
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
    
    lazy var termSizingCell: SearchTableViewCell = {
        [unowned self] in
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "SearchTableViewTermCell") as! SearchTableViewCell
        SearchViewController.removeHeightConstraint(label: cell.termLabel)
        SearchViewController.removeHeightConstraint(label: cell.definitionLabel)
        return cell
        }()
    
    lazy var definitionSizingCell: SearchTableViewCell = {
        [unowned self] in
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "SearchTableViewDefinitionCell") as! SearchTableViewCell
        SearchViewController.removeHeightConstraint(label: cell.termLabel)
        SearchViewController.removeHeightConstraint(label: cell.definitionLabel)
        return cell
        }()
    
    class func removeHeightConstraint(label: UILabel) {
        for c in label.constraints {
            if (c.firstAttribute == .height) {
                label.removeConstraint(c)
                break
            }
        }
    }
    
    /**
     * This method should make dynamically sizing table view cells work with iOS 7.  I have not been able
     * to test this because Xcode 7 does not support the iOS 7 simulator.
     */
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (showActivityIndicator) {
            return UITableView.automaticDimension
        }

        let searchTerm = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())
        
        var height = termHeightCache[searchTerm.sortTerm]?.height
        if (height == nil) {
            configureCell(termSizingCell, searchTerm: searchTerm, useTerm: true, useDefinition: false)
            let termHeight = calculateRowHeight(termSizingCell)

            configureCell(definitionSizingCell, searchTerm: searchTerm, useTerm: false, useDefinition: true)
            let definitionHeight = calculateRowHeight(definitionSizingCell)
            
            height = max(termHeight, definitionHeight)
            if (height! > 0) {
                termHeightCache[searchTerm.sortTerm] = TermHeight(height: height!, termIsTaller: termHeight > definitionHeight)
            }
        }
        return height!
    }
    
    func calculateRowHeight(_ cell: SearchTableViewCell) -> CGFloat {
        // Workaround: setting the bounds for multi-line DynamicLabel instances will cause the preferredMaxLayoutWidth to be set corretly when layoutIfNeeded() is called
        cell.termLabel.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        cell.definitionLabel.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)

        return calculateHeight(cell)
    }
    
    func calculateHeight(_ cell: UITableViewCell) -> CGFloat {
        let indexWidth = Common.getIndexWidthForTableView(tableView, observedTableIndexViewWidth: &observedTableIndexViewWidth, checkTableIndex: true)
        cell.bounds = CGRect(x: 0.0, y: 0.0, width: self.tableView.frame.width - indexWidth, height: cell.bounds.height);
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        
        let height = cell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        return height + 1.0 // Add 1.0 for the cell separator height
    }
    
    var estimatedHeight: CGFloat?

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if (showActivityIndicator) {
            return self.tableView(tableView, heightForRowAt: indexPath)
        }

        let searchTerm = searchTerms.termForPath(indexPath, sortSelection: currentSortSelection())
        var height = termHeightCache[searchTerm.sortTerm]?.height
        if (height == nil) {
            if (estimatedHeight == nil) {
                termSizingCell.termLabel.font = preferredSearchFont
                termSizingCell.termLabel.text = "Term"
                termSizingCell.definitionLabel.font = preferredSearchFont
                termSizingCell.definitionLabel.text = "Definition"
                estimatedHeight = calculateRowHeight(termSizingCell)
            }
            height = estimatedHeight!
        }
        return height!
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
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
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
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return index
    }
}

