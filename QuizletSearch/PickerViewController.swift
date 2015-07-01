//
//  PickerViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/1/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit
import Foundation
import CoreData

class PickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    struct Query {
        var name: String
        var queryString: String
    }
    
    var users = [User]()
    
    var apisToCall = [
        Query(name: "London Weather", queryString: "http://api.openweathermap.org/data/2.5/weather?q=London,uk"),
        Query(name: "My Quizlet Sets", queryString: "https://api.quizlet.com/2.0/search/sets?creator=dougzilla32&client_id=ZwGccNSqZJ")
    ]

    var currentRow = 0
    
    @IBOutlet weak var picker: UIPickerView!
    
    @IBAction func buttonClicked(sender: UIButton) {
        println("Button pressed: \(apisToCall[currentRow].name)")
        
        fetchUsers()
        createUserWithName("doug", id: "123")
        createUserWithName("jun", id: "456")
        createUserWithName("marla", id: "789")
        createUserWithName("david", id: "1234")
        createUserWithName("karen", id: "5678")
        
        // UIApplication.sharedApplication().openURL(quizletSession.authorizeURL())
        
        // var client = QuizletRestClient(session: quizletSession)
        // client.getMicrosoftToken()
        
        // oauth2.googleTextToSpeech("the quick brown fox jumped over the lazy dog")
        // oauth2.googleTextToSpeech("안녕하세요")
        // oauth2.googleTextToSpeech("hello")

        // UIApplication.sharedApplication().openURL(dropboxSession.authorizeURL())
    }
    
    func fetchUsers() {
        let moc = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext!
        let fetchRequest = NSFetchRequest(entityName: "User")
        
        var error: NSError?
        let users = moc.executeFetchRequest(fetchRequest, error: &error) as? [User]
        if (users == nil) {
            NSLog("An error occurred while fetching the list of users: \(error), \(error?.userInfo)")
        }
        
        self.users = users!
    }
    
    func createUserWithName(name: String, id: String) {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = appDelegate.managedObjectContext!
        
        let entity =  NSEntityDescription.entityForName("User", inManagedObjectContext: moc)!
        let user = User(entity: entity, insertIntoManagedObjectContext: moc)
        user.name = name
        user.id = id
        
        var error: NSError?
        if !moc.save(&error) {
            NSLog("An error occurred while saving the data model: \(error), \(error?.userInfo)")
            return
        }  

        users.append(user)
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
