//
//  UserCell.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/2/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class UserCell: UITableViewCell, ResettableBounds {
    
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var usernameLabel: UILabel!
    
    func resetBounds() {
        userImage.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        usernameLabel.bounds = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
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
