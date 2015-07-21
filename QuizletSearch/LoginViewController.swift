//
//  LoginViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/29/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit
import Foundation

class LoginViewController: UIViewController {
    
    @IBAction func loginAction(sender: UIButton) {
        var appDelegate = (UIApplication.sharedApplication().delegate as! AppDelegate)
        UIApplication.sharedApplication().openURL(appDelegate.quizletSession.authorizeURL())
    }

    override func loadView() {
        super.loadView()
        (UIApplication.sharedApplication().delegate as! AppDelegate).cancelRefreshTimer()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

