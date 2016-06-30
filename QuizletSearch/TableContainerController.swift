//
//  TableContainerController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/17/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class TableContainerController: UIViewController, UITableViewDelegate, UIScrollViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    @IBInspectable var refreshing: Bool = false

    var refreshControl: UIRefreshControl!
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: nil)
    }

    // MARK: - Table view controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register for keyboard show and hide notifications, to adjust the table view when the keyboard is showing
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(TableContainerController.keyboardWillShow(_:)), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(TableContainerController.keyboardWillHide(_:)), name: UIKeyboardWillHideNotification, object: nil)
        
        if (refreshing) {
            // Initialize the refresh control -- this is necessary because we aren't using a UITableViewController.  Normally you would set "Refreshing" to "Enabled" on the table view controller.  So instead we are initializing it programatically.
            refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(TableContainerController.refreshTable), forControlEvents: UIControlEvents.ValueChanged)
            tableView.addSubview(refreshControl)
            tableView.sendSubviewToBack(refreshControl)
        }
    }
    
    // Implemented by subclasses
    func refreshTable() { }
    
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
    
    // The UITableViewController deselects the currently selected row when the table becomes visible.  We are not subclassing UITableViewController because we want to customize the view with additional elements, and the UITableViewController does not allow for this.
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let path = tableView.indexPathForSelectedRow {
            tableView.deselectRowAtIndexPath(path, animated: true)
        }
    }
    
    // The UITableViewController flashes the scrollbar when the table becomes visible.
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        tableView.flashScrollIndicators()
    }
    
    // The UITableViewController invokes setEditing when startEditing is called.
    func startEditing() {
        setEditing(true, animated: true)
    }
}
