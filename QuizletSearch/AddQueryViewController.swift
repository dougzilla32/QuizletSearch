//
//  AddQueryViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/17/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class AddQueryViewController: UITableViewController, UISearchBarDelegate {

    let QueryLabelSection = 0
    let ResultsSection = 1
    
    let quizletSession = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel.quizletSession
    
    var model = AddQueryModel()
    var setPager: SetPager?
    var searchBar: UISearchBar!
    
    // MARK: - Search Bar
    
    // called when text starts editing
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        self.searchBar = searchBar
    }
    
    // called when text ends editing
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        if (searchBar.text == "") {
            executeSearchForQuery("", isSearchAssist: false)
        }
    }
    
    // called when text changes (including clear)
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchBar = searchBar
        executeSearchForQuery(searchBar.text, isSearchAssist: true)
    }
    
    // Have the keyboard close when 'Return' is pressed
    func searchBar(searchBar: UISearchBar, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool // called before text changes
    {
        if (text == "\n") {
            searchBar.resignFirstResponder()
            executeSearchForQuery(searchBar.text, isSearchAssist: false)
        }
        return true
    }
    
    func hideKeyboard(recognizer: UITapGestureRecognizer) {
        if (searchBar != nil) {
            searchBar.resignFirstResponder()
            executeSearchForQuery(searchBar.text, isSearchAssist: false)
        }
    }
    
    func executeSearchForQuery(var query: String?, isSearchAssist: Bool) {
        if (query == nil) {
            query = ""
        }
        query = query!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if (query!.isEmpty) {
            setPager = nil
            safelyReloadData()
            return
        }
        
        if (setPager != nil && isSearchAssist && setPager!.isSearchAssist) {
            setPager!.resetForSearchAssist(query: query!, creator: nil)
        }
        else {
            setPager = SetPager(query: query!, creator: nil, isSearchAssist: isSearchAssist)
        }
        
        setPager!.loadPage(1, completionHandler: { (pageLoaded: Int?, response: SetPager.Response) -> Void in
            self.safelyReloadData()
            if (response == .First) {
                self.scrollToResults()
            }
        })
    }
    
    // Workaround for a UITableView bug where it will crash when reloadData is called on the table if the search bar currently has the keyboard focus
    func safelyReloadData() {
        let isFirstResponder = searchBar.isFirstResponder()
        if (isFirstResponder) {
            searchBar.resignFirstResponder()
        }

        tableView.reloadData()

        if (isFirstResponder) {
            searchBar.becomeFirstResponder()
        }
    }
    
    func scrollToResults() {
        // Workaround: when the keyboard is showing and there are only a few rows, scrollToRowAtIndexPath will leave some rows occluded by the keyboard and will not properly scroll the table.  Use dispatch_after to introduce a delay as a workaround -- for some reason it works when this delay is introduced.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC/100)), dispatch_get_main_queue(), {
            self.tableView.scrollToRowAtIndexPath(self.model.resultHeaderPath(), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
            
        })
    }
    
    // MARK: - Gestures
    
    
    @IBAction func addUser(sender: AnyObject) {
        print("addUser")
    }

    // MARK: - View Controller
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.All
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Disable selections in the table
        tableView.allowsSelection = false
        
        // Dismiss keyboard when user touches the table
        let gestureRecognizer = UITapGestureRecognizer(target: self,  action: "hideKeyboard:")
        gestureRecognizer.cancelsTouchesInView = false
        tableView.addGestureRecognizer(gestureRecognizer)
        
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

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
        var numRows = model.numberOfRowsInSection(section)
        if (section == ResultsSection && setPager != nil) {
            if (setPager!.totalResults != nil) {
                numRows += setPager!.totalResults!
            }
            else if (setPager!.isLoading()) {
                // Activity Indicator row
                numRows++
            }
        }
        return numRows
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifierForPath(indexPath), forIndexPath: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    func cellIdentifierForPath(indexPath: NSIndexPath) -> String {
        var cellIdentifier: String
        if (!isResultRow(indexPath)) {
            cellIdentifier = model.cellIdentifierForPath(indexPath)
        }
        else {
            // result row
            let resultRow = indexPath.row - model.numberOfRowsInSection(indexPath.section)
            
            if (isActivityIndicatorRow(resultRow)) {
                cellIdentifier = "Activity Cell"
            }
            else {
                // Use zero height cell for empty qsets.  We insert empty qsets if the Quitlet paging query returns fewer pages than expected (this happens occasionally).
                let qset = setPager?.peekQSetForRow(resultRow)
                if (qset != nil && qset!.title.isEmpty && qset!.createdBy.isEmpty && qset!.description.isEmpty) {
                    cellIdentifier = "Empty Cell"
                }
                else if (setPager != nil && setPager!.isSearchAssist) {
                    cellIdentifier = "Search Assist Cell"
                }
                else {
                    cellIdentifier = "Result Cell"
                }
            }
        }
        return cellIdentifier
    }
    
    func isResultRow(indexPath: NSIndexPath) -> Bool {
        return (indexPath.row >= model.numberOfRowsInSection(indexPath.section))
    }
    
    func isActivityIndicatorRow(row: Int) -> Bool {
        return (setPager == nil || setPager!.totalResults == nil || row >= setPager!.totalResults)
    }
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let qset: QSet?
        if (!isResultRow(indexPath)) {
            qset = nil
        }
        else {
            // result row
            let resultRow = indexPath.row - model.numberOfRowsInSection(indexPath.section)
            if (isActivityIndicatorRow(resultRow)) {
                qset = nil
            }
            else {
                qset = setPager!.getQSetForRow(resultRow, completionHandler: { (pageLoaded: Int?, response: SetPager.Response) -> Void in
                    dispatch_async(dispatch_get_main_queue(), {
                        self.safelyReloadData()
                    })
                })

                if (qset == nil) {
                    return
                }
            }
        }
    
        configureCell(cell, atIndexPath: indexPath, qset: qset)
    }
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath, qset: QSet!) {
        if (!isResultRow(indexPath)) {
            if (model.isHeaderAtPath(indexPath)) {
                let label = cell.contentView.viewWithTag(100) as! UILabel
                label.font = preferredFont
                if (model.resultHeaderPath() == indexPath) {
                    if (setPager?.totalResults != nil) {
                        switch (setPager!.totalResults!) {
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
                            let formattedTotalResults = numberFormatter.stringFromNumber(setPager!.totalResults!)
                            label.text = "\(formattedTotalResults!) results:"
                        }
                    }
                    else {
                        label.text = "Search results:"
                    }
                }
            }
            else {
                cell.textLabel!.text = model.rowItemForPath(indexPath)
                cell.textLabel!.font = preferredFont
            }
        }
        else {
            // result row
            let resultRow = indexPath.row - model.numberOfRowsInSection(indexPath.section)
            if (isActivityIndicatorRow(resultRow)) {
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
            
            if (setPager != nil && setPager!.isSearchAssist) {
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
        if let setCell = cell as? SetTableViewCell {
            setCell.label.bounds = CGRectMake(0.0, 0.0, 0.0, 0.0)
        }
        
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        
        let height = cell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
        return height + 1.0 // Add 1.0 for the cell separator height
    }

    var searchCell: UITableViewCell?

    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if (section == ResultsSection) {
            if (searchCell == nil) {
                searchCell = tableView.dequeueReusableCellWithIdentifier("Query Cell")
                configureSearchCell(searchCell!)
            }
            return searchCell!.contentView
        }
        else {
            return nil
        }
    }
    
    func configureSearchCell(cell: UITableViewCell) {
        // Update the appearance of the search bar's textfield
        let searchBar = cell.contentView.viewWithTag(100) as! UISearchBar
        let searchTextField = Common.findTextField(searchBar)!
        searchTextField.font = preferredFont
        searchTextField.autocapitalizationType = UITextAutocapitalizationType.None
        searchTextField.enablesReturnKeyAutomatically = false
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if (section == QueryLabelSection) {
            return 0
        }
        
        return heightForSearchCell("Query Cell")
    }

    func heightForSearchCell(cellIdentifier: String) -> CGFloat {
        if (sizingCells[cellIdentifier] == nil) {
            sizingCells[cellIdentifier] = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)
        }
        
        let sizingCell = sizingCells[cellIdentifier]!
        configureSearchCell(sizingCell)
        return calculateHeight(sizingCell)
    }

    override func tableView(tableView: UITableView,
        estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
            let height: CGFloat
            if (!isResultRow(indexPath)) {
                height = self.tableView(tableView, heightForRowAtIndexPath: indexPath)
            }
            else {
                let resultRow = indexPath.row - model.numberOfRowsInSection(indexPath.section)
                if (isActivityIndicatorRow(resultRow)) {
                    height = self.tableView(tableView, heightForRowAtIndexPath: indexPath)
                }
                else if (setPager != nil && setPager!.isSearchAssist) {
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
            
            return height
    }

    override func tableView(tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return self.tableView(tableView, heightForHeaderInSection: section)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
