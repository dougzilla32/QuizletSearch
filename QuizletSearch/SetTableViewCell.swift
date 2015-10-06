//
//  LabelTableViewCell.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/2/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

class SetTableViewCell: UITableViewCell {
    
    @IBOutlet weak var label: DynamicLabel!
    @IBOutlet weak var term0: UILabel!
    @IBOutlet weak var term1: UILabel!
    @IBOutlet weak var term2: UILabel!
    @IBOutlet weak var definition0: UILabel!
    @IBOutlet weak var definition1: UILabel!
    @IBOutlet weak var definition2: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}
