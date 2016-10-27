//
//  UsersViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/29/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit
import Foundation

class UsersTableViewController: UITableViewController {

    override var shouldAutorotate : Bool {
        return true
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return .all
    }

    override func loadView() {
        super.loadView()
        (UIApplication.shared.delegate as! AppDelegate).cancelRefreshTimer()
    }

    override func viewWillAppear(_ animated: Bool) {
        UIView.setAnimationsEnabled(false)
        navigationController?.setNavigationBarHidden(false, animated: false)
        UIView.setAnimationsEnabled(true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Potentially incomplete method implementation.
        // Return the number of sections.
        return 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete method implementation.
        // Return the number of rows in the section.
        return 0
    }

    func hideKeyboard(_ recognizer: UITapGestureRecognizer) {
        // currentFirstResponder?.target.resignFirstResponder()
    }
}

