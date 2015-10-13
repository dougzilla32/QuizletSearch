//
//  SearchLabel.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/8/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit

class InsetTextField: UITextField {
    var dx = CGFloat(15.0)
    var dy = CGFloat(10.0)
    
    // placeholder position
    override func textRectForBounds(bounds: CGRect) -> CGRect {
        return CGRectInset(bounds, dx, dy)
    }
    
    // text position
    override func editingRectForBounds(bounds: CGRect) -> CGRect {
        return CGRectInset(bounds, dx, dy);
    }
}
