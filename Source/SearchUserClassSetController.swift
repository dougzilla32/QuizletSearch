//
//  SearchUserClassSetController.swift
//  QuizletSearch
//
//  Created by Doug on 11/1/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import UIKit

class SearchUserClassSetController: TableViewControllerBase, UITableViewDelegate, UIScrollViewDelegate, UITableViewDataSource {

    let quizletSession = (UIApplication.shared.delegate as! AppDelegate).dataModel.quizletSession
    
    let universalSearch = UniversalSearch()
    
    @IBOutlet weak var segmentedControl: TwicketSegmentedControl!

    @IBOutlet weak var searchBar: UISearchBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Allow the user to dismiss the keyboard by touch-dragging down to the bottom of the screen
        tableView.keyboardDismissMode = .interactive

        // Respond to dynamic type font changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(SearchUserClassSetController.preferredContentSizeChanged(_:)),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
        resetFonts()
    }

    deinit {
        // Remove all 'self' observers
        NotificationCenter.default.removeObserver(self)
    }
    
    var preferredFont: UIFont!
    var preferredBoldFont: UIFont!
    var italicFont: UIFont!
    var smallerFont: UIFont!
    var estimatedHeightForUserCell: CGFloat?
    
    @objc func preferredContentSizeChanged(_ notification: Notification) {
        resetFonts()
        self.view.setNeedsLayout()
    }
    
    func resetFonts() {
        preferredFont = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
        preferredBoldFont = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
        
        let fontDescriptor = preferredFont.fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits.traitItalic)
        italicFont = UIFont(descriptor: fontDescriptor!, size: preferredFont.pointSize)
        
        smallerFont = UIFont(descriptor: preferredFont.fontDescriptor, size: preferredFont.pointSize - 4.0)
        
        estimatedHeightForUserCell = nil
        
        if (searchBar != nil) {
            let searchTextField = Common.findTextField(searchBar)!
            searchTextField.font = preferredFont
        }
    }

    override var shouldAutorotate : Bool {
        return true
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return .all
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
       // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        trace("prepareForSegue SearchUserClassSetController segue:", segue.identifier)
        
        // Cancel current queries
        quizletSession.cancelQueryTasks()
    }
    
    // MARK: - TwicketSegmentedControlDelegate

    @IBAction func segmentedControlValueChanged(_ sender: Any) {
        tableView.reloadData()
    }

    // MARK: - Search Bar
    
    // called when text starts editing
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
    }
    
    // called when text ends editing
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    }
    
    // called when text changes (including clear)
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        executeSearchForQuery(searchBar.text)
    }
    
    // Have the keyboard close when 'Return' is pressed
    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool // called before text changes
    {
        if (text == "\n") {
            // The user pressed 'Search'
            searchBar.resignFirstResponder()
        }
        return true
    }
    
    // MARK: - Search
    func executeSearchForQuery(_ query: String!) {
        let query = (query != nil) ? query.trimmingCharacters(in: CharacterSet.whitespaces) : nil
        universalSearch.updateQuery(query)
        executeSearch(0)
    }
    
    func executeSearch(indexPath: IndexPath) {
        executeSearch(indexPath.row)
    }
    
    func executeSearch() {
        executeSearch(0)
    }
    
    func executeSearch(_ pagerIndex: Int) {
        universalSearch.executeSearch(pagerIndex, completionHandler: { [unowned self] (affectedResults: CountableRange<Int>?, totalResults: Int?, response: PagerResponse) -> Void in
            
            DispatchQueue.main.async(execute: {
                self.tableView.reloadData()
            })
        })
        
        // Start the activity indicator
        tableView.reloadData()
    }
    
    // MARK: - Table view data source

    // Called after the user changes the selection.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return universalSearch.totalResults ?? (universalSearch.isLoading() ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCell.EditingStyle.insert) {
        }
    }
 
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifierForPath(indexPath), for: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    func cellIdentifierForPath(_ indexPath: IndexPath) -> String {
        guard let qitem = universalSearch.peekQItemForRow(indexPath.row) else {
            return "Activity Cell"
        }

        let id: String
        switch (qitem.type) {
        case .qUser:
            id = "User Cell"
        case .qClass:
            id = "Class Cell"
        case .qSet:
            id = "Study Set Cell"
        }
        return id
    }

    func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath) {
        let qitem = universalSearch.getQItemForRow(indexPath.row, completionHandler: { [unowned self] (affectedResults: CountableRange<Int>?, totalResults: Int?, response: PagerResponse) -> Void in
                DispatchQueue.main.async(execute: {
                    self.tableView.reloadData()
                })
            })
    
        configureCell(cell, atIndexPath: indexPath, qitem: qitem)
    }
    
    func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath, qitem: QItem!) {
        if (qitem == nil) {
            let activityCell = cell as! ActivityCell
            universalSearch.isLoading() ? activityCell.activityIndicator.startAnimating() : activityCell.activityIndicator.stopAnimating()
        }
        else {
            switch (qitem.type) {
            case .qUser:
                let qUser = qitem as! QUser
                let userCell = cell as! UserCell
                userCell.usernameLabel.text = qUser.userName
                userCell.usernameLabel.font = preferredFont
                if (qitem?.type == .qUser && (qitem as! QUser).userName.isEmpty) {
                    // Empty item
                    cell.isHidden = true
                }
                else {
                    cell.isHidden = (segmentedControl.selectedSegmentIndex != 0)
                }
            case .qClass:
                let qClass = qitem as! QClass
                let classCell = cell as! ClassCell
                classCell.classLabel.text = qClass.name
                classCell.classLabel.font = preferredFont
                if let school = qClass.school {
                    var text = ""
                    var sep = ""
                    if (!school.name.isEmpty) {
                        text += school.name
                        sep = " · "
                    }
                    if (!school.city.isEmpty && !school.state.isEmpty) {
                        text += "\(sep)\(school.city), \(school.state)"
                    }
                    else if (!school.city.isEmpty) {
                        text += "\(sep)\(school.city)"
                    }
                    else if (!school.state.isEmpty) {
                        text += "\(sep)\(school.state)"
                    }
                    
                    classCell.usernameLabel.text = text
                }
                classCell.usernameLabel.font = smallerFont

                cell.isHidden = (segmentedControl.selectedSegmentIndex != 1)
            case .qSet:
                let qSet = qitem as! QSet
                let studySetCell = cell as! StudySetCell
                if let termCount = qSet.termCount {
                    studySetCell.termsLabel.text = "\(termCount) terms"
                    studySetCell.termsLabel.font = smallerFont
                }
                studySetCell.usernameLabel.text = qSet.createdBy
                studySetCell.usernameLabel.font = smallerFont
                studySetCell.studySetLabel.text = qSet.title
                studySetCell.studySetLabel.font = preferredFont

                cell.isHidden = (segmentedControl.selectedSegmentIndex != 2)
            }
        }
    }
    
    /*
    func loadImage() {
        if let img: UIImage = UIImage(data: previewImg[indexPath.row]) {
            cell.cardPreview.image = img
        } else {
            // The image isn't cached, download the img data
            // We should perform this in a background thread
            let imgURL = NSURL(string: "webLink URL")
            let request: NSURLRequest = NSURLRequest(URL: imgURL!)
            let session = NSURLSession.sharedSession()
            let task = session.dataTask(withRequest: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
                let error = error
                let data = data
                if error == nil {
                    // Convert the downloaded data in to a UIImage object
                    let image = UIImage(data: data!)
                    // Store the image in to our cache
                    self.previewImg[indexPath.row] = data!
                    // Update the cell
                    dispatch_async(dispatch_get_main_queue(), {
                        if let cell: YourTableViewCell = tableView.cellForRowAtIndexPath(indexPath) as? YourTableViewCell {
                            cell.cardPreview.image = image
                        }
                    })
                } else {
                    cell.cardPreview.image = UIImage(named: "defaultImage")
                }
            })
            task.resume()
        }
        
        
        let urlString = "http://www.foo.com/myImage.jpg"
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if error != nil {
                print("Failed fetching image:", error)
                return
            }
            
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                print("Not a proper HTTPURLResponse or statusCode")
                return
            }
            
            DispatchQueue.main.async {
                self.myImageView.image = UIImage(data: data!)
            }
            }.resume()
    }
    */

    var sizingCells: [String: UITableViewCell] = [:]
    
    /**
     * This method should make dynamically sizing table view cells work with iOS 7.  I have not
     * been able to test this because Xcode 7 does not support the iOS 7 simulator.
     */
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellIdentifier = cellIdentifierForPath(indexPath)
        var cell = sizingCells[cellIdentifier]
        if (cell == nil) {
            cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
            sizingCells[cellIdentifier] = cell!
        }
        
        let qitem = universalSearch.peekQItemForRow(indexPath.row)
        if (qitem?.type == .qUser && (qitem as! QUser).userName.isEmpty) {
            // Empty item
            return 0.0
        }
        
        if (qitem?.type == .qUser && segmentedControl.selectedSegmentIndex != 0
            || qitem?.type == .qClass && segmentedControl.selectedSegmentIndex != 1
            || qitem?.type == .qSet && segmentedControl.selectedSegmentIndex != 2) {
            return 0.0
        }
        
        configureCell(cell!, atIndexPath: indexPath, qitem: qitem)
        return calculateHeight(cell!)
    }
 
    func calculateHeight(_ cell: UITableViewCell) -> CGFloat {
        cell.bounds = CGRect(x: 0.0, y: 0.0, width: self.tableView.frame.width, height: cell.bounds.height)
        
        // Workaround: setting the bounds for multi-line DynamicLabel instances will cause the preferredMaxLayoutWidth to be set corretly when layoutIfNeeded() is called
        if let reset = cell as? ResettableBounds {
            reset.resetBounds()
        }
     
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        
        let height = cell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        return height + 1.0 // Add 1.0 for the cell separator height
    }
    
    func tableView(_ tableView: UITableView,
                   estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
//        if (true) {
//            return 44.0
//        }
        let height: CGFloat
        
        if (estimatedHeightForUserCell == nil) {
            let cellIdentifier = "User Cell"
            var sizingCell = sizingCells[cellIdentifier]
            if (sizingCell == nil) {
                sizingCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
                sizingCells[cellIdentifier] = sizingCell!
            }
            
            let qitem = QUser(userName: "User", accountType: .free, profileImage: URL(string: "https://quizlet.com/a/i/animals/1.X54Z.jpg")!, signUpDate: 0)
            configureCell(sizingCell!, atIndexPath: indexPath, qitem: qitem)
            estimatedHeightForUserCell = calculateHeight(sizingCell!)
        }
        height = estimatedHeightForUserCell!
        
        return height
    }
}
