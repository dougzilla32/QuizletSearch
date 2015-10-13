//
//  TextInputTableViewCell.swift
//  QuizletSearch
//
//  Created by Doug Stein on 10/12/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//

import UIKit

public class TextInputTableViewCell: UITableViewCell {
    @IBOutlet weak var textField: UITextField!
    
    public func configure(text: String?, placeholder: String) {
        textField.text = text
        textField.placeholder = placeholder
    }
}
