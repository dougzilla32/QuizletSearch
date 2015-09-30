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
            return
        }
        query = query!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if (query!.isEmpty) {
            return
        }
        
        print("Execute query: \(query!)")
        setPager = SetPager(query: query!, creator: nil)
        setPager!.loadPage(1, completionHandler: { (pageLoaded: Int?) -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                self.tableView.reloadData()
                let indexPath = NSIndexPath(forRow: self.tableRows[self.resultsSection].count-1, inSection: self.resultsSection)
                self.tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Top, animated: true)
            })
        })
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
    
    func preferredContentSizeChanged(notification: NSNotification) {
        resetFonts()
    }
    
    func resetFonts() {
        preferredFont = Common.preferredSearchFontForTextStyle(UIFontTextStyleBody)
        preferredBoldFont = Common.preferredSearchFontForTextStyle(UIFontTextStyleHeadline)
        
        estimatedHeight = nil
        
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
            // search result row
            let resultRow = indexPath.row - tableRows[indexPath.section].count
            let qset = setPager!.getQSetForRow(resultRow)
            if (qset == nil) {
                setPager!.loadRow(resultRow, completionHandler: { (pageLoaded: Int?) -> Void in
                    dispatch_async(dispatch_get_main_queue(), {
                        self.tableView.reloadData()
                    })
                })
            }
            cell.textLabel!.text = qset?.title
            cell.textLabel!.font = preferredFont
        }
        
        // TODO: add a separator between adjacent non-header cells and after the last cell
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        var sizingIndex: Int
        var cellIdentifier: String
        if (indexPath.row < tableRows[indexPath.section].count) {
            sizingIndex = tableRows[indexPath.section][indexPath.row].sizingIndex()
            cellIdentifier = tableRows[indexPath.section][indexPath.row].cellIdentifier()
        }
        else {
            sizingIndex = QueryRowType.Result.rawValue + QueryRowType.All.count
            cellIdentifier = "Result Cell"
        }
        return heightForCell(cellIdentifier, indexPath: indexPath, sizingIndex: sizingIndex)
    }
    
    var sizingCells = [UITableViewCell?](count: QueryRowType.All.count * 2, repeatedValue: nil)
    let searchCellSizingIndex = 1
    
    func heightForCell(cellIdentifier: String, indexPath: NSIndexPath, sizingIndex: Int) -> CGFloat {
        if (sizingCells[sizingIndex] == nil) {
            sizingCells[sizingIndex] = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)
        }
        
        let sizingCell = sizingCells[sizingIndex]!
        configureCell(sizingCell, atIndexPath: indexPath)

        var height = layoutSizingCell(sizingCell)

        // TODO: add a separator between adjacent non-header cells and after the last cell
        if (indexPath.section == resultsSection && indexPath.row == tableRows[indexPath.section].count - 1) {
            height = height + 0.0 // + 1.0 // Add 1.0 for the cell separator height
        }
        return height
    }
    
    func layoutSizingCell(sizingCell: UITableViewCell) -> CGFloat {
        sizingCell.bounds = CGRectMake(0.0, 0.0, CGRectGetWidth(self.tableView.frame), CGRectGetHeight(sizingCell.bounds));
        sizingCell.setNeedsLayout()
        sizingCell.layoutIfNeeded()
        
        let size = sizingCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        return size.height
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
        
        return heightForSearchCell(searchHeader.cellIdentifier(), sizingIndex: searchHeader.sizingIndex())
    }

    func heightForSearchCell(cellIdentifier: String, sizingIndex: Int) -> CGFloat {
        if (sizingCells[sizingIndex] == nil) {
            sizingCells[sizingIndex] = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)
        }
        
        let sizingCell = sizingCells[sizingIndex]!
        configureSearchCell(sizingCell)
        return layoutSizingCell(sizingCell)
    }
    
    var estimatedHeight: CGFloat?
    
    override func tableView(tableView: UITableView,
        estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
            
            if (estimatedHeight == nil) {
                let sizingIndex = tableRows[indexPath.section][indexPath.row].sizingIndex()
                if (sizingCells[sizingIndex] == nil) {
                    sizingCells[sizingIndex] = tableView.dequeueReusableCellWithIdentifier(tableRows[indexPath.section][indexPath.row].cellIdentifier())
                }
                
                let sizingCell = sizingCells[sizingIndex]!
                configureCell(sizingCell, atIndexPath:indexPath)

                sizingCell.textLabel!.font = preferredFont
                sizingCell.textLabel!.text = "Result"
                
                estimatedHeight = layoutSizingCell(sizingCell)
            }
            
            return estimatedHeight!
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
