//
//  MyTextView.swift
//  QuizletSearch
//
//  Created by Doug on 11/7/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import UIKit

class DebugTextView: UITextView {
    @available(iOS 9.0, *)
    override var forFirstBaselineLayout: UIView {
        get {
            let view = super.forFirstBaselineLayout
            trace("DebugTextView forFirstBaselineLayout:", view)
            return view
        }
    }
    
    @available(iOS 9.0, *)
    override var forLastBaselineLayout: UIView {
        get {
            let view = super.forLastBaselineLayout
            trace("DebugTextView forLastBaselineLayout:", view)
            return view
        }
    }
    
    override var intrinsicContentSize: CGSize {
        get {
            let size = super.intrinsicContentSize
            trace("DebugTextView intrinsicContentSize:", size, "frame.size:", self.frame.size)
            return size
        }
    }
    
    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        
        trace("DebugTextView invalidateIntrinsicContentSize")
    }
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        let size = super.systemLayoutSizeFitting(targetSize)
        trace("DebugTextView systemLayoutSizeFitting(", targetSize, ",", size)
        return size
    }
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        let size = super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: horizontalFittingPriority, verticalFittingPriority: verticalFittingPriority)
        trace("DebugTextView systemLayoutSizeFitting(", targetSize, "withHorizontalFittingPriority:", horizontalFittingPriority, "verticalFittingPriority:", verticalFittingPriority, "):", size)
        return size
    }
    
    /* UILayoutGuide objects owned by the receiver.
     */
    @available(iOS 9.0, *)
    override var layoutGuides: [UILayoutGuide] { get {
        let guides = super.layoutGuides
        trace("DebugTextView layoutGuides:", guides)
        return guides
        }}
    
    
    /* Adds layoutGuide to the receiver, passing the receiver in -setOwningView: to layoutGuide.
     */
    @available(iOS 9.0, *)
    override func addLayoutGuide(_ layoutGuide: UILayoutGuide) {
        super.addLayoutGuide(layoutGuide)
        trace("DebugTextView addLayoutGuide:", layoutGuide)
    }
    
    
    /* Removes layoutGuide from the receiver, passing nil in -setOwningView: to layoutGuide.
     */
    @available(iOS 9.0, *)
    override func removeLayoutGuide(_ layoutGuide: UILayoutGuide) {
        super.removeLayoutGuide(layoutGuide)
        trace("DebugTextView removeLayoutGuide:", layoutGuide)
    }

    override var hasAmbiguousLayout: Bool { get {
        let b = super.hasAmbiguousLayout
        trace("DebugTextView hasAmbiguousLayout:", b)
        return b
        }}
    
    
    @available(iOS 6.0, *)
    override func exerciseAmbiguityInLayout() {
        super.exerciseAmbiguityInLayout()
        trace("DebugTextView exerciseAmbiguityInLayout")
    }

    override func constraintsAffectingLayout(for axis: NSLayoutConstraint.Axis) -> [NSLayoutConstraint] {
        let c = super.constraintsAffectingLayout(for: axis)
        trace("DebugTextView constraintsAffectingLayout(for: ", axis, "):", c)
        return c
    }
}
