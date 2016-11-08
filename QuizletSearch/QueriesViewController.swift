//
//  QueryViewController.swift
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

fileprivate func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}

let WhooshAnimationEnabled = false

class QueriesViewController: TableViewControllerBase, UITableViewDelegate, UIScrollViewDelegate, UITableViewDataSource, UITextFieldDelegate {

    // Load dataModel lazily so the app gets a chance to show the model load error message in the case where the data model is out of sync.
    lazy var dataModel: DataModel = {
        return (UIApplication.shared.delegate as! AppDelegate).dataModel
    }()
    
    let SearchBarEnabled = false
    
    @IBOutlet weak var searchBar: UISearchBar!

    var currentUser: User!
    var addingRow: Int?
    var editingRow: Int?
    var addAnimationsEnabled: Bool?
    var currentFirstResponder: UITextField?
    var recursiveReloadCounter = 0
    var deferReloadRow: IndexPath?
    var updatingText = false
    var inEditMode = false
    var extraRows = 0
    var searchBarHeight: CGFloat!
    var currentContentOffsetY: CGFloat?
    
    var animationBlock: ((CGPoint, _ completionHandler: @escaping () -> Void) -> Void)?
    var animationContext: WhooshAnimationContext?
    var hideRefCount = [IndexPath: Int]()
    
    enum ExtraRowOptions {
        case insertOnly, insertAndDelete
    }

    @IBOutlet weak var editButton: UIButton!

    // MARK: - View Controller
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if (!SearchBarEnabled) {
            tableView.tableHeaderView = nil
        }
        
        let enabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer {
            UIView.setAnimationsEnabled(enabled)
        }

        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        currentUser = dataModel.currentUser!
        
        // Respond to dynamic type font changes
        NotificationCenter.default.addObserver(self,
            selector: #selector(QueriesViewController.preferredContentSizeChanged(_:)),
            name: NSNotification.Name.UIContentSizeCategoryDidChange,
            object: nil)
        resetFonts()

        if (SearchBarEnabled) {
            // Scroll the tableView such that the search bar is not visible
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(NSEC_PER_SEC/100)) / Double(NSEC_PER_SEC), execute: {
                self.searchBarVisibilityWorkaround(.insertAndDelete)
                
                self.searchBarHeight = self.searchBar.bounds.height
                self.tableView.setContentOffset(CGPoint(x: 0, y: self.searchBarHeight), animated: false)
            })
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateFooterShadow(force: true)
    }
    
    deinit {
        // Remove all 'self' observers
        NotificationCenter.default.removeObserver(self)
    }
    
    var preferredFont: UIFont?
    
    func preferredContentSizeChanged(_ notification: Notification) {
        resetFonts()        
        self.view.setNeedsLayout()
        tableView.reloadData()
    }
    
    func resetFonts() {
        preferredFont = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
    }
    
    // Workaround for search bar visibility -- there is a bug with UITableView where sometimes the search bar cannot be properly hidden when the user scrolls the table or when programmatically scrolling the table.  By quickly inserting and deleting an empty row in the table the incorrect behavior is alleviated.
    func searchBarVisibilityWorkaround(_ options: ExtraRowOptions) {
        trace("searchBarVisibilityWorkaround", options)
        let row = self.tableView(tableView, numberOfRowsInSection: 0)
        let indexPath = IndexPath(row: row, section: 0)

        let enabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer {
            UIView.setAnimationsEnabled(enabled)
        }

        self.extraRows += 1
        self.tableView.insertRows(at: [indexPath], with: UITableViewRowAnimation.none)
        if (options == .insertAndDelete) {
            self.extraRows -= 1
            self.tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.none)
        }
    }
    
    // Workaround for search bar positioning -- when programmatically manipulating the tableView, sometimes the contentOffset pops to zero such that the search bar becomes visible.  This workaround alleviates the improper behavior.
    func searchBarPositionWorkaround(_ overrideContentOffsetY: CGFloat? = nil) {
        let offsetY = (overrideContentOffsetY != nil) ? overrideContentOffsetY! : currentContentOffsetY

        let needsAdjustment = (offsetY >= searchBarHeight && tableView.contentOffset.y < searchBarHeight)
        trace("searchBarPositionWorkaround needsAdjustment:", needsAdjustment)
        
        if (needsAdjustment) {
            let enabled = UIView.areAnimationsEnabled
            UIView.setAnimationsEnabled(false)
            defer {
                UIView.setAnimationsEnabled(enabled)
            }

            tableView.setContentOffset(CGPoint(x: 0, y: searchBarHeight), animated: false)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var shouldAutorotate : Bool {
        return true
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return .all
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        trace("prepareForSegue", segue.destination, sender)
        
        if (segue.identifier == "AddQuery") {
            (segue.destination.childViewControllers[0] as! AddQueryViewController).configureForAdd()
        }
        else if (segue.identifier == "Search") {
            let searchViewController = segue.destination as! SearchViewController

            searchViewController.searchBarBecomesFirstResponder = true
            
            if (WhooshAnimationEnabled) {
                // Animate the filter's characters into the SearchViewController's search bar
                let indexPath = tableView.indexPathForSelectedRow!
                let cell = tableView.cellForRow(at: indexPath)!
                let label = cell.contentView.viewWithTag(100) as! UILabel
                
                let origin = label.frame.origin
                let mainWindow = UIApplication.shared.keyWindow!
                let sourcePoint = label.superview!.convert(origin, to: mainWindow)
                
                if (animationContext != nil) {
                    animationContext!.cancel()
                    animationContext = nil
                }
            
                searchViewController.animationBlock = { (targetPoint: CGPoint, completionHandler: @escaping () -> Void) in
                    searchViewController.animationContext = CommonAnimation.letterWhooshAnimationForLabel(label, sourcePoint: sourcePoint, targetPoint: targetPoint, style: .fadeOut, completionHandler: {
                        searchViewController.animationContext = nil
                        self.showLabelAtIndexPath(indexPath, label: label)
                        completionHandler()
                    })
                    
                    self.hideLabelAtIndexPath(indexPath, label: label)
                }
            }
        }
        
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    
    func showLabelAtIndexPath(_ indexPath: IndexPath, label: UILabel) {
        var count = self.hideRefCount[indexPath]
        if (count == nil) {
            label.isHidden = false
        }
        else {
            count! -= 1
            if (count == 0) {
                label.isHidden = false
                self.hideRefCount[indexPath] = nil
            }
            else {
                self.hideRefCount[indexPath] = count
            }
        }
    }
    
    func hideLabelAtIndexPath(_ indexPath: IndexPath, label: UILabel) {
        var count = self.hideRefCount[indexPath]
        if (count == nil) {
            count = 1
            label.isHidden = true
        }
        else {
            count! += 1
        }
        self.hideRefCount[indexPath] = count
    }

    @IBAction func unwindFromUsers(_ segue: UIStoryboardSegue) {
        let y = currentContentOffsetY
        
        if (SearchBarEnabled) {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(NSEC_PER_SEC/100)) / Double(NSEC_PER_SEC), execute: {
                self.searchBarPositionWorkaround(y)
            })
        }
    }
    
    @IBAction func unwindFromSearch(_ segue: UIStoryboardSegue) {
        let y = currentContentOffsetY

        if (SearchBarEnabled) {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(NSEC_PER_SEC/100)) / Double(NSEC_PER_SEC), execute: {
                self.searchBarPositionWorkaround(y)
            })
        }

        // TODO cannnnot count on this being set, need to track separately (nil unwrap error)
        let indexPath = tableView.indexPathForSelectedRow
        if (tableView.indexPathForSelectedRow != nil) {
            tableView.deselectRow(at: tableView.indexPathForSelectedRow!, animated: false)
        }

        if (animationBlock != nil) {
            let cell = tableView.cellForRow(at: indexPath!)!
            let label = cell.contentView.viewWithTag(100) as! UILabel
            
            let origin = label.frame.origin
            let mainWindow = UIApplication.shared.keyWindow!
            let targetPoint = label.superview!.convert(origin, to: mainWindow)
            
            hideLabelAtIndexPath(indexPath!, label: label)
            self.animationBlock!(targetPoint, {
                self.showLabelAtIndexPath(indexPath!, label: label)
            })
            self.animationBlock = nil
        }
    }
    
    @IBAction func unwindFromAddQuery(_ segue: UIStoryboardSegue) {
        if (segue.identifier != "AddQueryAdd") {
            return
        }

        currentContentOffsetY = tableView.contentOffset.y
        if (currentFirstResponder != nil) {
            addAnimationsEnabled = UIView.areAnimationsEnabled
            UIView.setAnimationsEnabled(false)
            if (Common.isEmpty(currentFirstResponder!.text)) {
                // Already have a blank textfield as first responder
                return
            }
            currentFirstResponder!.resignFirstResponder()
        }
        
        // Delete this comment when confirmed to work properly.  Workaround -- use dispatch_after to avoid race condition between the current textfield resigning the first responder and inserting the new row into the table
        let query = dataModel.newQueryForUser(dataModel.currentUser!)
        let addQueryViewController = segue.source as! AddQueryViewController
        addQueryViewController.saveToQuery(query)

        query.title = ""
        if (!query.query.isEmpty) {
            query.title += query.query
        }
        if (!query.creators.isEmpty) {
            if (!query.title.isEmpty) {
                query.title += " "
            }
            query.title += query.creators.replacingOccurrences(of: ",", with: " ")
        }
        if (!query.classes.isEmpty) {
            if (!query.title.isEmpty) {
                query.title += " "
            }
            query.title += query.classes.replacingOccurrences(of: ",", with: " ")
        }
        
        currentUser.addQuery(query)
        dataModel.saveChanges()
        
        let indexPath = IndexPath(row: currentUser.queries.count-1, section: 0)
        editingRow = indexPath.row
        tableView.insertRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
        addingRow = indexPath.row
    }
    
    @IBAction func edit(_ sender: AnyObject) {
        tableView.isEditing = !tableView.isEditing
        inEditMode = tableView.isEditing
        editButton.setTitle(tableView.isEditing ? "Done" : "Edit", for: UIControlState())

        recursiveReloadCounter += 1
        extraRows = 0
        tableView.reloadData()
        if (SearchBarEnabled) {
            self.searchBarVisibilityWorkaround(.insertOnly)
        }
        recursiveReloadCounter -= 1
    }
    
    @IBAction func updateText(_ sender: AnyObject) {
        currentContentOffsetY = tableView.contentOffset.y
        let enabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        updatingText = true
        let textField = sender as! UITextField
        trace("updateText IN text:", textField.text)
        textField.resignFirstResponder()
        trace("updateText OUT text:", textField.text, "defer:", (deferReloadRow as NSIndexPath?)?.row)
        updatingText = false
        UIView.setAnimationsEnabled(enabled)
        
        if (deferReloadRow != nil) {
            tableView.reloadRows(at: [deferReloadRow!], with: UITableViewRowAnimation.automatic)
            deferReloadRow = nil
        }
    }
    
    // MARK: - Textfield delegate
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        currentFirstResponder = textField
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        editingRow = nil
        
        var text = textField.text
        if (text != nil) {
            text = text!.trimWhitespace()
        }
        else {
            text = ""
        }

        let indexPath = indexPathForTextField(textField)
        var deleteRow: IndexPath?
        var reloadRow: IndexPath?
        
        if (text!.isEmpty) {
            if (addingRow == indexPath.row) {
                // Delete
                let query = (currentUser.queries[indexPath.row] as! Query)
                currentUser.removeQueryAtIndex(indexPath.row)
                dataModel.moc.delete(query)
                dataModel.saveChanges()
                deleteRow = indexPath
            }
            else {
                // Revert
                reloadRow = indexPath
            }
        }
        else {
            // Apply
            (currentUser.queries[indexPath.row] as! Query).title = text!
            dataModel.saveChanges()
            reloadRow = indexPath
        }
        
        if (recursiveReloadCounter == 0) {
            if (deleteRow != nil) {
                trace("deleteRow row:", indexPath.row)
                tableView.deleteRows(at: [deleteRow!], with: UITableViewRowAnimation.automatic)
            }
            if (reloadRow != nil) {
                trace("reloadRow row:", indexPath.row, "updatingText:", updatingText)
                if (updatingText) {
                    deferReloadRow = reloadRow
                }
                else {
                    tableView.reloadRows(at: [reloadRow!], with: UITableViewRowAnimation.automatic)
                }
            }
        }
        
        addingRow = nil
        currentFirstResponder = nil
        if (SearchBarEnabled) {
            searchBarPositionWorkaround()
        }
    }
    
    func indexPathForTextField(_ textField: UITextField) -> IndexPath {
        let textInputCell = textField.superview!.superview as! UITableViewCell
        
        // Use indexPathForRowAtPoint rather than indexPathForCell because indexPathForCell returns nil if the cell is not yet visible (either scrolled off or not yet realized)
        return tableView.indexPathForRow(at: textInputCell.center)!
    }
    
    // MARK: - Table view delegate

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        currentContentOffsetY = tableView.contentOffset.y
        return indexPath
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        trace("select", indexPath.row)
        dataModel.currentQuery = dataModel.currentUser?.queries[indexPath.row] as? Query
    }
    
    // MARK: - Table view data source

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row < currentUser.queries.count
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row < currentUser.queries.count
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        currentUser.moveQueriesAtIndexes(IndexSet(integer: sourceIndexPath.row), toIndex: destinationIndexPath.row)
        dataModel.saveChanges()
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            if (currentFirstResponder != nil) {
                currentContentOffsetY = tableView.contentOffset.y
                
                let enabled = UIView.areAnimationsEnabled
                UIView.setAnimationsEnabled(false)
                currentFirstResponder!.resignFirstResponder()
                UIView.setAnimationsEnabled(enabled)
            }

            currentUser.removeQueryAtIndex(indexPath.row)
            dataModel.saveChanges()
            tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
            
            // Call reloadData to workaround a bug where the footer jumps to the bottom of
            // the table after deleting a row.
            tableView.reloadData()
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numRows = currentUser.queries.count
        numRows += extraRows
        return numRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellId: String
        if (indexPath.row >= currentUser.queries.count) {
            cellId = "Empty"
        }
        else if (inEditMode || indexPath.row == editingRow) {
            cellId = "TextField"
        }
        else {
            cellId = "Label"
        }
        
        // trace("cellForRow row:", indexPath.row, "cellId:", cellId)
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        
        if (indexPath.row == editingRow) {
            let textField = cell.contentView.viewWithTag(100) as! UITextField
            if (!textField.isFirstResponder) {
                textField.becomeFirstResponder()
            }
            
            if let enabled = addAnimationsEnabled {
                addAnimationsEnabled = nil
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(NSEC_PER_SEC/100)) / Double(NSEC_PER_SEC), execute: {
                    UIView.setAnimationsEnabled(enabled)
                })
            }
        }
        
        return cell
    }
    
    func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath) {
        if (indexPath.row < currentUser.queries.count) {
            let queryData = currentUser.queries[indexPath.row] as! Query
            let text = queryData.title
            if (inEditMode || indexPath.row == editingRow) {
                let textField = cell.contentView.viewWithTag(100) as! UITextField
                textField.text = text
                textField.font = preferredFont
            }
            else {
                let label = cell.contentView.viewWithTag(100) as! UILabel
                label.text = text
                label.font = preferredFont
            }
        }
    }
    
    lazy var labelSizingCell: UITableViewCell = {
        [unowned self] in
        return self.tableView.dequeueReusableCell(withIdentifier: "Label")!
    }()
    
    lazy var textFieldSizingCell: UITableViewCell = {
        [unowned self] in
        return self.tableView.dequeueReusableCell(withIdentifier: "TextField")!
    }()
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = (inEditMode || indexPath.row == editingRow) ? textFieldSizingCell : labelSizingCell
        configureCell(cell, atIndexPath: indexPath)
        return calculateHeight(cell)
    }
    
    func calculateHeight(_ cell: UITableViewCell) -> CGFloat {
        cell.bounds = CGRect(x: 0.0, y: 0.0, width: self.tableView.frame.width, height: cell.bounds.height);
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        
        let size = cell.contentView.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
        return size.height + 1.0 // Add 1.0 for the cell separator height
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
            return 44.0
    }

    //
    // Header
    //
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Header")!
        configureHeaderCell(cell, section: section)
        return cell.contentView
    }
    
    func configureHeaderCell(_ cell: UITableViewCell, section: Int) {
        let label = cell.contentView.viewWithTag(100) as! UILabel
        label.text = "Filtered by sets containing:"
        label.font = preferredFont
    }
    
    lazy var headerSizingCell: UITableViewCell = {
        [unowned self] in
        return self.tableView.dequeueReusableCell(withIdentifier: "Header")!
    }()
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        configureHeaderCell(headerSizingCell, section: section)
        return calculateHeaderHeight(headerSizingCell)
    }
    
    func calculateHeaderHeight(_ cell: UITableViewCell) -> CGFloat {
        // Workaround: setting the bounds for multi-line UILabel instances will cause the preferredMaxLayoutWidth to be set corretly when layoutIfNeeded() is called
        let label = cell.contentView.viewWithTag(100) as! UILabel
        label.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        return calculateHeight(cell)
    }
    
    //
    // Footer
    //
    
    var footerCell: UITableViewCell?
    
    var footerTopSeparator: UIView?
    
    var footerHeight: CGFloat = 0.0
    
    func isFooterAtBottomOfFrame() -> Bool {
        return tableView.contentOffset.y < (tableView.contentSize.height - tableView.frame.size.height)
    }
    
    func updateFooterShadow(force: Bool) {
        if let cell = footerCell {
            let layer = cell.contentView.layer
            if (isFooterAtBottomOfFrame()) {
                if (force || layer.shadowPath == nil) {
                    let bezierPath = UIBezierPath(rect: CGRect(x: 15, y: -5.0, width: tableView.frame.width, height: 5.0))
                    layer.shadowOffset = CGSize(width: 0.0, height: 5.0)
                    layer.shadowOpacity = 0.5
                    layer.shadowPath = bezierPath.cgPath
                }
                footerTopSeparator!.isHidden = true
            }
            else {
                if (force || layer.shadowPath != nil) {
                    layer.shadowOffset = CGSize(width: 0.0, height: -3.0)
                    layer.shadowOpacity = 0.0
                    layer.shadowPath = nil
                }
                footerTopSeparator!.isHidden = false
            }
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if (inEditMode) {
            return nil
        }
        
        footerCell = tableView.dequeueReusableCell(withIdentifier: "Footer")!
        footerTopSeparator = configureFooterCell(footerCell!, section: section)
        updateFooterShadow(force: false)
        return footerCell!.contentView
    }
    
    func configureFooterCell(_ cell: UITableViewCell, section: Int) -> UIView {
        let button = cell.contentView.viewWithTag(100) as! UIButton
    
        button.titleLabel!.font = UIFont.systemFont(ofSize: preferredFont!.pointSize
            + button.contentEdgeInsets.top + button.contentEdgeInsets.bottom + 1)

        // Workaround: the separator for the last row is hidden by the footer
        let topSep = UIView()
        topSep.frame = CGRect(x: 15, y: 0.0, width: tableView.frame.width, height: 0.5)
        topSep.backgroundColor = tableView.separatorColor
        cell.contentView.addSubview(topSep)
        
        // Add a separator to the bottom of the footer
        let bottomSep = UIView()
        bottomSep.frame = CGRect(x: 15, y: footerHeight - 1.0, width: tableView.frame.width, height: 0.5)
        bottomSep.backgroundColor = tableView.separatorColor
        cell.contentView.addSubview(bottomSep)
        
        return topSep
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if (inEditMode) {
            return 0
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Footer")!
        _ = configureFooterCell(cell, section: section)
        footerHeight = calculateHeight(cell)
        return footerHeight
    }
    
    // MARK: Scroll view delegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateFooterShadow(force: false)
    }
}
