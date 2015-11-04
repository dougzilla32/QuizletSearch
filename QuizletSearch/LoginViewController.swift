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
    
    @IBAction func proceedAsGuest(sender: AnyObject) {
        
        var alertController:UIAlertController?
        alertController = UIAlertController(title: "Guest",
            message: "Enter the user name to search as guest",
            preferredStyle: .Alert)
        
        alertController!.addTextFieldWithConfigurationHandler(
            {(textField: UITextField) in
                textField.placeholder = "Username"
        })
        
        let proceed = UIAlertAction(title: "Proceed",
            style: UIAlertActionStyle.Default,
            handler: {
                (paramAction:UIAlertAction!) in
                if let textFields = alertController?.textFields {
                    let theTextFields = textFields
                    let enteredText = theTextFields[0].text
                    (UIApplication.sharedApplication().delegate as! AppDelegate).proceedAsGuest(enteredText)
                }
        })
        
        let cancel = UIAlertAction(title: "Cancel",
            style: UIAlertActionStyle.Default,
            handler: {
                (paramAction:UIAlertAction!) in
            })
        
        alertController?.addAction(proceed)
        alertController?.addAction(cancel)
        
        self.presentViewController(alertController!,
            animated: true,
            completion: nil)
    }

    @IBAction func loginAction(sender: UIButton) {
        let appDelegate = (UIApplication.sharedApplication().delegate as! AppDelegate)
        UIApplication.sharedApplication().openURL(appDelegate.quizletSession.authorizeURL())
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .All
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

