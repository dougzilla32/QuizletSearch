//
//  ActivityCell.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/2/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class ActivityCell: UITableViewCell, ResettableBounds {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    func resetBounds() {
        activityIndicator.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
}
