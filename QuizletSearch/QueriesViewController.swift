//
//  QueryViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/17/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class QueriesViewController: TableContainerController {

    // MARK: - View Controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // tableView.rowHeight = UITableViewAutomaticDimension
        // tableView.estimatedRowHeight = 44.0
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.All
    }
    
    // MARK: - Table view data source

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("My label", forIndexPath: indexPath) as! LabelTableViewCell
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    func configureCell(cell: LabelTableViewCell, atIndexPath indexPath: NSIndexPath) {
        let text = "Sets created by: dougzilla32"
        cell.label.text = text
        // cell.label.font = preferredSearchFont
    }
    
    lazy var sizingCell: LabelTableViewCell = {
        return self.tableView.dequeueReusableCellWithIdentifier("My label") as! LabelTableViewCell
    }()
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        configureCell(sizingCell, atIndexPath:indexPath)
        return calculateHeight(sizingCell)
    }
    
    func calculateHeight(cell: UITableViewCell) -> CGFloat {
        cell.bounds = CGRectMake(0.0, 0.0, CGRectGetWidth(self.tableView.frame), CGRectGetHeight(sizingCell.bounds));
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
