//
//  AddQueryViewController.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/17/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


let QuerySection = 0
let ResultsSection = 1

class AddQueryViewController: UITableViewController, UISearchBarDelegate, UITextFieldDelegate {
    enum ScrollTarget: Int {
        case none, userHeader, classHeader, resultsHeader
        
        static let RowType: [QueryRowType?] = [nil, .userHeader, .classHeader, .resultHeader]
    }
    
    let MaxDescriptionLength = 350
    
    let quizletSession = (UIApplication.shared.delegate as! AppDelegate).dataModel.quizletSession
    var model: AddQueryModel!
    var keyboardHeight: CGFloat = 0.0
    
    var queryToLoad: Query?
    
    @IBOutlet var addButton: UIBarButtonItem!
    @IBOutlet var cancelAddQuery: UIBarButtonItem!

    @IBOutlet var saveButton: UIBarButtonItem!
    @IBOutlet var cancelEditQuery: UIBarButtonItem!
    
    @IBOutlet weak var findSetsLabel: UILabel!

    // MARK: - View Controller
    
    override func viewWillAppear(_ animated: Bool) {
        addButton.setTitleTextAttributes(
            [ NSFontAttributeName: UIFont.boldSystemFont(ofSize: 17.0) ],
            for: UIControlState())

//        navigationController!.setNavigationBarHidden(false, animated: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable selections in the table
        tableView.allowsSelection = false
        
        // Allow the user to dismiss the keyboard by touch-dragging down to the bottom of the screen
        tableView.keyboardDismissMode = .interactive
        
        // Respond to dynamic type font changes
        NotificationCenter.default.addObserver(self,
            selector: #selector(AddQueryViewController.preferredContentSizeChanged(_:)),
            name: NSNotification.Name.UIContentSizeCategoryDidChange,
            object: nil)
        resetFonts()
        
        // Register for keyboard show and hide notifications, to adjust the table view when the keyboard is showing
        NotificationCenter.default.addObserver(self, selector: #selector(AddQueryViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AddQueryViewController.keyboardDidHide(_:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)

        // Delay "touches began" so that swipe to delete for textfield cells works properly
        self.tableView.panGestureRecognizer.delaysTouchesBegan = true
        
//        self.navigationController!.navigationBar.titleTextAttributes =
//            [NSFontAttributeName: UIFont(name: "Noteworthy-Bold", size: 18)!]
        
        model = AddQueryModel()
        model.loadFromQuery(queryToLoad)
        queryToLoad = nil
        model.reloadData()
        
        executeSearch()
    }
    
    deinit {
        // Remove all 'self' observers
        NotificationCenter.default.removeObserver(self)
        
        addButton = nil
        cancelAddQuery = nil
        
        saveButton = nil
        cancelEditQuery = nil
    }
    
    var preferredFont: UIFont!
    var preferredBoldFont: UIFont!
    var italicFont: UIFont!
    var smallerFont: UIFont!
    var estimatedHeightForSearchAssistCell: CGFloat?
    var estimatedHeightForResultCell: CGFloat?
    
    func preferredContentSizeChanged(_ notification: Notification) {
        resetFonts()
        self.view.setNeedsLayout()
    }
    
    func resetFonts() {
        preferredFont = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        preferredBoldFont = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
        
        let fontDescriptor = preferredFont.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits.traitItalic)
        italicFont = UIFont(descriptor: fontDescriptor!, size: preferredFont.pointSize)
        
        smallerFont = UIFont(descriptor: preferredFont.fontDescriptor, size: preferredFont.pointSize - 3.0)
        
        estimatedHeightForSearchAssistCell = nil
        estimatedHeightForResultCell = nil
        
        findSetsLabel.font = preferredFont
        if (searchBar != nil) {
            let searchTextField = Common.findTextField(searchBar)!
            searchTextField.font = preferredFont
        }
    }
    
    func configureForAdd() {
        self.navigationItem.leftBarButtonItems = [cancelAddQuery]
        self.navigationItem.rightBarButtonItems = [addButton]
    }
    
    func configureForSave(_ queryToLoad: Query) {
        self.navigationItem.leftBarButtonItems = [cancelEditQuery]
        self.navigationItem.rightBarButtonItems = [saveButton]
        self.queryToLoad = queryToLoad
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
    
    func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardHeight = keyboardSize.height
        }
    }
    
    func keyboardDidHide(_ notification: Notification) {
        keyboardHeight = 0
//        ensureLastRowIsVisible()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        trace("prepareForSegue AddQueryViewController segue:", segue.identifier, "sender:", (sender as! UIBarButtonItem).title)
        
        // Cancel current queries
        quizletSession.cancelQueryTasks()
    }
    
    @discardableResult
    func saveToQuery(_ query: Query) -> Bool {
        return model.saveToQuery(query)
    }

    // MARK: - Search Bar
    
    var searchBar: UISearchBar!
    
    // called when text starts editing
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
    }
    
    // called when text ends editing
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    }
    
    // called when text changes (including clear)
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        executeSearchForQuery(searchBar.text, scrollTarget: .resultsHeader)
    }
    
    // Have the keyboard close when 'Return' is pressed
    func searchBar(_ searchBar: UISearchBar, range: NSRange, replacementText text: String) -> Bool
    {
        if (text == "\n") {
            // The user pressed 'Search'
            searchBar.resignFirstResponder()
        }
        return true
    }
    
    // MARK: - Search
    
    func executeSearchForQuery(_ queryOpt: String?, scrollTarget: ScrollTarget) {
        var query = (queryOpt != nil) ? queryOpt! : ""
        query = query.trimmingCharacters(in: CharacterSet.whitespaces)
        
        if (model.pagers.queryPager == nil && !query.isEmpty) {
            model.pagers.queryPager = SetPager(query: query)
        }
        else {
            model.pagers.queryPager?.reset(query: query)
        }
        
        executeSearch(PagerIndex(type: .query, index: 0), scrollTarget: scrollTarget)
    }
    
    func executeSearch(indexPath: IndexPath?, scrollTarget: ScrollTarget) {
        executeSearch(model.indexPathToPagerIndex(indexPath), scrollTarget: scrollTarget)
    }
    
    func executeSearch() {
        executeSearch(PagerIndex(type: .query, index: 0), scrollTarget: nil)
    }
    
    func executeSearch(_ pagerIndex: PagerIndex?, scrollTarget: ScrollTarget?) {
        var firstLoaded = true
        
        model.pagers.executeSearch(pagerIndex, completionHandler: { (affectedResults: CountableRange<Int>?, totalResults: Int?, response: PagerResponse) -> Void in
            
            self.safelyReloadData(affectedResults: affectedResults, totalResults: totalResults)
            if (scrollTarget != nil && firstLoaded && totalResults > 0) {
                self.scrollTo(scrollTarget!)
                firstLoaded = false
            }
        })

        // Start the activity indicator
        let path = model.pathForResultHeader()
        let cell = tableView.cellForRow(at: path as IndexPath)
        if (cell != nil) {
            configureCell(cell!, atIndexPath: path as IndexPath)
        }
    }
    
    var prevTotalResults = 0
    var prevTotalResultsHighWaterMark = 0
    
    // Workaround for a UITableView bug where it will crash when reloadData is called on the table if the search bar currently has the keyboard focus
    func safelyReloadData(affectedResults affected: CountableRange<Int>?, totalResults total: Int?) {
        trace("safelyReload: totalResults=", total, " prevTotalResults=", prevTotalResults, /* "totalResultRows=", model.pagers.totalResultRows, */ " prevTotalResultsHighWaterMark=", prevTotalResultsHighWaterMark, separator: "")

        let offset = model.rowTypes[ResultsSection].count
        
        let affectedResults = (affected != nil) ? affected! : 0..<0
        let totalResults = (total != nil) ? total! : 0

        let totalResultsHighWaterMark = (model.pagers.totalResultsHighWaterMark != nil) ? model.pagers.totalResultsHighWaterMark! : 0
        
        trace("affectedResults", affectedResults)
        for i in affectedResults {
            if (i >= prevTotalResultsHighWaterMark) {
                break
            }
            let path = IndexPath(row: i + offset, section: ResultsSection)
            let cell = tableView.cellForRow(at: path)
            if (cell != nil) {
                configureCell(cell!, atIndexPath: path)
            }
        }
        
        var didInsert = false
        
        if (totalResultsHighWaterMark > prevTotalResultsHighWaterMark) {
            var indexPaths = [IndexPath]()
            for i in prevTotalResultsHighWaterMark..<totalResultsHighWaterMark {
                let path = IndexPath(row: i + offset, section: ResultsSection)
                indexPaths.append(path)
            }
            
            UIView.setAnimationsEnabled(false)
            trace("BEGIN numRows=", model.numberOfRowsInSection(ResultsSection), separator: "")
            trace("insertRows", totalResults-prevTotalResults)
            tableView.insertRows(at: indexPaths, with: UITableViewRowAnimation.none)
            trace("END numRows=", model.numberOfRowsInSection(ResultsSection), separator: "")
            UIView.setAnimationsEnabled(true)
            didInsert = true
        }
        else if (totalResults < prevTotalResults) {
            for i in totalResults..<prevTotalResults {
                let path = IndexPath(row: i + offset, section: ResultsSection)
                let cell = tableView.cellForRow(at: path)
                if (cell != nil) {
                    configureCell(cell!, atIndexPath: path)
                }
            }
            trace("deleteRows", prevTotalResults-totalResults)
        }
        
        let path = model.pathForResultHeader()
        let cell = tableView.cellForRow(at: path as IndexPath)
        if (cell != nil) {
            configureCell(cell!, atIndexPath: path as IndexPath)
        }
        
        if (!didInsert) {
            // Trick the table into re-fetching the heights for the currently visible rows
            UIView.setAnimationsEnabled(false)
            let indexPath = IndexPath(row: 0, section: 0)
            tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.none)
            UIView.setAnimationsEnabled(true)
        }

        prevTotalResults = totalResults
        prevTotalResultsHighWaterMark = totalResultsHighWaterMark
        
        ensureLastRowIsVisible()
    }
    
    // MARK: - Editable cells
    
    struct TargetAndPath {
        let target: UITextField
        let path: IndexPath
    }
    
    // The currently active textfield (either username or class), restore the first responder textfield after reloadData is called on the table
    var currentFirstResponder: TargetAndPath?
    
    struct PathAndRange {
        let path: IndexPath
        let range: UITextRange?
    }
    
    // Gives the newly added textfield the keyboard focus (it becomes the first responder when 'cellForRowAtIndexPath' is called with the firstResponderIndexPath index path)
    var desiredFirstResponder: PathAndRange?
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        trace("didBeginEditing", textField.text)
        currentFirstResponder = TargetAndPath(target: textField, path: indexPathForTextField(textField))
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        trace("didEndEditing", textField.text)
        var indexPath = indexPathForTextField(textField)
        if (desiredFirstResponder?.path == indexPath) {
            // Do not update if textFieldDidEndEditing is called while reloading the table
            trace("Ignore update")
            return
        }

        currentFirstResponder = nil

        let text = textField.text?.trimWhitespace()

        switch (model.rowTypeForPath(indexPath)) {
        case .userCell:
            if (text == nil || text!.isEmpty) {
                deleteUserAtIndexPath(indexPath)
                trace("Delete user: '", text, "' ", indexPath.row, separator: "")
            }
            else {
                let newIndexPath = model.updateAndSortUser(text, atIndexPath: indexPath)
                trace("Update user: '", text, "' ", indexPath.row, " ", newIndexPath.row, separator: "")
                if (newIndexPath != indexPath) {
                    self.tableView.moveRow(at: indexPath, to: newIndexPath)
                    indexPath = newIndexPath
                }
            }

        case .classCell:
            if (text == nil || text!.isEmpty) {
                deleteClassAtIndexPath(indexPath)
                trace("Delete class: '", text, "' ", indexPath.row, separator: "")
            }
            else {
                let newIndexPath = model.updateAndSortClass(text, atIndexPath: indexPath)
                trace("Update class: '", text, "' ", indexPath.row, " ", newIndexPath.row, separator: "")
                if (newIndexPath != indexPath) {
                    self.tableView.moveRow(at: indexPath, to: newIndexPath)
                    indexPath = newIndexPath
                }
            }
            
        default:
            abort()
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (string == "\n") {
            return true
        }
        
        var text = textField.text ?? ""
        text = (text as NSString).replacingCharacters(in: range, with: string)
        text = text.trimWhitespace()

        let indexPath = indexPathForTextField(textField)

        switch (model.rowTypeForPath(indexPath)) {
        case .userCell:
            model.updateUser(text, atIndexPath: indexPath)
            executeSearch(indexPath: indexPath, scrollTarget: .userHeader)
        case .classCell:
            model.updateClass(text, atIndexPath: indexPath)
            executeSearch(indexPath: indexPath, scrollTarget: .classHeader)
        default:
            abort()
        }
        
        return true
    }
    
    @IBAction func updateText(_ sender: AnyObject) {
        let textField = sender as! UITextField
        textField.resignFirstResponder()
    }

    func indexPathForTextField(_ textField: UITextField) -> IndexPath {
        let textInputCell = textField.superview!.superview as! TextInputTableViewCell

        // Use indexPathForRowAtPoint rather than indexPathForCell because indexPathForCell returns nil if the cell is not yet visible (either scrolled off or not yet realized)
        return tableView.indexPathForRow(at: textInputCell.center)!
    }
    
    @IBAction func addUser(_ sender: AnyObject) {
        if (searchBar.isFirstResponder) {
            searchBar.resignFirstResponder()
        }
        if (currentFirstResponder != nil) {
            if (currentFirstResponder!.path == model.topmostPathForType(QueryRowType.userCell) && currentFirstResponder!.target.text == "") {
                // There is already an empty user input textfield as first responder, so simply return
                return
            }
            trace("Resign first responder", currentFirstResponder!.target.text)
        }
        currentFirstResponder?.target.resignFirstResponder()

        let indexPath = self.model.insertNewUser("")
        desiredFirstResponder = PathAndRange(path: indexPath, range: nil)
        
        trace("Insert new empty user before")
        tableView.insertRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
        trace("Insert new empty user after")

        // Do not call executeSearch -- adding an empty user does not cause the results to change
        // executeSearch(indexPath: indexPath, scrollTarget: .UserHeader)
    }
    
    func deleteUserAtIndexPath(_ indexPath: IndexPath) {
        model.deleteAtIndexPath(indexPath)
        self.tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)

        // Delete the pager after deleting the rows in the tableView so that the row heights are not disrupted
        model.deleteUsernamePagerAtIndexPath(indexPath)
    }
    
    @IBAction func addClass(_ sender: AnyObject) {
        if (searchBar.isFirstResponder) {
            searchBar.resignFirstResponder()
        }
        if (currentFirstResponder != nil) {
            if (currentFirstResponder!.path == model.topmostPathForType(QueryRowType.classCell) && currentFirstResponder!.target.text == "") {
                // There is already an empty class input textfield as first responder, so simply return
                return
            }
            trace("Resign first responder", currentFirstResponder!.target.text)
        }
        currentFirstResponder?.target.resignFirstResponder()
        
        let indexPath = model.insertNewClass("669401")
        desiredFirstResponder = PathAndRange(path: indexPath, range: nil)
        
        trace("Insert new class before")
        tableView.insertRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
        trace("Insert new class after")
        
        executeSearch(indexPath: indexPath, scrollTarget: .classHeader)
    }
    
    func deleteClassAtIndexPath(_ indexPath: IndexPath) {
        model.deleteAtIndexPath(indexPath)
        self.tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)

        // Delete the pager after deleting the rows in the tableView so that the row heights are not disrupted
        model.deleteClassPagerAtIndexPath(indexPath)
    }
    
    // MARK: - Scroll view data source
    
    var fingerIsDown = false
    
    // called on start of dragging (may require some time and or distance to move)
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        fingerIsDown = true
    }

    // called on finger up if the user dragged. velocity is in points/millisecond. targetContentOffset may be changed to adjust where the scroll view comes to rest
    override func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        fingerIsDown = false
    }

    // called on finger up if the user dragged. decelerate is true if it will continue moving afterwards
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        enforceMaxYForScrollView(scrollView, delay: 0.01, animated: true)
    }
    
    var previousTableViewYOffset: CGFloat = 0.0
    var disableViewDidScroll = 0
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let scrollSpeed = tableView.contentOffset.y - previousTableViewYOffset
        previousTableViewYOffset = tableView.contentOffset.y
        
//        trace("scrollViewDidScroll", scrollView.contentOffset.y, scrollSpeed, fingerIsDown, disableViewDidScroll)
        if (scrollSpeed < 0) {
            return
        }
        
        if (disableViewDidScroll == 0) {
            disableViewDidScroll += 1
//            trace("increment #1 disableViewDidScroll", disableViewDidScroll)
            defer {
//                trace("decrement #1 disableViewDidScroll", disableViewDidScroll)
                disableViewDidScroll -= 1
            }
            
            if (!fingerIsDown) {
                enforceMaxYForScrollView(scrollView, delay: 0.1, animated: true)
            }
        }
    }
    
    func ensureLastRowIsVisible() {
        if (!fingerIsDown) {
            enforceMaxYForScrollView(tableView, delay: 0.0, animated: false)
        }
    }
    
    func enforceMaxYForScrollView(_ scrollView: UIScrollView, delay: Double, animated: Bool) {
        // Note: the 'delay' parameter simulates the first part of the bounce by allowing the scroll view to continue scrolling 'down' for a moment before starting the 'up' animation
        let resultHeaderPath = model.pathForResultHeader()
        let resultHeaderMinY = tableView.rectForRow(at: resultHeaderPath as IndexPath).minY
        let searchBarHeight = tableView.rectForHeader(inSection: ResultsSection).height

        let lastRowPath = IndexPath(row: model.numberOfResultRows() - 1, section: ResultsSection)
        let lastRowMaxY = tableView.rectForRow(at: lastRowPath).maxY
        
        let scrollToIndexPath: IndexPath
        let maxY: CGFloat
        let scrollToY: CGFloat
        
//        trace("enforceMaxYForScrollView", lastRowMaxY, resultHeaderMinY + scrollView.frame.height - searchBarHeight, resultHeaderMinY, scrollView.frame.height, searchBarHeight)

        // If the scrolling area is tall, potentially scroll to the last row (at bottom).  If the scrolling area is short,  potentially scroll to the result header (at top).
        if (lastRowMaxY > resultHeaderMinY + scrollView.frame.height - keyboardHeight - searchBarHeight) {
            scrollToIndexPath = lastRowPath
            maxY = lastRowMaxY
            scrollToY = maxY - (scrollView.frame.height - keyboardHeight)
        }
        else {
            scrollToIndexPath = resultHeaderPath as IndexPath
            maxY = tableView.rectForRow(at: scrollToIndexPath).minY + scrollView.frame.height - keyboardHeight - searchBarHeight
            scrollToY = maxY - (scrollView.frame.height - keyboardHeight)
        }
        
//        trace("enforceScrollTo CHECK", scrollToIndexPath.row, scrollView.contentOffset.y + scrollView.frame.height, maxY)
        if (scrollView.contentOffset.y + scrollView.frame.height - keyboardHeight > maxY) {
            if (model.pagers.isLoading()) {
//                trace("deferredScrollTo", scrollToIndexPath.row)
                // ensureLastRowIsVisible will be called when the pager is done loading
                return
            }

            if (!animated) {
                tableView.setContentOffset(CGPoint(x: 0, y: scrollToY), animated: false)
                return
            }

            disableViewDidScroll += 1
//            trace("increment #2 disableViewDidScroll", disableViewDidScroll)

//            trace("enforceScrollTo YES \(scrollToIndexPath.row)")
            // Workaround: using dispatch_after here causes the deceleration of the scroll view to be cancelled.  I do no know why this works.
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(Double(NSEC_PER_SEC) * delay)) / Double(NSEC_PER_SEC), execute: {
                UIView.animate(withDuration: 1.0, delay: 0.0, usingSpringWithDamping: 3.0, initialSpringVelocity: 3.0, options: [.curveLinear, .allowUserInteraction], animations: {

                        self.tableView.setContentOffset(CGPoint(x: 0, y: scrollToY), animated: false)
                    }, completion: {
                        (value: Bool) in
//                            trace("decrement #2 disableViewDidScroll", self.disableViewDidScroll)
                        self.disableViewDidScroll -= 1
                })
            })
        }
    }
    
    var scrollingTo = 0
    
    func scrollTo(_ scrollTarget: ScrollTarget) {
        if (scrollTarget == .none) {
            return
        }
        
        let scrollToIndexPath = self.model.topmostPathForType(ScrollTarget.RowType[scrollTarget.rawValue]!)!

        // Workaround: when the keyboard is showing and there are only a few rows, scrollToRowAtIndexPath will leave some rows occluded by the keyboard and will not properly scroll the table.  Use dispatch_after to introduce a delay as a workaround -- for some reason it works when this delay is introduced.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(NSEC_PER_SEC/100)) / Double(NSEC_PER_SEC), execute: {
            self.safelyScrollToRowAtIndexPath(scrollToIndexPath, atScrollPosition: .top)
        })
    }
    
    func safelyScrollToRowAtIndexPath(_ indexPath: IndexPath, atScrollPosition: UITableViewScrollPosition) {
        let originalOffset = self.tableView.contentOffset.y
        self.tableView.scrollToRow(at: indexPath, at: atScrollPosition, animated: false)
        let offset = self.tableView.contentOffset.y
        
        if (originalOffset != offset) {
            // We know it will scroll to a new position and scrollViewDidEndScrollingAnimation will be called
            self.tableView.setContentOffset(CGPoint(x: 0, y: originalOffset), animated: false)
            
//            trace("scrollTo \(scrollTarget)")
            self.disableViewDidScroll += 1
//            trace("increment #3 disabledViewDidScroll", self.disableViewDidScroll)
            self.scrollingTo += 1
            
            // Do the scroll with animation so `scrollViewDidEndScrollingAnimation:` will execute
            self.tableView.scrollToRow(at: indexPath, at: atScrollPosition, animated: true)
        }
    }
    
    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
//        trace("decrement #3 disableViewDidScroll", disableViewDidScroll, scrollingTo)
        if (scrollingTo > 0) {
            disableViewDidScroll -= 1
        }
        scrollingTo -= 1
    }
    
    // MARK: - Table view data source

    // Called before the user changes the selection. Return a new indexPath, or nil, to change the proposed selection.
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return model.isHeaderAtPath(indexPath) ? nil : indexPath
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.numberOfRowsInSection(section)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return model.canEditRowAtIndexPath(indexPath)
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            let r = currentFirstResponder
            if (r != nil && r!.path == indexPath) {
                if (r!.target.text == nil || r!.target.text!.isEmpty) {
                    // In this case the textFieldDidEndEditing callback will delete the textfield so we can return
                    trace("Delete: resign & delete self first responder",  r!.target.text)
                    r!.target.resignFirstResponder()
                    return
                }
                else {
                    trace("Delete: resign self first responder", r!.target.text)
                    r!.target.resignFirstResponder()
                }
            }

            // handle delete (by removing the data from your array and updating the tableview)
            switch (model.rowTypeForPath(indexPath)) {
            case .userCell:
                trace("Delete user", indexPath.row)
                deleteUserAtIndexPath(indexPath)
            case .classCell, .includeCell, .excludeCell, .resultCell:
                trace("Delete class", indexPath.row)
                deleteClassAtIndexPath(indexPath)
            default:
                abort()
            }

            if (currentFirstResponder != nil) {
                trace("Delete: resign first responder", currentFirstResponder!.target.text)
                currentFirstResponder!.target.resignFirstResponder()
            }
            
            executeSearch(nil, scrollTarget: .none)
        }
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true // Yes, the table view can be reordered
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to toIndexPath: IndexPath) {
        // update the item in my data source by first removing at the from index, then inserting at the to index.
        // let item = items[fromIndexPath.row]
        // items.removeAtIndex(fromIndexPath.row)
        // items.insert(item, atIndex: toIndexPath.row)
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if sourceIndexPath.section != proposedDestinationIndexPath.section {
            var row = 0
            if sourceIndexPath.section < proposedDestinationIndexPath.section {
                row = self.tableView(tableView, numberOfRowsInSection: sourceIndexPath.section) - 1
            }
            return IndexPath(row: row, section: sourceIndexPath.section)
        }
        return proposedDestinationIndexPath
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifierForPath(indexPath), for: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        
        if let textInputCell = cell as? TextInputTableViewCell , indexPath == desiredFirstResponder?.path {
            trace("desired becomes responder", textInputCell.textField.text)
            if (!textInputCell.textField.isFirstResponder) {
                textInputCell.textField.becomeFirstResponder()
                if let range = desiredFirstResponder?.range {
                    textInputCell.textField.selectedTextRange = range
                }
            }
            desiredFirstResponder = nil
        }

        return cell
    }
    
    func cellIdentifierForPath(_ indexPath: IndexPath) -> String {
        return model.cellIdentifierForPath(indexPath)
    }
    
    func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath) {
        let qset: QSet?

        if let resultRow = model.resultRowForIndexPath(indexPath) {
            qset = model.pagers.getQSetForRow(resultRow, completionHandler: { (affectedResults: CountableRange<Int>?, totalResults: Int?, response: PagerResponse) -> Void in
                DispatchQueue.main.async(execute: {
                    self.safelyReloadData(affectedResults: affectedResults, totalResults: totalResults)
                })
            })
        }
        else {
            qset = nil
        }
    
        configureCell(cell, atIndexPath: indexPath, qset: qset)
    }
    
    func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath, qset: QSet!) {
        if let resultRow = model.resultRowForIndexPath(indexPath) {
            // result row
            if (model.isActivityIndicatorRow(resultRow)) {
                let activityIndicator = cell.contentView.viewWithTag(100) as! UIActivityIndicatorView
                activityIndicator.startAnimating()
                return
            }
            
            if (qset == nil || qset.title.isEmpty && qset.createdBy.isEmpty && qset.description.isEmpty) {
                // Empty cell
                if let searchAssistCell = cell as? LabelTableViewCell {
                    searchAssistCell.label.text = ""
                    return
                }
                else {
                    let setCell = (cell as! SetTableViewCell)
                    setCell.termsActivityIndicator.stopAnimating()
                    setCell.label.text = ""
                    setCell.term0.text = ""
                    setCell.term1.text = ""
                    setCell.term2.text = ""
                    setCell.definition0.text = ""
                    setCell.definition1.text = ""
                    setCell.definition2.text = ""
                }
                return
            }
            
            let title = qset.title.trimWhitespace()
            let owner = qset.createdBy.trimWhitespace()
            var description = qset.description.trimWhitespace()
//            if (!qset.classIds.isEmpty) {
//                description = qset.classIds + ": " + description
//            }
            
            let titleLength = (title as NSString).length
            let ownerLength = (owner as NSString).length
            var descriptionLength = (description as NSString).length
            
            if (descriptionLength > MaxDescriptionLength) {
                // Use NSString because swift Strings are quite slow
                descriptionLength = NSMaxRange((description as NSString).rangeOfComposedCharacterSequence(at: MaxDescriptionLength))
                description = (description as NSString).substring(to: descriptionLength) + "..."
                descriptionLength += 3
            }
            
            var labelText: String = ""
            
            let titleIndex = 0
            if (titleLength > 0) {
                labelText += title
            }
            
            var ownerIndex: Int
            if (ownerLength > 0) {
                ownerIndex = (labelText as NSString).length
                if (ownerIndex > 0) {
                    labelText += "\n"
                    ownerIndex += 1
                }
                labelText += owner
            }
            else {
                ownerIndex = 0
            }
            
            let hasDescription = !description.isEmpty && description.lowercased() != title.lowercased()
            var descriptionIndex: Int
            if (hasDescription) {
                descriptionIndex = (labelText as NSString).length
                if (descriptionIndex > 0) {
                    labelText += "\n"
                    descriptionIndex += 1
                }
                labelText += description
            }
            else {
                descriptionIndex = 0
            }
            
            let attributedText = NSMutableAttributedString(string: labelText)
            attributedText.addAttribute(NSFontAttributeName, value: preferredFont, range: NSMakeRange(titleIndex, titleLength))
            attributedText.addAttribute(NSFontAttributeName, value: italicFont, range: NSMakeRange(ownerIndex, ownerLength))
            if (hasDescription) {
                attributedText.addAttribute(NSFontAttributeName, value: smallerFont, range: NSMakeRange(descriptionIndex, descriptionLength))
            }
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing += 10.0
            
            /* Alternatively could use tabs and tab stops in combination with newlines for formatting the title, owner and description in the cell
            let frameWidth = CGRectGetWidth(self.tableView.frame)
            let tabLocation = Swift.min(frameWidth / 2, 260.0)
            paragraphStyle.tabStops = [
                NSTextTab(textAlignment: NSTextAlignment.Left, location: tabLocation, options: [:]),
                NSTextTab(textAlignment: NSTextAlignment.Left, location: tabLocation + 10.0, options: [:]),
                NSTextTab(textAlignment: NSTextAlignment.Left, location: tabLocation + 20.0, options: [:]),
                NSTextTab(textAlignment: NSTextAlignment.Left, location: tabLocation + 30.0, options: [:]),
                NSTextTab(textAlignment: NSTextAlignment.Left, location: tabLocation + 40.0, options: [:]),
            ]
            */
            
            // Only apply paragraph spacing for last paragraph in title and last paragraph in owner.  Do not apply to paragraphs elsewhere.
            var start: Int = 0
            var end: Int = 0

            (title as NSString).getParagraphStart(&start, end: &end, contentsEnd: nil, for: NSMakeRange(titleLength, 0))
            attributedText.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSMakeRange(titleIndex + start, end - start))

            (owner as NSString).getParagraphStart(&start, end: &end, contentsEnd: nil, for: NSMakeRange(ownerLength, 0))
            attributedText.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSMakeRange(ownerIndex + start, end - start))
            
            if let searchAssistCell = cell as? LabelTableViewCell {
                searchAssistCell.label.attributedText = attributedText
                return
            }
            
            let setCell = (cell as! SetTableViewCell)
            setCell.label.attributedText = attributedText
            
            /* Alternatively could use three labels instead of one label to position the title, owner and description in the cell
            let title = cell.contentView.viewWithTag(100) as! UILabel
            let owner = cell.contentView.viewWithTag(110) as! UILabel
            let description = cell.contentView.viewWithTag(120) as! UILabel
            
            title.text = qset.title
            owner.text = qset.createdBy
            description.text = qset.description
            */
            
            // Terms
            let termLabels = [ setCell.term0, setCell.term1, setCell.term2 ]
            let definitionLabels = [ setCell.definition0, setCell.definition1, setCell.definition2 ]
            
            let isLoadingTerms = (qset.terms.count == 0)
            isLoadingTerms
                ? setCell.termsActivityIndicator.startAnimating()
                : setCell.termsActivityIndicator.stopAnimating()
            for i in 0...2 {
                if (i < qset.terms.count) {
                    var term: String! = qset.terms[i].term.trimWhitespace()
                    var definition: String! = qset.terms[i].definition.trimWhitespace()
                    
                    // Make sure term and definition always line up horizontally in the cell even if one or the other is empty
                    if (term.isEmpty && definition.isEmpty) {
                        if (isLoadingTerms) {
                            term = "\u{200B}"
                            definition = "\u{200B}"
                        }
                        else {
                            term = nil
                            definition = nil
                        }
                    }
                    else if (term.isEmpty) {
                        term = "\u{200B}"
                    }
                    else if (definition.isEmpty) {
                        definition = "\u{200B}"
                    }
                    
                    termLabels[i]?.text = term
                    definitionLabels[i]?.text = definition
                }
                else {
                    if (isLoadingTerms) {
                        termLabels[i]?.text = "\u{200B}"
                        definitionLabels[i]?.text = "\u{200B}"
                    }
                    else {
                        termLabels[i]?.text = nil
                        definitionLabels[i]?.text = nil
                    }
                }
                termLabels[i]?.font = smallerFont
                definitionLabels[i]?.font = smallerFont
            }
        }
        else {
            if (model.isHeaderAtPath(indexPath)) {
                let label = cell.contentView.viewWithTag(100) as! UILabel
                label.font = preferredFont

                if (indexPath == model.topmostPathForType(.resultHeader)) {
                    if let t = model.pagers.totalResultsNoMax {
                        switch (t) {
                        case 0:
                            label.text = "0 results"
                        case 1:
                            label.text = "1 result"
                        case 5000..<Int.max:
                            // The Quizlet hardcoded upper limit on the number of search results is 5,000
                            label.text = "Over 5,000 results:"
                        default:
                            let numberFormatter = NumberFormatter()
                            numberFormatter.numberStyle = .decimal
                            let formattedTotalResults = numberFormatter.string(from: NSNumber(value: t))
                            label.text = "\(formattedTotalResults!) results:"
                        }
                    }
                    else {
                        label.text = "Search results:"
                    }

                    let activityIndicator = cell.contentView.viewWithTag(110) as! UIActivityIndicatorView
                    model.pagers.isLoading() ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
                }
            }
            else if let textInputCell = cell as? TextInputTableViewCell {
                textInputCell.textField.text = model.rowItemForPath(indexPath)
                textInputCell.textField.font = preferredFont
                textInputCell.textField.autocapitalizationType = UITextAutocapitalizationType.none
                textInputCell.textField.autocorrectionType = UITextAutocorrectionType.no
                textInputCell.textField.spellCheckingType = UITextSpellCheckingType.no
                textInputCell.textField.returnKeyType = UIReturnKeyType.search
            }
            else {
                cell.textLabel!.text = model.rowItemForPath(indexPath)
                cell.textLabel!.font = preferredFont
            }
        }
    }
    
    var sizingCells: [String: UITableViewCell] = [:]
    
    /**
     * This method should make dynamically sizing table view cells work with iOS 7.  I have not been able
     * to test this because Xcode 7 does not support the iOS 7 simulator.
     */
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellIdentifier = cellIdentifierForPath(indexPath)
        var cell = sizingCells[cellIdentifier]
        if (cell == nil) {
            cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
            sizingCells[cellIdentifier] = cell!
        }

        let qset: QSet?
        if let resultRow = model.resultRowForIndexPath(indexPath) {
            qset = model.pagers.peekQSetForRow(resultRow)
        }
        else {
            qset = nil
        }

        configureCell(cell!, atIndexPath: indexPath, qset: qset)
        return calculateHeight(cell!)
    }
    
    func calculateHeight(_ cell: UITableViewCell) -> CGFloat {
        cell.bounds = CGRect(x: 0.0, y: 0.0, width: self.tableView.frame.width, height: cell.bounds.height)

        // Workaround: setting the bounds for multi-line DynamicLabel instances will cause the preferredMaxLayoutWidth to be set corretly when layoutIfNeeded() is called
        if let labelCell = cell as? LabelTableViewCell {
            labelCell.label.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        }
        else if let setCell = cell as? SetTableViewCell {
            setCell.resetBounds()
//            setCell.label.bounds = CGRectMake(0.0, 0.0, 0.0, 0.0)
        }
        else if let textInputCell = cell as? TextInputTableViewCell {
            textInputCell.textField.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        }
        
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        
        let height = cell.contentView.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height
        return height + 1.0 // Add 1.0 for the cell separator height
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if (section == ResultsSection) {
            if (searchBar == nil) {
                searchBar = createSearchBar()
                searchBar.text = model.pagers.queryPager?.query
                searchBar.delegate = self
            }

            return searchBar
         
        }
        else {
            return nil
        }
    }
    
    func createSearchBar() -> UISearchBar {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Query Cell")
        let cellSearchBar = cell!.contentView.subviews[0] as! UISearchBar

        let searchBar = UISearchBar()
        searchBar.placeholder = cellSearchBar.placeholder

        // Update the appearance of the search bar's textfield
        let searchTextField = Common.findTextField(searchBar)!
        searchTextField.font = preferredFont
        searchTextField.autocapitalizationType = UITextAutocapitalizationType.none
        searchTextField.enablesReturnKeyAutomatically = false
        
        return searchBar
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return (section == ResultsSection) ? heightForSearchBar() - 3.0 : 0  // Subtract 3 to reduce borders to look better
    }
    
    var sizingSearchBar: UISearchBar!

    func heightForSearchBar() -> CGFloat {
        if (sizingSearchBar == nil) {
            sizingSearchBar = createSearchBar()
        }
        
        sizingSearchBar.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        sizingSearchBar.setNeedsLayout()
        sizingSearchBar.layoutIfNeeded()
        
        let height = sizingSearchBar.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height
        return height + 1.0 // Add 1.0 for the cell separator height
    }
    
    override func tableView(_ tableView: UITableView,
        estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
            let height: CGFloat
            if let _ = model.resultRowForIndexPath(indexPath) {
                if (estimatedHeightForResultCell == nil) {
                    let cellIdentifier = "Result Cell"
                    var sizingCell = sizingCells[cellIdentifier]
                    if (sizingCell == nil) {
                        sizingCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
                        sizingCells[cellIdentifier] = sizingCell!
                    }
                    
                    let qset = QSet(id: 0, url: "", title: "Title", description: "", createdBy: "Owner", creatorId: 0, createdDate: 0, modifiedDate: 0, classIds: "")
                    qset.terms = [
                        QTerm(id: 0, term: "Term 1", definition: "Definition 1"),
                        QTerm(id: 0, term: "Term 2", definition: "Definition 2"),
                        QTerm(id: 0, term: "Term 3", definition: "Definition 3"),
                    ]
                    configureCell(sizingCell!, atIndexPath: indexPath, qset: qset)
                    estimatedHeightForResultCell = calculateHeight(sizingCell!)
                }
                height = estimatedHeightForResultCell!
            }
            else {
                height = self.tableView(tableView, heightForRowAt: indexPath)
            }
            
            return height
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return self.tableView(tableView, heightForHeaderInSection: section)
    }
}
