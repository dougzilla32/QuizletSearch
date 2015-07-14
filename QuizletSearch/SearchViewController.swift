//
//  SearchViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/29/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit
import Foundation

class SearchViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var sortStyle: UISegmentedControl!

    var termsAtoZ: [Term] = []
    
    var termsBySet: [(String, [Term])] = []
    
    @IBAction func unwindToList(segue: UIStoryboardSegue) {
    }
    
    @IBAction func sortStyleChanged(sender: AnyObject) {
        // TODO: check to make sure this is the correct way to reload the table
        tableView.reloadData()
    }
    
    func isAtoZ() -> Bool {
        return sortStyle.selectedSegmentIndex == 0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        refreshTerms()
    }
    
    func refreshTerms() {
        let dataModel = (UIApplication.sharedApplication().delegate as! AppDelegate).dataModel
        
        termsAtoZ = []
        termsBySet = []
        
        if let filter = dataModel.currentUser?.currentFilter {
            for set  in filter.sets {
                var quizletSet = set as! QuizletSet
                var termsForSet = [Term]()
                
                for term in quizletSet.terms {
                    var term = (term as! Term)
                    termsAtoZ.append(term)
                    termsForSet.append(term)
                }
                
                sort(&termsForSet, termComparator)
                
                // TODO: remove this workaround for bug with appending to an array of tuples
                // termsBySet!.append((quizletSet.title, termsForSet))
                termsBySet += [(quizletSet.title, termsForSet)]
            }
            
            sort(&termsAtoZ, termComparator)
            
            sort(&termsBySet, { (s1: (String, [Term]), s2: (String, [Term])) -> Bool in
                return s1.0 < s2.0
            })
            
            println("SORT TERMS")
        }
    }
    
    func termComparator(t1: Term, t2: Term) -> Bool {
        switch (t1.term.compare(t2.term)) {
        case .OrderedAscending:
            return true
        case .OrderedDescending:
            return false
        case .OrderedSame:
            return t1.definition < t2.definition
        }
    }
    
    // MARK: - Table view controller
    override func viewWillAppear(animated: Bool) {
        if let path = tableView.indexPathForSelectedRow() {
            tableView.deselectRowAtIndexPath(path, animated: true)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        tableView.flashScrollIndicators()
    }
    
    func startEditing() {
        setEditing(true, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return isAtoZ() ? 1 : termsBySet.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return isAtoZ() ? termsAtoZ.count : termsBySet[section].1.count
    }

    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // fixed font style. use custom view (UILabel) if you want something different
        return isAtoZ() ? nil : termsBySet[section].0
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("termAndDefinition", forIndexPath: indexPath) as! UITableViewCell
        
        var term: Term
        if (isAtoZ()) {
            term = termsAtoZ[indexPath.row]
        } else {
            term = termsBySet[indexPath.section].1[indexPath.row]
        }
        cell.textLabel!.text = "\(term.term)\n\(term.definition)"
        cell.textLabel!.lineBreakMode = .ByWordWrapping
        cell.textLabel!.numberOfLines = 0
        
        var hasImage = false || false
        if (hasImage) {
            cell.accessoryView = UIImageView(image: nil)
        }
    
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        var term: Term
        if (isAtoZ()) {
            term = termsAtoZ[indexPath.row]
        } else {
            term = termsBySet[indexPath.section].1[indexPath.row]
        }

        var text = "\(term.term)\n\(term.definition)"
        // TODO: change to get proper width from table
        var width = CGFloat(200)
        var font = UIFont.boldSystemFontOfSize(14.0)

        var attributedText = NSAttributedString(string: text, attributes: [NSFontAttributeName: font])
        var rect = attributedText.boundingRectWithSize(CGSizeMake(width, CGFloat.max),
            options: NSStringDrawingOptions.UsesLineFragmentOrigin,
            context: nil)
        var size = rect.size
        
        return size.height + 10
    }

    /*
    Basically, to add sections and an index list in the UITableView, you need to deal with these methods as defined in UITableViewDataSource protocol:

    numberOfSectionsInTableView: method – returns the total number of sections in the table view. Usually we set the number of section to 1. If you want to have multiple sections, set this value to a larger number.
    
    titleForHeaderInSection: method – returns the header titles for different sections. This method is optional if you do not assign titles for the section.
    
    numberOfRowsInSection: method – returns the total number of rows in a specific section
    
    cellForRowAtIndexPath: method – this method shouldn’t be new to you if you know how to display data in UITableView. It returns the table data for a particular section.
    
    sectionIndexTitlesForTableView: method – returns the indexed titles that appear in the index list on the right side of the table view. For example, you can return an array of strings containing “A” to “Z”.
    
    sectionForSectionIndexTitle: method – returns the section index that the table view should jump to when user taps a particular index.
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    // Return NO if you do not want the specified item to be editable.
    return true
    }
    */
    
    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete {
    // Delete the row from the data source
    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    } else if editingStyle == .Insert {
    // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
    }
    */
    
    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
    
    }
    */
    
    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    // Return NO if you do not want the item to be re-orderable.
    return true
    }
    */
    
    /*
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    }
    */
    
}

