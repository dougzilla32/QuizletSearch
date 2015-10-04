//
//  SearchLabel.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/8/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit

class DynamicLabel: UILabel {
    override var bounds : CGRect {
        didSet {
            // If this is a multiline label, need to make sure
            // preferredMaxLayoutWidth always matches the frame width
            // (i.e. orientation change can mess this up)
            if (self.numberOfLines == 0 && bounds.size.width != self.preferredMaxLayoutWidth) {
                self.preferredMaxLayoutWidth = self.bounds.size.width
                self.setNeedsUpdateConstraints()
            }
        }
    }
}
