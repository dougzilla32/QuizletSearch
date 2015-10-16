//
//  AddQueryViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/17/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class AddQueryViewController: UITableViewController, UISearchBarDelegate, UITextFieldDelegate {

    let QueryLabelSection = 0
    let ResultsSection = 1
    
    let quizletSession = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel.quizletSession
    var model = AddQueryModel()
    
    // MARK: - View Controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable selections in the table
        tableView.allowsSelection = false
        
        // Allow the user to dismiss the keyboard by touch-dragging down to the bottom of the screen
        tableView.keyboardDismissMode = .Interactive
        
        // Respond to dynamic type font changes
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "preferredContentSizeChanged:",
            name: UIContentSizeCategoryDidChangeNotification,
            object: nil)
        resetFonts()
        
        self.navigationController!.navigationBar.titleTextAttributes =
            [NSFontAttributeName: UIFont(name: "Noteworthy-Bold", size: 18)!]
        
        model.reloadData()
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.All
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        // Remove all 'self' observers
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - Search Bar
    
    var searchBar: UISearchBar!
    var searchBarCurrentText: String?
    var disableSearchBarEndEdit = false
    
    // called when text starts editing
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
    }
    
    // called when text ends editing
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        searchBarCurrentText = searchBar.text

        if (!disableSearchBarEndEdit) {
            executeSearchForQuery(searchBar.text, isSearchAssist: false, scrollToResults: false)
        }
    }
    
    // called when text changes (including clear)
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        executeSearchForQuery(searchBar.text, isSearchAssist: true, scrollToResults: true)
    }
    
    // Have the keyboard close when 'Return' is pressed
    func searchBar(searchBar: UISearchBar, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool
    {
        if (text == "\n") {
            // The user pressed 'Search', run a full query in this case
            disableSearchBarEndEdit = true
            searchBar.resignFirstResponder()
            disableSearchBarEndEdit = false

            executeSearchForQuery(searchBar.text, isSearchAssist: false, scrollToResults: true)
        }
        return true
    }
    
    func executeSearchForQuery(var query: String?, isSearchAssist: Bool, scrollToResults: Bool) {
        if (query == nil) {
            query = ""
        }
        query = query!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        model.query.query = query!
        model.query.isSearchAssist = isSearchAssist
        
        executeQuery(scrollToResults: scrollToResults)
    }
    
    func executeQuery(scrollToResults scrollToResults: Bool) {
        var firstLoaded = true
        let isSearchAssist = model.query.isSearchAssist
        
        model.executeQuery(completionHandler: { (pageLoaded: Int?, response: PagerResponse) -> Void in
            isSearchAssist ? self.safelyReloadData() : self.resetSearchBar()
            if (pageLoaded != nil && response == .First && scrollToResults && firstLoaded) {
                self.scrollToResults()
                firstLoaded = false
            }
        })
    }
    
    // Workaround for a UITableView bug where it will crash when reloadData is called on the table if the search bar currently has the keyboard focus
    func safelyReloadData() {
        disableSearchBarEndEdit = true
        let searchBarFirstResponder = searchBar.isFirstResponder()
        if (searchBarFirstResponder) {
            searchBar.resignFirstResponder()
        }
        disableSearchBarEndEdit = false
        
        indexPathForDesiredFirstResponder = indexPathForCurrentFirstResponder
        tableView.reloadData()

        if (searchBarFirstResponder) {
            searchBar.becomeFirstResponder()
        }
    }
    
    func scrollToResults() {
        // Workaround: when the keyboard is showing and there are only a few rows, scrollToRowAtIndexPath will leave some rows occluded by the keyboard and will not properly scroll the table.  Use dispatch_after to introduce a delay as a workaround -- for some reason it works when this delay is introduced.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC/100)), dispatch_get_main_queue(), {
            self.tableView.scrollToRowAtIndexPath(self.model.resultHeaderPath(), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
            
        })
    }
    
    func resignAndResetSearchBar() {
        if (searchBar.isFirstResponder()) {
            searchBar.resignFirstResponder()
        }
        
        resetSearchBar()
    }

    func resetSearchBar() {
        if (searchBar != nil) {
            searchBar.delegate = nil
        }
        searchBar = nil
        
        // Workaround: call reloadData to avoid a crash when insertRowsAtIndexPaths is called
        indexPathForDesiredFirstResponder = indexPathForCurrentFirstResponder
        tableView.reloadData()
    }
    
    // MARK: - Editable cells
    
    func textFieldDidBeginEditing(textField: UITextField) {
        // became first responder
        
        // Use indexPathForRowAtPoint rather than indexPathForCell because indexPathForCell returns nil if the cell is not yet visible (either scrolled off or not yet realized)
        let textInputCell = textField.superview!.superview as! TextInputTableViewCell
        indexPathForCurrentFirstResponder = tableView.indexPathForRowAtPoint(textInputCell.center)
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        indexPathForCurrentFirstResponder = nil
    }
    
    // called when text changes (including clear)
    func textField(textField: UITextField, textDidChange searchText: String) {
    }
    
    @IBAction func updateText(sender: AnyObject) {
        (sender as! UITextField).resignFirstResponder()
    }
    
    // Restore the first responder textfield after reloadData is called on the table
    var indexPathForCurrentFirstResponder: NSIndexPath?
    
    // Gives the newly added textfield the keyboard focus (it becomes the first responder when 'cellForRowAtIndexPath' is called with the firstResponderIndexPath index path)
    var indexPathForDesiredFirstResponder: NSIndexPath?
    
    @IBAction func addUser(sender: AnyObject) {
        resignAndResetSearchBar()
        
        let indexPath = self.model.appendUser("dougzilla32")
        indexPathForDesiredFirstResponder = indexPath
        self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)

        model.query.isSearchAssist = false
        executeQuery(scrollToResults: false)
    }
    
    @IBAction func addClass(sender: AnyObject) {
        resignAndResetSearchBar()
        
        let indexPath = model.appendClass("669401")
        indexPathForDesiredFirstResponder = indexPath
        tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
        
        model.query.isSearchAssist = false
        executeQuery(scrollToResults: false)
    }
    
    var preferredFont: UIFont!
    var preferredBoldFont: UIFont!
    var italicFont: UIFont!
    var smallerFont: UIFont!
    var estimatedHeightForSearchAssistCell: CGFloat?
    var estimatedHeightForResultCell: CGFloat?
    
    func preferredContentSizeChanged(notification: NSNotification) {
        resetFonts()
    }
    
    func resetFonts() {
        preferredFont = Common.preferredSearchFontForTextStyle(UIFontTextStyleBody)
        preferredBoldFont = Common.preferredSearchFontForTextStyle(UIFontTextStyleHeadline)
        
        let fontDescriptor = preferredFont.fontDescriptor().fontDescriptorWithSymbolicTraits(UIFontDescriptorSymbolicTraits.TraitItalic)
        italicFont = UIFont(descriptor: fontDescriptor, size: preferredFont.pointSize)
        
        smallerFont = UIFont(descriptor: preferredFont.fontDescriptor(), size: preferredFont.pointSize - 3.0)
        
        estimatedHeightForSearchAssistCell = nil
        estimatedHeightForResultCell = nil
        
        self.view.setNeedsLayout()
    }
    
    // MARK: - Table view data source

    // Called before the user changes the selection. Return a new indexPath, or nil, to change the proposed selection.
    override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        return model.isHeaderAtPath(indexPath) ? nil : indexPath
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 2
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.numberOfRowsInSection(section)
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifierForPath(indexPath), forIndexPath: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        if let textInputCell = cell as? TextInputTableViewCell where indexPath == indexPathForDesiredFirstResponder {
            if (!textInputCell.textField.isFirstResponder()) {
                textInputCell.textField.becomeFirstResponder()
            }
            indexPathForDesiredFirstResponder = nil
        }

        return cell
    }
    
    func cellIdentifierForPath(indexPath: NSIndexPath) -> String {
        return model.cellIdentifierForPath(indexPath)
    }
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let qset: QSet?

        if let resultRow = model.resultRowForIndexPath(indexPath) {
            // result row
            if (model.isActivityIndicatorRow(resultRow)) {
                qset = nil
            }
            else {
                qset = model.pagers!.getQSetForRow(resultRow, completionHandler: { (pageLoaded: Int?, response: PagerResponse) -> Void in
                    dispatch_async(dispatch_get_main_queue(), {
                        self.safelyReloadData()
                    })
                })
                
                if (qset == nil) {
                    return
                }
            }
        }
        else {
            qset = nil
        }
    
        configureCell(cell, atIndexPath: indexPath, qset: qset)
    }
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath, qset: QSet!) {
        if let resultRow = model.resultRowForIndexPath(indexPath) {
            // result row
            if (model.isActivityIndicatorRow(resultRow)) {
                let activityIndicator = cell.contentView.viewWithTag(100) as! UIActivityIndicatorView
                activityIndicator.startAnimating()
                return
            }
            
            if (qset.title.isEmpty && qset.createdBy.isEmpty && qset.description.isEmpty) {
                // Empty cell
                return
            }
            
            let title = qset.title.trimWhitespace()
            let owner = qset.createdBy.trimWhitespace()
            let description = qset.description.trimWhitespace()
            
            let titleLength = (title as NSString).length
            let ownerLength = (owner as NSString).length
            let descriptionLength = (description as NSString).length
            
            var labelText: String = ""
            
            let titleIndex = 0
            if (titleLength > 0) {
                labelText += title
            }
            
            var ownerIndex: Int
            if (ownerLength > 0) {
                ownerIndex = (labelText as NSString).length
                if (ownerIndex > 0) {
                    labelText += "\n"
                    ownerIndex++
                }
                labelText += owner
            }
            else {
                ownerIndex = 0
            }
            
            let hasDescription = !description.isEmpty && description.lowercaseString != title.lowercaseString
            var descriptionIndex: Int
            if (hasDescription) {
                descriptionIndex = (labelText as NSString).length
                if (descriptionIndex > 0) {
                    labelText += "\n"
                    descriptionIndex++
                }
                labelText += description
            }
            else {
                descriptionIndex = 0
            }
            
            let attributedText = NSMutableAttributedString(string: labelText)
            attributedText.addAttribute(NSFontAttributeName, value: preferredFont, range: NSMakeRange(titleIndex, titleLength))
            attributedText.addAttribute(NSFontAttributeName, value: italicFont, range: NSMakeRange(ownerIndex, ownerLength))
            if (hasDescription) {
                attributedText.addAttribute(NSFontAttributeName, value: smallerFont, range: NSMakeRange(descriptionIndex, descriptionLength))
            }
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing += 10.0
            
            /* Alternatively could use tabs and tab stops in combination with newlines for formatting the title, owner and description in the cell
            let frameWidth = CGRectGetWidth(self.tableView.frame)
            let tabLocation = min(frameWidth / 2, 260.0)
            paragraphStyle.tabStops = [
                NSTextTab(textAlignment: NSTextAlignment.Left, location: tabLocation, options: [:]),
                NSTextTab(textAlignment: NSTextAlignment.Left, location: tabLocation + 10.0, options: [:]),
                NSTextTab(textAlignment: NSTextAlignment.Left, location: tabLocation + 20.0, options: [:]),
                NSTextTab(textAlignment: NSTextAlignment.Left, location: tabLocation + 30.0, options: [:]),
                NSTextTab(textAlignment: NSTextAlignment.Left, location: tabLocation + 40.0, options: [:]),
            ]
            */
            
            // Only apply paragraph spacing for last paragraph in title and last paragraph in owner.  Do not apply to paragraphs elsewhere.
            var start: Int = 0
            var end: Int = 0

            (title as NSString).getParagraphStart(&start, end: &end, contentsEnd: nil, forRange: NSMakeRange(titleLength, 0))
            attributedText.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSMakeRange(titleIndex + start, end - start))

            (owner as NSString).getParagraphStart(&start, end: &end, contentsEnd: nil, forRange: NSMakeRange(ownerLength, 0))
            attributedText.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSMakeRange(ownerIndex + start, end - start))
            
            if (model.query.isSearchAssist) {
                let searchAssistCell = (cell as! LabelTableViewCell)
                searchAssistCell.label.attributedText = attributedText
                return
            }
            
            let setCell = (cell as! SetTableViewCell)
            setCell.label.attributedText = attributedText
            
            /* Alternatively could use three labels instead of one label to position the title, owner and description in the cell
            let title = cell.contentView.viewWithTag(100) as! UILabel
            let owner = cell.contentView.viewWithTag(110) as! UILabel
            let description = cell.contentView.viewWithTag(120) as! UILabel
            
            title.text = qset.title
            owner.text = qset.createdBy
            description.text = qset.description
            */
            
            // Terms
            let termLabels = [ setCell.term0, setCell.term1, setCell.term2 ]
            let definitionLabels = [ setCell.definition0, setCell.definition1, setCell.definition2 ]
            
            for i in 0...2 {
                if (i < qset.terms.count) {
                    var term: String! = qset.terms[i].term.trimWhitespace()
                    var definition: String! = qset.terms[i].definition.trimWhitespace()
                    
                    // Make sure term and definition always line up horizontally in the cell even if one or the other is empty
                    if (term.isEmpty && definition.isEmpty) {
                        term = nil
                        definition = nil
                    }
                    else if (term.isEmpty) {
                        term = "\u{200B}"
                    }
                    else if (definition.isEmpty) {
                        definition = "\u{200B}"
                    }
                    
                    termLabels[i].text = term
                    definitionLabels[i].text = definition
                }
                else {
                    termLabels[i].text = nil
                    definitionLabels[i].text = nil
                }
                termLabels[i].font = smallerFont
                definitionLabels[i].font = smallerFont
            }
        }
        else {
            if (model.isHeaderAtPath(indexPath)) {
                let label = cell.contentView.viewWithTag(100) as! UILabel
                label.font = preferredFont
                if (model.resultHeaderPath() == indexPath) {
                    if let t = model.totalResults {
                        switch (t) {
                        case 0:
                            label.text = "0 results"
                        case 1:
                            label.text = "1 result"
                        case 5000:
                            // The Quizlet hardcoded upper limit on the number of search results is 5,000
                            label.text = "Over 5,000 results:"
                        default:
                            let numberFormatter = NSNumberFormatter()
                            numberFormatter.numberStyle = .DecimalStyle
                            let formattedTotalResults = numberFormatter.stringFromNumber(t)
                            label.text = "\(formattedTotalResults!) results:"
                        }
                    }
                    else {
                        label.text = "Search results:"
                    }
                }
            }
            else if let textInputCell = cell as? TextInputTableViewCell {
                textInputCell.textField.text = model.rowItemForPath(indexPath)
                textInputCell.textField.font = preferredFont
                textInputCell.textField.autocapitalizationType = UITextAutocapitalizationType.None
                textInputCell.textField.autocorrectionType = UITextAutocorrectionType.No
                textInputCell.textField.spellCheckingType = UITextSpellCheckingType.No
                textInputCell.textField.returnKeyType = UIReturnKeyType.Search
            }
            else {
                cell.textLabel!.text = model.rowItemForPath(indexPath)
                cell.textLabel!.font = preferredFont
            }
        }
    }
    
    var sizingCells: [String: UITableViewCell] = [:]
    
    /**
     * This method should make dynamically sizing table view cells work with iOS 7.  I have not been able
     * to test this because Xcode 7 does not support the iOS 7 simulator.
     */
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let cellIdentifier = cellIdentifierForPath(indexPath)
        var cell = sizingCells[cellIdentifier]
        if (cell == nil) {
            cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)
            sizingCells[cellIdentifier] = cell!
        }

        configureCell(cell!, atIndexPath: indexPath)
        return calculateHeight(cell!)
    }
    
    func calculateHeight(cell: UITableViewCell) -> CGFloat {
        cell.bounds = CGRectMake(0.0, 0.0, CGRectGetWidth(self.tableView.frame), CGRectGetHeight(cell.bounds))

        // Workaround: setting the bounds for multi-line DynamicLabel instances will cause the preferredMaxLayoutWidth to be set corretly when layoutIfNeeded() is called
        if let labelCell = cell as? LabelTableViewCell {
            labelCell.label.bounds = CGRectMake(0.0, 0.0, 0.0, 0.0)
        }
        else if let setCell = cell as? SetTableViewCell {
            setCell.label.bounds = CGRectMake(0.0, 0.0, 0.0, 0.0)
        }
        else if let textInputCell = cell as? TextInputTableViewCell {
            textInputCell.textField.bounds = CGRectMake(0.0, 0.0, 0.0, 0.0)
        }
        
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        
        let height = cell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
        return height + 1.0 // Add 1.0 for the cell separator height
    }

    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if (section == ResultsSection) {
            if (searchBar == nil) {
                searchBar = UISearchBar()
                searchBar.text = searchBarCurrentText
                configureSearchBar(searchBar)
                searchBar.delegate = self
            }

            return searchBar
         
        }
        else {
            return nil
        }
    }
    
    func configureSearchBar(searchBar: UISearchBar) {
        searchBar.placeholder = "Search"

        // Update the appearance of the search bar's textfield
        let searchTextField = Common.findTextField(searchBar)!
        searchTextField.font = preferredFont
        searchTextField.autocapitalizationType = UITextAutocapitalizationType.None
        searchTextField.enablesReturnKeyAutomatically = false
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return (section == ResultsSection) ? heightForSearchBar() - 3.0 : 0  // Subtract 3 to reduce borders to look better
    }
    
    var sizingSearchBar: UISearchBar!

    func heightForSearchBar() -> CGFloat {
        if (sizingSearchBar == nil) {
            sizingSearchBar = UISearchBar()
        }
        
        configureSearchBar(sizingSearchBar)
        sizingSearchBar.bounds = CGRectMake(0.0, 0.0, 0.0, 0.0)
        sizingSearchBar.setNeedsLayout()
        sizingSearchBar.layoutIfNeeded()
        
        let height = sizingSearchBar.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
        return height + 1.0 // Add 1.0 for the cell separator height
    }
    
    override func tableView(tableView: UITableView,
        estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
            let height: CGFloat
            if let resultRow = model.resultRowForIndexPath(indexPath) {
                if (model.isActivityIndicatorRow(resultRow)) {
                    height = self.tableView(tableView, heightForRowAtIndexPath: indexPath)
                }
                else if (model.query.isSearchAssist) {
                    if (estimatedHeightForSearchAssistCell == nil) {
                        let cellIdentifier = "Search Assist Cell"
                        var sizingCell = sizingCells[cellIdentifier]
                        if (sizingCell == nil) {
                            sizingCell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)
                            sizingCells[cellIdentifier] = sizingCell!
                        }
                        
                        let qset = QSet(id: 0, url: "", title: "Title", description: "", createdBy: "Owner", creatorId: 0, createdDate: 0, modifiedDate: 0)
                        configureCell(sizingCell!, atIndexPath: indexPath, qset: qset)
                        estimatedHeightForSearchAssistCell = calculateHeight(sizingCell!)
                    }
                    height = estimatedHeightForSearchAssistCell!
                }
                else {
                    if (estimatedHeightForResultCell == nil) {
                        let cellIdentifier = "Result Cell"
                        var sizingCell = sizingCells[cellIdentifier]
                        if (sizingCell == nil) {
                            sizingCell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)
                            sizingCells[cellIdentifier] = sizingCell!
                        }
                        
                        let qset = QSet(id: 0, url: "", title: "Title", description: "", createdBy: "Owner", creatorId: 0, createdDate: 0, modifiedDate: 0)
                        qset.terms = [
                            QTerm(id: 0, term: "Term 1", definition: "Definition 1"),
                            QTerm(id: 0, term: "Term 2", definition: "Definition 2"),
                            QTerm(id: 0, term: "Term 3", definition: "Definition 3"),
                        ]
                        configureCell(sizingCell!, atIndexPath: indexPath, qset: qset)
                        estimatedHeightForResultCell = calculateHeight(sizingCell!)
                    }
                    height = estimatedHeightForResultCell!
                }
            }
            else {
                height = self.tableView(tableView, heightForRowAtIndexPath: indexPath)
            }
            
            return height
    }

    override func tableView(tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return self.tableView(tableView, heightForHeaderInSection: section)
    }
}
