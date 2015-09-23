//
//  AddQueryViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/17/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class AddQueryViewController: UITableViewController {

    // MARK: - View Controller
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.All
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AddQueryViewController.cellIdentifiers.count
    }
    
    static let cellIdentifiers = [
        "Query Header",
        "Query Cell",
        "Users Header",
        "User Cell",
        "Classes Header",
        "Class Cell",
        "Including Header",
        "Include Cell",
        "Excluding Header",
        "Exclude Cell",
        "Results Header",
        "Result Cell"
    ]

    var sizingCells = [UITableViewCell?](count: cellIdentifiers.count, repeatedValue: nil)
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        // if (indexPath.row != AddQueryViewController.cellIdentifiers.count - 1) {
        //    TODO: add a separator between adjacent non-header cells and after the last cell
        // }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(AddQueryViewController.cellIdentifiers[indexPath.row], forIndexPath: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if (sizingCells[indexPath.row] == nil) {
            sizingCells[indexPath.row] = tableView.dequeueReusableCellWithIdentifier(AddQueryViewController.cellIdentifiers[indexPath.row])
        }

        let sizingCell = sizingCells[indexPath.row]!
        configureCell(sizingCell, atIndexPath:indexPath)
        
        sizingCell.bounds = CGRectMake(0.0, 0.0, CGRectGetWidth(self.tableView.frame), CGRectGetHeight(sizingCell.bounds));
        sizingCell.setNeedsLayout()
        sizingCell.layoutIfNeeded()
        
        let size = sizingCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        var height = size.height
        
        // TODO: add a separator between adjacent non-header cells and after the last cell
        if (indexPath.row == AddQueryViewController.cellIdentifiers.count - 1) {
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
