//
//  QueryViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/17/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class QueriesViewController: TableContainerController, UITextFieldDelegate {

    // Load dataModel lazily so the app gets a chance to show the model load error message in the case where the data model is out of sync.
    lazy var dataModel: DataModel = {
        return (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel
    }()
    
    let SearchBarEnabled = false
    
    @IBOutlet weak var searchBar: UISearchBar!

    var currentUser: User!
    var addingRow: Int?
    var editingRow: Int?
    var addAnimationsEnabled: Bool?
    var currentFirstResponder: UITextField?
    var recursiveReloadCounter = 0
    var deferReloadRow: NSIndexPath?
    var updatingText = false
    var inEditMode = false
    var extraRows = 0
    var searchBarHeight: CGFloat!
    var currentContentOffsetY: CGFloat?
    
    enum ExtraRowOptions {
        case InsertOnly, InsertAndDelete
    }

    @IBOutlet weak var editButton: UIButton!

    // MARK: - View Controller
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        if (!SearchBarEnabled) {
            tableView.tableHeaderView = nil
        }
        
        let enabled = UIView.areAnimationsEnabled()
        UIView.setAnimationsEnabled(false)
        defer {
            UIView.setAnimationsEnabled(enabled)
        }

        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        currentUser = dataModel.currentUser!
        
//         tableView.rowHeight = UITableViewAutomaticDimension
//         tableView.estimatedRowHeight = 44.0
        
        // Respond to dynamic type font changes
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "preferredContentSizeChanged:",
            name: UIContentSizeCategoryDidChangeNotification,
            object: nil)
        resetFonts()

        if (SearchBarEnabled) {
            // Scroll the tableView such that the search bar is not visible
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC/100)), dispatch_get_main_queue(), {
                self.searchBarVisibilityWorkaround(.InsertAndDelete)
                
                self.searchBarHeight = self.searchBar.bounds.height
                self.tableView.setContentOffset(CGPoint(x: 0, y: self.searchBarHeight), animated: false)
            })
        }
    }
    
    deinit {
        // Remove all 'self' observers
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    var preferredFont: UIFont?
    
    func preferredContentSizeChanged(notification: NSNotification) {
        resetFonts()        
        self.view.setNeedsLayout()
        tableView.reloadData()
    }
    
    func resetFonts() {
        preferredFont = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
    }
    
    // Workaround for search bar visibility -- there is a bug with UITableView where sometimes the search bar cannot be properly hidden when the user scrolls the table or when programmatically scrolling the table.  By quickly inserting and deleting an empty row in the table the incorrect behavior is alleviated.
    func searchBarVisibilityWorkaround(options: ExtraRowOptions) {
        trace("searchBarVisibilityWorkaround", options)
        let row = self.tableView(tableView, numberOfRowsInSection: 0)
        let indexPath = NSIndexPath(forRow: row, inSection: 0)

        let enabled = UIView.areAnimationsEnabled()
        UIView.setAnimationsEnabled(false)
        defer {
            UIView.setAnimationsEnabled(enabled)
        }

        self.extraRows++
        self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
        if (options == .InsertAndDelete) {
            self.extraRows--
            self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
        }
    }
    
    // Workaround for search bar positioning -- when programmatically manipulating the tableView, sometimes the contentOffset pops to zero such that the search bar becomes visible.  This workaround alleviates the improper behavior.
    func searchBarPositionWorkaround(var overrideContentOffsetY: CGFloat? = nil) {
        if (overrideContentOffsetY == nil) {
            overrideContentOffsetY = currentContentOffsetY
        }

        let needsAdjustment = (overrideContentOffsetY >= searchBarHeight && tableView.contentOffset.y < searchBarHeight)
        trace("searchBarPositionWorkaround needsAdjustment:", needsAdjustment)
        
        if (needsAdjustment) {
            let enabled = UIView.areAnimationsEnabled()
            UIView.setAnimationsEnabled(false)
            defer {
                UIView.setAnimationsEnabled(enabled)
            }

            tableView.setContentOffset(CGPoint(x: 0, y: searchBarHeight), animated: false)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .All
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    
    // MARK: - Navigation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        trace("prepareForSegue", segue.destinationViewController, sender)
        
        if (segue.identifier == "AddQuery") {
            (segue.destinationViewController.childViewControllers[0] as! AddQueryViewController).configureForAdd()
        }
        
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }

    @IBAction func unwindFromUsers(segue: UIStoryboardSegue) {
        trace("unwindFromUsers QueriesViewController")
        let y = currentContentOffsetY
        
        if (SearchBarEnabled) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC/100)), dispatch_get_main_queue(), {
                self.searchBarPositionWorkaround(y)
            })
        }
    }
    
    @IBAction func unwindFromSearch(segue: UIStoryboardSegue) {
        trace("unwindFromSearch QueriesViewController")
        let y = currentContentOffsetY

        if (SearchBarEnabled) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC/100)), dispatch_get_main_queue(), {
                self.searchBarPositionWorkaround(y)
            })
        }

        if (tableView.indexPathForSelectedRow != nil) {
            tableView.deselectRowAtIndexPath(tableView.indexPathForSelectedRow!, animated: false)
        }
    }
    
    @IBAction func unwindFromAddQuery(segue: UIStoryboardSegue) {
        trace("unwindFromAddQuery QueriesViewController segueId:", segue.identifier)
        
        if (segue.identifier != "AddQueryAdd") {
            return
        }

        currentContentOffsetY = tableView.contentOffset.y
        if (currentFirstResponder != nil) {
            addAnimationsEnabled = UIView.areAnimationsEnabled()
            UIView.setAnimationsEnabled(false)
            if (Common.isEmpty(currentFirstResponder!.text)) {
                // Already have a blank textfield as first responder
                return
            }
            currentFirstResponder!.resignFirstResponder()
        }
        
        // Delete this comment when confirmed to work properly.  Workaround -- use dispatch_after to avoid race condition between the current textfield resigning the first responder and inserting the new row into the table
        let query = dataModel.newQueryForUser(dataModel.currentUser!)
        let addQueryViewController = segue.sourceViewController as! AddQueryViewController
        addQueryViewController.saveToQuery(query)

        query.title = ""
        if (!query.query.isEmpty) {
            query.title += query.query
        }
        if (!query.creators.isEmpty) {
            if (!query.title.isEmpty) {
                query.title += " "
            }
            query.title += query.creators.stringByReplacingOccurrencesOfString(",", withString: " ")
        }
        if (!query.classes.isEmpty) {
            if (!query.title.isEmpty) {
                query.title += " "
            }
            query.title += query.classes.stringByReplacingOccurrencesOfString(",", withString: " ")
        }
        
        currentUser.addQuery(query)
        dataModel.saveChanges()
        
        let indexPath = NSIndexPath(forRow: currentUser.queries.count-1, inSection: 0)
        editingRow = indexPath.row
        tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
        addingRow = indexPath.row
    }
    
    @IBAction func edit(sender: AnyObject) {
        tableView.editing = !tableView.editing
        inEditMode = tableView.editing
        editButton.setTitle(tableView.editing ? "Done" : "Edit", forState: UIControlState.Normal)

        recursiveReloadCounter++
        extraRows = 0
        tableView.reloadData()
        if (SearchBarEnabled) {
            self.searchBarVisibilityWorkaround(.InsertOnly)
        }
        recursiveReloadCounter--
    }
    
    @IBAction func updateText(sender: AnyObject) {
        currentContentOffsetY = tableView.contentOffset.y
        let enabled = UIView.areAnimationsEnabled()
        UIView.setAnimationsEnabled(false)
        updatingText = true
        let textField = sender as! UITextField
        trace("updateText IN text:", textField.text)
        textField.resignFirstResponder()
        trace("updateText OUT text:", textField.text, "defer:", deferReloadRow?.row)
        updatingText = false
        UIView.setAnimationsEnabled(enabled)
        
        if (deferReloadRow != nil) {
            tableView.reloadRowsAtIndexPaths([deferReloadRow!], withRowAnimation: UITableViewRowAnimation.Automatic)
            deferReloadRow = nil
        }
    }
    
    // MARK: - Textfield delegate
    
    func textFieldDidBeginEditing(textField: UITextField) {
        currentFirstResponder = textField
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        editingRow = nil
        
        var text = textField.text
        if (text != nil) {
            text = text!.trimWhitespace()
        }
        else {
            text = ""
        }

        let indexPath = indexPathForTextField(textField)
        var deleteRow: NSIndexPath?
        var reloadRow: NSIndexPath?
        
        if (text!.isEmpty) {
            if (addingRow == indexPath.row) {
                // Delete
                let query = (currentUser.queries[indexPath.row] as! Query)
                currentUser.removeQueryAtIndex(indexPath.row)
                dataModel.moc.deleteObject(query)
                dataModel.saveChanges()
                deleteRow = indexPath
            }
            else {
                // Revert
                reloadRow = indexPath
            }
        }
        else {
            // Apply
            (currentUser.queries[indexPath.row] as! Query).title = text!
            dataModel.saveChanges()
            reloadRow = indexPath
        }
        
        if (recursiveReloadCounter == 0) {
            if (deleteRow != nil) {
                trace("deleteRow row:", indexPath.row)
                tableView.deleteRowsAtIndexPaths([deleteRow!], withRowAnimation: UITableViewRowAnimation.Automatic)
            }
            if (reloadRow != nil) {
                trace("reloadRow row:", indexPath.row, "updatingText:", updatingText)
                if (updatingText) {
                    deferReloadRow = reloadRow
                }
                else {
                    tableView.reloadRowsAtIndexPaths([reloadRow!], withRowAnimation: UITableViewRowAnimation.Automatic)
                }
            }
        }
        
        addingRow = nil
        currentFirstResponder = nil
        if (SearchBarEnabled) {
            searchBarPositionWorkaround()
        }
    }
    
    func indexPathForTextField(textField: UITextField) -> NSIndexPath {
        let textInputCell = textField.superview!.superview as! UITableViewCell
        
        // Use indexPathForRowAtPoint rather than indexPathForCell because indexPathForCell returns nil if the cell is not yet visible (either scrolled off or not yet realized)
        return tableView.indexPathForRowAtPoint(textInputCell.center)!
    }
    
    // MARK: - Table view delegate

    func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        currentContentOffsetY = tableView.contentOffset.y
        return indexPath
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        trace("select", indexPath.row)
        dataModel.currentQuery = dataModel.currentUser?.queries[indexPath.row] as? Query
//        self.performSegueWithIdentifier("MySegue", sender: self)
    }
    
    // MARK: - Table view data source

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return indexPath.row < currentUser.queries.count
    }
    
    func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return indexPath.row < currentUser.queries.count
    }
    
    func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        currentUser.moveQueriesAtIndexes(NSIndexSet(index: sourceIndexPath.row), toIndex: destinationIndexPath.row)
        dataModel.saveChanges()
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            if (currentFirstResponder != nil) {
                currentContentOffsetY = tableView.contentOffset.y
                
                let enabled = UIView.areAnimationsEnabled()
                UIView.setAnimationsEnabled(false)
                currentFirstResponder!.resignFirstResponder()
                UIView.setAnimationsEnabled(enabled)
            }

            currentUser.removeQueryAtIndex(indexPath.row)
            dataModel.saveChanges()
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numRows = currentUser.queries.count
        if (!inEditMode) {
            numRows++
        }
        numRows += extraRows
        return numRows
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellId: String
        if (indexPath.row == currentUser.queries.count && !inEditMode) {
            cellId = "Add button"
        }
        else if (indexPath.row >= currentUser.queries.count) {
            cellId = "Empty"
        }
        else if (inEditMode || indexPath.row == editingRow) {
            cellId = "TextField"
        }
        else {
            cellId = "Label"
        }
        
        trace("cellForRow row:", indexPath.row, "cellId:", cellId)
        
        let cell = tableView.dequeueReusableCellWithIdentifier(cellId, forIndexPath: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        
        if (indexPath.row == editingRow) {
            let textField = cell.contentView.viewWithTag(100) as! UITextField
            if (!textField.isFirstResponder()) {
                textField.becomeFirstResponder()
            }
            
            if let enabled = addAnimationsEnabled {
                addAnimationsEnabled = nil
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC/100)), dispatch_get_main_queue(), {
                    UIView.setAnimationsEnabled(enabled)
                })
            }
        }
        
        return cell
    }
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        if (indexPath.row < currentUser.queries.count) {
            let queryData = currentUser.queries[indexPath.row] as! Query
            let text = queryData.title
            if (inEditMode || indexPath.row == editingRow) {
                let textField = cell.contentView.viewWithTag(100) as! UITextField
                textField.text = text
                textField.font = preferredFont
            }
            else {
                let label = cell.contentView.viewWithTag(100) as! UILabel
                label.text = text
                label.font = preferredFont
            }
        }
    }
    
    lazy var labelSizingCell: UITableViewCell = {
        return self.tableView.dequeueReusableCellWithIdentifier("Label")!
    }()
    
    lazy var textFieldSizingCell: UITableViewCell = {
        return self.tableView.dequeueReusableCellWithIdentifier("TextField")!
    }()
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let cell = (inEditMode || indexPath.row == editingRow) ? textFieldSizingCell : labelSizingCell
        configureCell(cell, atIndexPath:indexPath)
        return calculateHeight(cell)
    }
    
    func calculateHeight(cell: UITableViewCell) -> CGFloat {
        cell.bounds = CGRectMake(0.0, 0.0, CGRectGetWidth(self.tableView.frame), CGRectGetHeight(cell.bounds));
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        
        let size = cell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        return size.height + 1.0 // Add 1.0 for the cell separator height
    }
    
    func tableView(tableView: UITableView,
        estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
            return 44.0
    }

    //
    // Header
    //
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = tableView.dequeueReusableCellWithIdentifier("Header")!
        configureHeaderCell(cell, section: section)
        return cell
    }
    
    func configureHeaderCell(cell: UITableViewCell, section: Int) {
        let label = cell.contentView.viewWithTag(100) as! UILabel
        label.text = "Filtered by sets containing:"
        label.font = preferredFont
    }
    
    //
    // Header height
    //
    
    lazy var headerSizingCell: UITableViewCell = {
        return self.tableView.dequeueReusableCellWithIdentifier("Header")!
    }()
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        configureHeaderCell(headerSizingCell, section: section)
        return calculateHeaderHeight(headerSizingCell)
    }
    
    func calculateHeaderHeight(cell: UITableViewCell) -> CGFloat {
        // Workaround: setting the bounds for multi-line UILabel instances will cause the preferredMaxLayoutWidth to be set corretly when layoutIfNeeded() is called
        let label = cell.contentView.viewWithTag(100) as! UILabel
        label.bounds = CGRectMake(0.0, 0.0, 0.0, 0.0)
        return calculateHeight(cell)
    }
}
