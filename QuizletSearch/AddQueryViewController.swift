//
//  AddQueryViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/17/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

enum QueryRowType: Int {
    case Query, User, Class, Include, Exclude, Result
    
    static let All = [Query, User, Class, Include, Exclude, Result]
    static let Identifier = ["Query", "User", "Class", "Include", "Exclude", "Result"]
}

protocol QueryRow {
    var type: QueryRowType { get }
    
    func isHeader() -> Bool
    func cellIdentifier() -> String
    func sizingIndex() -> Int
}

class QueryRowHeader: QueryRow {
    var type: QueryRowType
    init(type: QueryRowType) { self.type = type }
    
    func isHeader() -> Bool { return true }
    func cellIdentifier() -> String { return QueryRowType.Identifier[type.rawValue] + " Header" }
    func sizingIndex() -> Int { return type.rawValue }
}

class QueryRowValue: QueryRow {
    var type: QueryRowType
    var value: String
    init(type: QueryRowType, value: String) { self.type = type; self.value = value }
    
    func isHeader() -> Bool { return false }
    func cellIdentifier() -> String { return QueryRowType.Identifier[type.rawValue] + " Cell" }
    func sizingIndex() -> Int { return type.rawValue + QueryRowType.All.count }
}

class AddQueryViewController: UITableViewController, UISearchBarDelegate {

    let queryLabelSection = 0
    let resultsSection = 1
    
    var setPager: SetPager?
    
    var tableRows: [[QueryRow]]!
    var searchHeader: QueryRow!
    var searchBar: UISearchBar!
    
    // MARK: - Search Bar
    
    // called when text starts editing
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        self.searchBar = searchBar
    }
    
    // called when text ends editing
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        if (searchBar.text == "") {
            executeSearchForQuery("")
        }
    }
    
    // called when text changes (including clear)
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchBar = searchBar
    }
    
    // Have the keyboard close when 'Return' is pressed
    func searchBar(searchBar: UISearchBar, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool // called before text changes
    {
        if (text == "\n") {
            searchBar.resignFirstResponder()
            executeSearchForQuery(searchBar.text)
        }
        return true
    }
    
    func hideKeyboard(recognizer: UITapGestureRecognizer) {
        searchBar?.resignFirstResponder()
    }
    
    func executeSearchForQuery(var query: String?) {
        if (query == nil) {
            query = ""
        }
        query = query!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if (query!.isEmpty) {
            setPager = nil
            self.tableView.reloadData()
            return
        }
        
        setPager = SetPager(query: query!, creator: nil)
        setPager!.loadPage(1, completionHandler: { (pageLoaded: Int?) -> Void in
            self.tableView.reloadData()
            self.scrollToResults()
        })
    }
    
    func scrollToResults() {
        let indexPath = NSIndexPath(forRow: self.tableRows[self.resultsSection].count-1, inSection: self.resultsSection)
        self.tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Top, animated: true)
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
        
        // Register for keyboard show and hide notifications, to adjust the table view when the keyboard is showing
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
        
        self.navigationController!.navigationBar.titleTextAttributes =
            [NSFontAttributeName: UIFont(name: "Noteworthy-Bold", size: 18)!]
        
        tableRows = [[QueryRow](), [QueryRow]()]
        tableRows[0].append(QueryRowHeader(type: .Query))
        searchHeader = QueryRowValue(type: .Query, value: "")
        tableRows[1].append(QueryRowHeader(type: .User))
        // tableRows[1].append(QueryRowValue(type: .User, value: "dougzilla32"))
        tableRows[1].append(QueryRowHeader(type: .Class))
        // tableRows[1].append(QueryRowValue(type: .Class, value: "K10-1 Beginning Korean Level 1"))
        // tableRows[1].append(QueryRowValue(type: .Class, value: "K10-2 Beginning Korean Level 2"))
        // tableRows[1].append(QueryRowValue(type: .Class, value: "준숙기"))
        // tableRows[1].append(QueryRowHeader(type: .Include))
        // tableRows[1].append(QueryRowValue(type: .Include, value: "K10-2 Week 1 Greetings"))
        // tableRows[1].append(QueryRowHeader(type: .Exclude))
        // tableRows[1].append(QueryRowValue(type: .Exclude, value: "K10-2 Week 12 Grammar"))
        tableRows[1].append(QueryRowHeader(type: .Result))
        
        // tableRows.append(QueryRowValue(type: .Result, value: "K10-2 Week 1 Greetings"))
        // tableRows.append(QueryRowValue(type: .Result, value: "K10-2 Week 12 Grammar"))
        // tableRows.append(QueryRowValue(type: .Result, value: "Favorite foods"))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
    
    var preferredFont: UIFont!
    var preferredBoldFont: UIFont!
    var italicFont: UIFont!
    var smallerFont: UIFont!
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
        
        estimatedHeightForResultCell = nil
        
        self.view.setNeedsLayout()
    }
    
    // MARK: - Table view data source

    // Called before the user changes the selection. Return a new indexPath, or nil, to change the proposed selection.
    override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        return tableRows[indexPath.section][indexPath.row].isHeader() ? nil : indexPath
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 2
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numRows = tableRows[section].count
        if (section == resultsSection && setPager?.totalResults != nil) {
            numRows += (setPager?.totalResults)!
        }
        return numRows
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cellIdentifier: String
        if (indexPath.row < tableRows[indexPath.section].count) {
            cellIdentifier = tableRows[indexPath.section][indexPath.row].cellIdentifier()
        }
        else {
            cellIdentifier = "Result Cell"
        }
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let qset: QSet?
        if (indexPath.row < tableRows[indexPath.section].count) {
            qset = nil
        }
        else {
            // result row
            let resultRow = indexPath.row - tableRows[indexPath.section].count
            qset = setPager!.getQSetForRow(resultRow)
            if (qset == nil) {
                setPager!.loadRow(resultRow, completionHandler: { (pageLoaded: Int?) -> Void in
                    dispatch_async(dispatch_get_main_queue(), {
                        self.tableView.reloadData()
                    })
                })
                return
            }
        }
        
        configureCell(cell, atIndexPath: indexPath, qset: qset)
    }
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath, qset: QSet!) {
        if (indexPath.row < tableRows[indexPath.section].count) {
            let row = tableRows[indexPath.section][indexPath.row]
            if (row.isHeader()) {
                let label = cell.contentView.viewWithTag(100) as! UILabel
                label.font = preferredFont
            }
            else {
                cell.textLabel!.text = (row as! QueryRowValue).value
                cell.textLabel!.font = preferredFont
            }
        }
        else {
            /* TODO: remove debugging code
            if (true) {
                let text = "The quick brown fox jumped over the lazy dog.  The quick brown fox jumped over the lazy dog.  The quick brown fox jumped over the lazy dog."
                // let label = cell.contentView.viewWithTag(100) as! SearchLabel
                let label = (cell as! LabelTableViewCell).label!
                label.text = text
                label.font = preferredFont
                return
            }
            */
            
            let title = qset.title.trimWhitespace()
            let owner = qset.createdBy.trimWhitespace()
            let description = qset.description.trimWhitespace()
            
            let titleCount = title.characters.count
            let ownerCount = owner.characters.count
            let descriptionCount = description.characters.count
            
            var labelText: String = "\(title)\n\(owner)"
            let titleIndex = 0
            let ownerIndex = titleCount + 1
            
            let descriptionIndex: Int
            if (!description.isEmpty) {
                labelText += "\n\(description)"
                descriptionIndex = titleCount + ownerCount + 2
            }
            else {
                descriptionIndex = 0
            }
            
            // TODO: remove debugging statement
            // print("[ \(labelText) ]")
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing += 10.0
            // paragraphStyle.minimumLineHeight += 10.0
            
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
            
            let attributedText = NSMutableAttributedString(string: labelText)
            attributedText.addAttribute(NSFontAttributeName, value: italicFont, range: NSMakeRange(ownerIndex, ownerCount))
            attributedText.addAttribute(NSFontAttributeName, value: preferredFont, range: NSMakeRange(titleIndex, titleCount))
            if (!description.isEmpty) {
                attributedText.addAttribute(NSFontAttributeName, value: smallerFont, range: NSMakeRange(descriptionIndex, descriptionCount))
            }
            
            // Only apply paragraph spacing for title and owner newlines, not the newlines in the description
            let paragraphCount = description.isEmpty
                ? titleCount + ownerCount + 1
                : titleCount + ownerCount + 2
            attributedText.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSMakeRange(0, paragraphCount))
            
            let label = (cell as! LabelTableViewCell).label
            label.attributedText = attributedText
            
            /* Alternatively could use three labels instead of one label to position the title, owner and description in the cell
            let title = cell.contentView.viewWithTag(100) as! UILabel
            let owner = cell.contentView.viewWithTag(110) as! UILabel
            let description = cell.contentView.viewWithTag(120) as! UILabel
            
            title.text = qset?.title
            owner.text = qset?.createdBy
            description.text = qset?.description
            */
        }
    }
    
    var sizingCells: [String: UITableViewCell] = [:]
    
    /**
     * This method should make dynamically sizing table view cells work with iOS 7.  I have not been able
     * to test this because Xcode 7 does not support the iOS 7 simulator.
     */
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let cellIdentifier: String
        if (indexPath.row < tableRows[indexPath.section].count) {
            cellIdentifier = tableRows[indexPath.section][indexPath.row].cellIdentifier()
        }
        else {
            cellIdentifier = "Result Cell"
        }

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
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        
        var height = cell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
        height = height + 1.0 // Add 1.0 for the cell separator height
        return height
    }
    
    var searchCell: UITableViewCell?

    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if (section == resultsSection) {
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
        if (section == queryLabelSection) {
            return 0
        }
        
        return heightForSearchCell(searchHeader.cellIdentifier())
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
            if (indexPath.row < tableRows[indexPath.section].count) {
                return self.tableView(tableView, heightForRowAtIndexPath: indexPath)
            }

            if (estimatedHeightForResultCell == nil) {
                let cellIdentifier = "Result Cell"
                var sizingCell = sizingCells[cellIdentifier]
                if (sizingCell == nil) {
                    sizingCell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)
                    sizingCells[cellIdentifier] = sizingCell!
                }
            
                let qset = QSet(id: 0, url: "", title: "Title", description: "", createdBy: "Owner", creatorId: 0, createdDate: 0, modifiedDate: 0)
                configureCell(sizingCell!, atIndexPath: indexPath, qset: qset)
                estimatedHeightForResultCell = calculateHeight(sizingCell!)
            }
            
            return estimatedHeightForResultCell!
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
