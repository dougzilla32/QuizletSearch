//
//  ClassCell.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/2/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class ClassCell: UITableViewCell, ResettableBounds {
    
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var classLabel: UILabel!
    
    func resetBounds() {
        usernameLabel.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        classLabel.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
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
