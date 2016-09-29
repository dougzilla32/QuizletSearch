//
//  TextInputTableViewCell.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/12/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

open class TextInputTableViewCell: UITableViewCell {
    @IBOutlet weak var textField: UITextField!
    
    open func configure(_ text: String?, placeholder: String) {
        textField.text = text
        textField.placeholder = placeholder
    }
}
