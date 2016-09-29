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
    
    @IBAction func proceedAsGuest(_ sender: AnyObject) {
        
        var alertController:UIAlertController?
        alertController = UIAlertController(title: "Guest",
            message: "Enter the user name to search as guest",
            preferredStyle: .alert)
        
        alertController!.addTextField(
            configurationHandler: {(textField: UITextField) in
                textField.placeholder = "Username"
        })
        
        let proceed = UIAlertAction(title: "Proceed",
            style: UIAlertActionStyle.default,
            handler: {
                (paramAction:UIAlertAction!) in
                if let textFields = alertController?.textFields {
                    let theTextFields = textFields
                    let enteredText = theTextFields[0].text
                    (UIApplication.shared.delegate as! AppDelegate).proceedAsGuest(enteredText)
                }
        })
        
        let cancel = UIAlertAction(title: "Cancel",
            style: UIAlertActionStyle.default,
            handler: {
                (paramAction:UIAlertAction!) in
            })
        
        alertController?.addAction(proceed)
        alertController?.addAction(cancel)
        
        self.present(alertController!,
            animated: true,
            completion: nil)
    }

    @IBAction func loginAction(_ sender: UIButton) {
        let appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        UIApplication.shared.openURL(appDelegate.quizletSession.authorizeURL() as URL)
    }
    
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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

