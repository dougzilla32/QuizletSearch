//
//  QueryViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/17/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class QueriesViewController: TableContainerController, UITextFieldDelegate {
    
    // TODO: remove static, communicate this to AddQueryViewController some other way
    static var currentQueryData: Query!
    
    let dataModel = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel
    
    var queries: NSMutableOrderedSet!
    var addingRow: Int?
    var editingRow: Int?
    var reloadCounter = 0

    @IBOutlet weak var editButton: UIButton!

    // MARK: - View Controller
    
    override func viewWillAppear(animated: Bool) {
        UIView.setAnimationsEnabled(false)
        navigationController?.setNavigationBarHidden(true, animated: false)
        UIView.setAnimationsEnabled(true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        queries = dataModel.currentUser!.queries.mutableCopy() as! NSMutableOrderedSet
        
        // tableView.rowHeight = UITableViewAutomaticDimension
        // tableView.estimatedRowHeight = 44.0
        
//        tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0), atScrollPosition: UITableViewScrollPosition.Top, animated: false)
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
    
    @IBAction func unwindFromUsers(segue: UIStoryboardSegue) {
        print("unwindFromUsers QueriesViewController")
    }
    
    @IBAction func unwindFromSearch(segue: UIStoryboardSegue) {
        print("unwindFromSearch QueriesViewController")
        if (tableView.indexPathForSelectedRow != nil) {
            tableView.deselectRowAtIndexPath(tableView.indexPathForSelectedRow!, animated: false)
        }
    }
    
    @IBAction func add(sender: AnyObject) {
        let query = dataModel.newQueryForUser(dataModel.currentUser!)
        queries.addObject(query)
        
        let indexPath = NSIndexPath(forRow: queries.count-1, inSection: 0)
        addingRow = indexPath.row
        editingRow = indexPath.row
        tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
        
        save()
    }
    
    @IBAction func edit(sender: AnyObject) {
        tableView.editing = !tableView.editing
        
//        let indexPath = NSIndexPath(forRow: queries.count, inSection: 0)
//        if (tableView.editing) {
//            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
//        }
//        else {
//            tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
//        }
        
        editButton.setTitle(tableView.editing ? "Done" : "Edit", forState: UIControlState.Normal)

        reloadCounter++
        tableView.reloadData()
        reloadCounter--
    }
    
    func save() {
//        dataModel.currentUser!.queries = queries
    }
    
    // MARK: - Textfield delegate
    
//    func textFieldDidBeginEditing(textField: UITextField) {
//        trace("didBeginEditing", textField.text)
//    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        var text = textField.text
        if (text != nil) {
            text = text!.trimWhitespace()
        }
        else {
            text = ""
        }

        let indexPath = indexPathForTextField(textField)
        if (text!.isEmpty) {
            if (addingRow == indexPath.row) {
                // Delete
                queries.removeObjectAtIndex(indexPath.row)
                if (reloadCounter == 0) {
                    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
                }
            }
            else {
                // Revert
                if (reloadCounter == 0) {
                    tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
                }
            }
        }
        else {
            // Apply
            (queries[indexPath.row] as! Query).title = text!
            if (reloadCounter == 0) {
                tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
            }
        }
        
        addingRow = nil
        editingRow = nil
        
        save()
    }
    
//    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
//        if (string == "\n") {
//            return true
//        }
//        return true
//    }
    
    @IBAction func updateText(sender: AnyObject) {
        let textField = sender as! UITextField
        textField.resignFirstResponder()
    }
    
    func indexPathForTextField(textField: UITextField) -> NSIndexPath {
        let textInputCell = textField.superview!.superview as! UITableViewCell
        
        // Use indexPathForRowAtPoint rather than indexPathForCell because indexPathForCell returns nil if the cell is not yet visible (either scrolled off or not yet realized)
        return tableView.indexPathForRowAtPoint(textInputCell.center)!
    }
    
    // MARK: - Table view delegate

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        trace("select", indexPath.row)
//        self.performSegueWithIdentifier("MySegue", sender: self)
    }

    // MARK: - Table view data source

    func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return indexPath.row < queries.count
    }
    
    func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        queries.moveObjectsAtIndexes(NSIndexSet(index: sourceIndexPath.row), toIndex: destinationIndexPath.row)
        
        tableView.reloadData()
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            queries.removeObjectAtIndex(indexPath.row)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numRows = queries.count
        if (!tableView.editing) {
            numRows++
        }
        return numRows
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellId: String
        if (indexPath.row == queries.count) {
            cellId = "Add button"
        }
        else if (tableView.editing || indexPath.row == editingRow) {
            cellId = "TextField"
        }
        else {
            cellId = "Label"
        }
        
        let cell = tableView.dequeueReusableCellWithIdentifier(cellId, forIndexPath: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        
        if (indexPath.row == editingRow) {
            let textField = cell.contentView.viewWithTag(100) as! UITextField
            if (!textField.isFirstResponder()) {
                textField.becomeFirstResponder()
            }
        }
        
        return cell
    }
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        if (indexPath.row < queries.count) {
            let queryData = queries[indexPath.row] as! Query
            let text = queryData.title
            if (tableView.editing || indexPath.row == editingRow) {
                let textField = cell.contentView.viewWithTag(100) as! UITextField
                textField.text = text
            }
            else {
                let label = cell.contentView.viewWithTag(100) as! UILabel
                label.text = text
            }
        }
        // label.font = preferredSearchFont
    }
    
    lazy var labelSizingCell: UITableViewCell = {
        return self.tableView.dequeueReusableCellWithIdentifier("Label")!
    }()
    
    lazy var textFieldSizingCell: UITableViewCell = {
        return self.tableView.dequeueReusableCellWithIdentifier("TextField")!
    }()
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let cell = (tableView.editing || indexPath.row == editingRow) ? textFieldSizingCell : labelSizingCell
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
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
