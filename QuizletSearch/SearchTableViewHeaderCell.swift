//
//  SearchTableViewHeaderCell.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/8/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit

class SearchTableViewHeaderCell: UITableViewCell {
    
    @IBOutlet weak var headerLabel: DynamicLabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
