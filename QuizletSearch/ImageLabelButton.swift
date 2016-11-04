//
//  ImageLabelButton.swift
//  QuizletSearch
//
//  Created by Doug on 11/3/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import UIKit

enum LabelPosition: Int {
    case bottom
    
    case top
    
    case left
    
    case right
}

@IBDesignable

class ImageLabelButton: UIButton
{
    @IBInspectable var padding: CGFloat = 2
    
    var labelPosition: LabelPosition = .bottom
    
    @IBInspectable var labelLocation: Int {
        get {
            return self.labelPosition.rawValue
        }
        set (position) {
            self.labelPosition = LabelPosition(rawValue: position) ?? .bottom
        }
    }

    @IBInspectable var labelAtEdge: Bool = false

    @IBInspectable var imageAtEdge: Bool = false
    
    @IBInspectable var imageSize: CGSize = CGSize.zero
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        centerTitleLabel()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        centerTitleLabel()
    }
    
    private func centerTitleLabel() {
        self.titleLabel?.textAlignment = .center
    }
    
    private func adjustedTitleRect(forContentRect contentRect: CGRect) -> CGRect {
        return (currentImage != nil && self.imageSize != CGSize.zero)
            ? CGRect(origin: CGPoint(x: titleEdgeInsets.left, y: titleEdgeInsets.top),
                     size: (titleLabel != nil) ? titleLabel!.intrinsicContentSize : CGSize.zero)
            : super.titleRect(forContentRect: contentRect)
    }

    private func adjustedImageRect(forContentRect contentRect: CGRect) -> CGRect {
        return (self.imageSize != CGSize.zero)
            ? CGRect(origin: CGPoint(x: imageEdgeInsets.left, y: imageEdgeInsets.top), size: self.imageSize)
            : super.imageRect(forContentRect: contentRect)
    }

    override func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        var titleRect = adjustedTitleRect(forContentRect: contentRect)
        
        if (currentImage != nil) {
            let titleSize = addInsets(size: titleRect.size, insets: titleEdgeInsets)
            var imageSize = adjustedImageRect(forContentRect: contentRect).size
            imageSize = addInsets(size: imageSize, insets: imageEdgeInsets)

            switch (labelPosition) {
            case .top:
                titleRect = self.topRect(contentRect: contentRect, topSize: titleSize, bottomSize: imageSize,
                                         stickTopToEdge: labelAtEdge, stickBottomToEdge: imageAtEdge, fullWidth: true)
            case .bottom:
                titleRect = self.bottomRect(contentRect: contentRect, topSize: imageSize, bottomSize: titleSize,
                                            stickTopToEdge: imageAtEdge, stickBottomToEdge: labelAtEdge, fullWidth: true)
            case .left:
                titleRect = self.leftRect(contentRect: contentRect, leftSize: titleSize, rightSize: imageSize,
                                          stickLeftToEdge: labelAtEdge, stickRightToEdge: imageAtEdge, fullHeight: true)
            case .right:
                titleRect = self.rightRect(contentRect: contentRect, leftSize: imageSize, rightSize: titleSize,
                                           stickLeftToEdge: imageAtEdge, stickRightToEdge: labelAtEdge, fullHeight: true)
            }
            
            titleRect = removeInsets(rect: titleRect, insets: titleEdgeInsets)
        }
        return titleRect
    }
    
    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        var imageRect = adjustedImageRect(forContentRect: contentRect)
        
        if (titleLabel?.text != nil) {
            let imageSize = addInsets(size: imageRect.size, insets: imageEdgeInsets)
            var titleSize = adjustedTitleRect(forContentRect: contentRect).size
            titleSize = addInsets(size: titleSize, insets: titleEdgeInsets)
            
            switch (labelPosition) {
            case .top:
                imageRect = self.bottomRect(contentRect: contentRect, topSize: titleSize, bottomSize: imageSize,
                                            stickTopToEdge: labelAtEdge, stickBottomToEdge: imageAtEdge, fullWidth: false)
            case .bottom:
                imageRect = self.topRect(contentRect: contentRect, topSize: imageSize, bottomSize: titleSize,
                                         stickTopToEdge: imageAtEdge, stickBottomToEdge: labelAtEdge, fullWidth: false)
            case .left:
                imageRect = self.rightRect(contentRect: contentRect, leftSize: titleSize, rightSize: imageSize,
                                           stickLeftToEdge: labelAtEdge, stickRightToEdge: imageAtEdge, fullHeight: false)
            case .right:
                imageRect = self.leftRect(contentRect: contentRect, leftSize: imageSize, rightSize: titleSize,
                                          stickLeftToEdge: imageAtEdge, stickRightToEdge: labelAtEdge, fullHeight: false)
            }
            
            imageRect = removeInsets(rect: imageRect, insets: imageEdgeInsets)
        }
        return imageRect
    }
    
    private func addInsets(size: CGSize, insets: UIEdgeInsets) -> CGSize {
        var size = size
        size.width += insets.left + insets.right
        size.height += insets.top + insets.bottom
        return size
    }
    
    private func removeInsets(rect: CGRect, insets: UIEdgeInsets) -> CGRect {
        var rect = rect
        rect.origin.x += insets.left
        rect.origin.y += insets.top
        rect.size.width -= insets.left + insets.right
        rect.size.height -= insets.top + insets.bottom
        return rect
    }
    
    private func topRect(contentRect: CGRect, topSize: CGSize, bottomSize: CGSize, stickTopToEdge: Bool, stickBottomToEdge: Bool, fullWidth: Bool) -> CGRect {
        let x = contentRect.origin.x + (fullWidth ? 0.0 : (contentRect.size.width - topSize.width) / 2.0)
        let y: CGFloat
        let halfPad = (contentRect.size.height - (topSize.height + bottomSize.height + padding)) / 2.0
        if (stickTopToEdge || stickBottomToEdge) {
            y = stickTopToEdge ? contentRect.origin.y : contentRect.origin.y + halfPad
        }
        else {
            y = contentRect.origin.y + halfPad
        }
        
        let width = fullWidth ? contentRect.size.width : topSize.width
        let height = topSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func bottomRect(contentRect: CGRect, topSize: CGSize, bottomSize: CGSize, stickTopToEdge: Bool, stickBottomToEdge: Bool, fullWidth: Bool) -> CGRect {
        let x = contentRect.origin.x + (fullWidth ? 0.0 : (contentRect.size.width - bottomSize.width) / 2.0)
        let y: CGFloat
        let halfPad = (contentRect.size.height - (topSize.height + bottomSize.height + padding)) / 2.0
        if (stickTopToEdge || stickBottomToEdge) {
            y = stickBottomToEdge
                ? contentRect.origin.y + contentRect.size.height - bottomSize.height
                : contentRect.origin.y + topSize.height + halfPad
        }
        else {
            y = contentRect.origin.y + halfPad + topSize.height + padding
        }
        
        let width = fullWidth ? contentRect.size.width : bottomSize.width
        let height = bottomSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func leftRect(contentRect: CGRect, leftSize: CGSize, rightSize: CGSize, stickLeftToEdge: Bool, stickRightToEdge: Bool, fullHeight: Bool) -> CGRect {
        let x: CGFloat
        let halfPad = (contentRect.size.width - (leftSize.width + rightSize.width + padding)) / 2.0
        if (stickLeftToEdge || stickRightToEdge) {
            x = stickLeftToEdge ? contentRect.origin.x : contentRect.origin.x + halfPad
        }
        else {
            x = contentRect.origin.x + halfPad
        }
        let y = contentRect.origin.y + (fullHeight ? 0.0 : (contentRect.size.height - leftSize.height) / 2.0)
        
        let width = leftSize.width
        let height = fullHeight ? contentRect.size.height : leftSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func rightRect(contentRect: CGRect, leftSize: CGSize, rightSize: CGSize, stickLeftToEdge: Bool, stickRightToEdge: Bool, fullHeight: Bool) -> CGRect {
        let x: CGFloat
        let halfPad = (contentRect.size.width - (leftSize.width + rightSize.width + padding)) / 2.0
        if (stickLeftToEdge || stickRightToEdge) {
            x = stickRightToEdge
                ? contentRect.origin.x + contentRect.size.width - rightSize.width
                : contentRect.origin.x + leftSize.width + halfPad
        }
        else {
            x = contentRect.origin.x + halfPad + leftSize.width + padding
        }
        let y = contentRect.origin.y + (fullHeight ? 0.0 : (contentRect.size.height - rightSize.height) / 2.0)
        
        let width = rightSize.width
        let height = fullHeight ? contentRect.size.height : rightSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    override var intrinsicContentSize: CGSize {
        var intrinsicSize: CGSize
        
        if (titleLabel?.text != nil && imageView?.image != nil) {
            let labelSize = titleLabel!.intrinsicContentSize
            let imageSize = (self.imageSize != CGSize.zero) ? self.imageSize : imageView!.intrinsicContentSize
            
            switch (labelPosition) {
            case .top, .bottom:
                intrinsicSize = CGSize(width:
                    contentEdgeInsets.left + contentEdgeInsets.right +
                        max(labelSize.width + titleEdgeInsets.left + titleEdgeInsets.right,
                            imageSize.width + imageEdgeInsets.left + imageEdgeInsets.right),
                                       height:
                    contentEdgeInsets.top + contentEdgeInsets.bottom
                        + labelSize.height + titleEdgeInsets.top + titleEdgeInsets.bottom
                        + imageSize.height + imageEdgeInsets.top + imageEdgeInsets.bottom
                        + padding)
            case .left, .right:
                intrinsicSize = CGSize(width:
                    contentEdgeInsets.left + contentEdgeInsets.right
                        + labelSize.width + titleEdgeInsets.left + titleEdgeInsets.right
                        + imageSize.width + imageEdgeInsets.left + imageEdgeInsets.right
                        + padding,
                                       height:
                    contentEdgeInsets.top + contentEdgeInsets.bottom
                        + max(labelSize.height + titleEdgeInsets.top + titleEdgeInsets.bottom,
                              imageSize.height + imageEdgeInsets.top + imageEdgeInsets.bottom))
            }
        }
        else {
            if (titleLabel?.text != nil) {
                intrinsicSize = super.intrinsicContentSize
                intrinsicSize.width += titleEdgeInsets.left + titleEdgeInsets.right
                intrinsicSize.height += titleEdgeInsets.top + titleEdgeInsets.bottom
            }
            else if (imageView?.image != nil) {
                intrinsicSize = (self.imageSize != CGSize.zero) ? self.imageSize : super.intrinsicContentSize
                intrinsicSize.width += imageEdgeInsets.left + imageEdgeInsets.right
                intrinsicSize.height += imageEdgeInsets.top + imageEdgeInsets.bottom
            }
            else {
                intrinsicSize = super.intrinsicContentSize
            }
        }
        
        return intrinsicSize
    }
}
