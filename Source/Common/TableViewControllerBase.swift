//
//  TableContainerController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/17/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class TableViewControllerBase: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    @IBInspectable var refreshing: Bool = false

    var refreshControl: UIRefreshControl!

    // MARK: - Table view controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (tableView != nil) {
            // Register for keyboard show and hide notifications, to adjust the table view when the keyboard is showing
            NotificationCenter.default.addObserver(self, selector: #selector(TableViewControllerBase.keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(TableViewControllerBase.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
            if (refreshing) {
                // Initialize the refresh control -- this is necessary because we aren't using a UITableViewController.  Normally you would set "Refreshing" to "Enabled" on the table view controller.  So instead we are initializing it programatically.
                refreshControl = UIRefreshControl()
                refreshControl.addTarget(self, action: #selector(TableViewControllerBase.refreshTable), for: UIControl.Event.valueChanged)
                tableView.addSubview(refreshControl)
                tableView.sendSubviewToBack(refreshControl)
            }
        }
        else {
            print("WARNING: TableViewControllerBase.tableView is nil for class \(type(of: self))")

        }
    }
    
    // Implemented by subclasses
    @objc func refreshTable() { }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            
            var contentInsets: UIEdgeInsets
            if (UIApplication.shared.statusBarOrientation.isPortrait) {
                contentInsets = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: keyboardSize.height, right: 0.0);
            } else {
                contentInsets = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: keyboardSize.width, right: 0.0);
            }
            
            self.tableView.contentInset = contentInsets;
            self.tableView.scrollIndicatorInsets = contentInsets;
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        self.tableView.contentInset = UIEdgeInsets.zero
        self.tableView.scrollIndicatorInsets = UIEdgeInsets.zero
    }
    
    // The UITableViewController deselects the currently selected row when the table becomes visible.  We are not subclassing UITableViewController because we want to customize the view with additional elements, and the UITableViewController does not allow for this.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let path = tableView?.indexPathForSelectedRow {
            tableView.deselectRow(at: path, animated: true)
        }
    }
    
    // The UITableViewController flashes the scrollbar when the table becomes visible.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        tableView?.flashScrollIndicators()
    }
    
    // The UITableViewController invokes setEditing when startEditing is called.
    func startEditing() {
        setEditing(true, animated: true)
    }
}
