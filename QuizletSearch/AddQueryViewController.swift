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

class AddQueryViewController: UITableViewController {

    var tableRows = [QueryRow]()
    
    // MARK: - View Controller
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.All
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableRows.append(QueryRowHeader(type: .Query))
        tableRows.append(QueryRowValue(type: .Query, value: ""))
        tableRows.append(QueryRowHeader(type: .User))
        tableRows.append(QueryRowValue(type: .User, value: "dougzilla32"))
        tableRows.append(QueryRowHeader(type: .Class))
        tableRows.append(QueryRowValue(type: .Class, value: "K10-1 Beginning Korean Level 1"))
        tableRows.append(QueryRowValue(type: .Class, value: "K10-2 Beginning Korean Level 2"))
        tableRows.append(QueryRowValue(type: .Class, value: "준숙기"))
        tableRows.append(QueryRowHeader(type: .Include))
        tableRows.append(QueryRowValue(type: .Include, value: "K10-2 Week 1 Greetings"))
        tableRows.append(QueryRowHeader(type: .Exclude))
        tableRows.append(QueryRowValue(type: .Exclude, value: "K10-2 Week 12 Grammar"))
        tableRows.append(QueryRowHeader(type: .Result))
        tableRows.append(QueryRowValue(type: .Result, value: "K10-2 Week 1 Greetings"))
        tableRows.append(QueryRowValue(type: .Result, value: "K10-2 Week 12 Grammar"))
        tableRows.append(QueryRowValue(type: .Result, value: "Favorite foods"))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source

    // Called before the user changes the selection. Return a new indexPath, or nil, to change the proposed selection.
    override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        return tableRows[indexPath.row].isHeader() ? nil : indexPath
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableRows.count
    }
    
    var sizingCells = [UITableViewCell?](count: QueryRowType.All.count * 2, repeatedValue: nil)
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let row = tableRows[indexPath.row]
        if (!row.isHeader()) {
            cell.textLabel!.text = (row as! QueryRowValue).value
        }
        //    TODO: add a separator between adjacent non-header cells and after the last cell
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(tableRows[indexPath.row].cellIdentifier(), forIndexPath: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let sizingIndex = tableRows[indexPath.row].sizingIndex()
        if (sizingCells[sizingIndex] == nil) {
            sizingCells[sizingIndex] = tableView.dequeueReusableCellWithIdentifier(tableRows[indexPath.row].cellIdentifier())
        }

        let sizingCell = sizingCells[sizingIndex]!
        configureCell(sizingCell, atIndexPath:indexPath)
        
        sizingCell.bounds = CGRectMake(0.0, 0.0, CGRectGetWidth(self.tableView.frame), CGRectGetHeight(sizingCell.bounds));
        sizingCell.setNeedsLayout()
        sizingCell.layoutIfNeeded()
        
        let size = sizingCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        var height = size.height
        
        // TODO: add a separator between adjacent non-header cells and after the last cell
        if (indexPath.row == tableRows.count - 1) {
            height = height + 0.0 // + 1.0 // Add 1.0 for the cell separator height
        }
        return height
    }

    var observedTableIndexViewWidth: CGFloat?
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
