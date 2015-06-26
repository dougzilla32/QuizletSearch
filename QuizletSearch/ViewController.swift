//
//  ViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/1/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit
import Foundation

let accessToken = "accessToken"
let accessTokenSecret = "accessTokenSecret"


class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    struct Query {
        var name: String
        var queryString: String
    }
    
    let dropboxSession = DropboxSession()
    let quizletSession = QuizletSession()
    
    var apisToCall = [
        Query(name: "London Weather", queryString: "http://api.openweathermap.org/data/2.5/weather?q=London,uk"),
        Query(name: "My Quizlet Sets", queryString: "https://api.quizlet.com/2.0/search/sets?creator=dougzilla32&client_id=ZwGccNSqZJ")
    ]

    var currentRow = 0
    
    @IBOutlet weak var picker: UIPickerView!
    
    @IBAction func buttonClicked(sender: UIButton) {
        println("Button pressed: \(apisToCall[currentRow].name)")
        
        var appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        println("\(appDelegate.managedObjectModel)")
        // UIApplication.sharedApplication().openURL(quizletSession.authorizeURL())
        
        // var client = QuizletRestClient(session: quizletSession)
        // client.getMicrosoftToken()
        
        // oauth2.googleTextToSpeech("the quick brown fox jumped over the lazy dog")
        // oauth2.googleTextToSpeech("안녕하세요")
        // oauth2.googleTextToSpeech("hello")

        // UIApplication.sharedApplication().openURL(dropboxSession.authorizeURL())
    }
    
    // returns the number of 'columns' to display.
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // returns the # of rows in each component..
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return apisToCall.count
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        return apisToCall[row].name
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        currentRow = row
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
