//
//  ImageLabelButton.swift
//  QuizletSearch
//
//  Created by Doug on 11/3/16.
//  Copyright © 2016 Doug Stein. All rights reserved.
//

import UIKit

@IBDesignable

class ImageLabelButton: UIButton
{
    let MaxDimension: CGFloat = 10000
    
    @IBInspectable var padding: CGFloat = 2
    
    enum TitlePosition: Int {
        case bottom
        
        case top
        
        case left
        
        case right
    }
    
    var titlePositionEnum: TitlePosition = .bottom
    
    @IBInspectable var titlePosition: Int {
        get {
            return self.titlePositionEnum.rawValue
        }
        set (position) {
            self.titlePositionEnum = TitlePosition(rawValue: position) ?? .bottom
        }
    }
    
    @IBInspectable var alignTitle: Bool = true
    
    @IBInspectable var alignImage: Bool = false
    
    @IBInspectable var imageSize: CGSize = CGSize.zero
    
    private var cachedLabel: UILabel?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configTitleLabel()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configTitleLabel()
    }
    
    private func configTitleLabel() {
        cachedLabel = self.titleLabel
        cachedLabel?.textAlignment = .center
    }
    
    override func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        let indent = traceIn("titleRect contentRect:", contentRect, object: self)
        
        var titleRect = CGRect.zero
        if (cachedLabel != nil) {
            var imageSize = adjustedImageRect(forContentRect: contentRect).size
            var titleSize = calculateTitleSize(forContentRect: contentRect, imageSize: imageSize)
            trace("titleRect titleSize before:", titleSize, indent: indent)

            titleSize = addInsets(size: titleSize, insets: titleEdgeInsets)
            imageSize = addInsets(size: imageSize, insets: imageEdgeInsets)

            switch (titlePositionEnum) {
            case .top:
                titleRect = self.topRect(contentRect: contentRect, topSize: titleSize, bottomSize: imageSize, alignTop: alignTitle, alignBottom: alignImage)
            case .bottom:
                titleRect = self.bottomRect(contentRect: contentRect, topSize: imageSize, bottomSize: titleSize, alignTop: alignImage, alignBottom: alignTitle)
            case .left:
                titleRect = self.leftRect(contentRect: contentRect, leftSize: titleSize, rightSize: imageSize, alignLeft: alignTitle, alignRight: alignImage)
            case .right:
                titleRect = self.rightRect(contentRect: contentRect, leftSize: imageSize, rightSize: titleSize, alignLeft: alignImage, alignRight: alignTitle)
            }
            
            titleRect = removeInsets(rect: titleRect, insets: titleEdgeInsets)
            
            trace("titleRect titleSize:", titleSize, "imageSize:", imageSize, indent: indent)
        }
        
        traceOut("titleRect contentRect:", contentRect, "titleRect:", titleRect, object: self)
        return titleRect
    }
    
    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        let indent = traceIn("imageRect contentRect:", contentRect, object: self)

        var imageRect = adjustedImageRect(forContentRect: contentRect)
        trace("imageRect imageRect before:", imageRect, indent: indent)
        
        if (currentTitle != nil) {
            var titleSize = calculateTitleSize(forContentRect: contentRect, imageSize: imageRect.size)

            let imageSize = addInsets(size: imageRect.size, insets: imageEdgeInsets)
            titleSize = addInsets(size: titleSize, insets: titleEdgeInsets)
            
            switch (titlePositionEnum) {
            case .top:
                imageRect = self.bottomRect(contentRect: contentRect, topSize: titleSize, bottomSize: imageSize, alignTop: alignTitle, alignBottom: alignImage)
            case .bottom:
                imageRect = self.topRect(contentRect: contentRect, topSize: imageSize, bottomSize: titleSize, alignTop: alignImage, alignBottom: alignTitle)
            case .left:
                imageRect = self.rightRect(contentRect: contentRect, leftSize: titleSize, rightSize: imageSize, alignLeft: alignTitle, alignRight: alignImage)
            case .right:
                imageRect = self.leftRect(contentRect: contentRect, leftSize: imageSize, rightSize: titleSize, alignLeft: alignImage, alignRight: alignTitle)
            }
            
            imageRect = removeInsets(rect: imageRect, insets: imageEdgeInsets)

            trace("imageRect titleSize:", titleSize, "imageSize:", imageSize, indent: indent)
        }
        
        traceOut("imageRect contentRect:", contentRect, "imageRect:", imageRect, object: self)
        return imageRect
    }
    
    private func calculateTitleSize(forContentRect contentRect: CGRect, imageSize: CGSize) -> CGSize {
        var titleContentRect = contentRect
        
        if (titlePositionEnum == .left || titlePositionEnum == .right) {
            let adjustWidth = imageSize.width + padding + imageEdgeInsets.left + imageEdgeInsets.right
            titleContentRect.size.width -= adjustWidth
            if (titlePositionEnum == .right) {
                titleContentRect.origin.x += adjustWidth
            }
        }
        
        let bounds = CGRect(origin: contentRect.origin, size: CGSize(width: titleContentRect.size.width, height: MaxDimension))
        let boundingRect = cachedLabel?.textRect(forBounds: bounds, limitedToNumberOfLines: cachedLabel!.numberOfLines)
        return (boundingRect != nil) ? boundingRect!.size : CGSize.zero
    }
    
    private func adjustedImageRect(forContentRect contentRect: CGRect) -> CGRect {
        return (self.imageSize != CGSize.zero)
            ? CGRect(origin: CGPoint(x: imageEdgeInsets.left, y: imageEdgeInsets.top), size: self.imageSize)
            : super.imageRect(forContentRect: contentRect)
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
    
    private func topRect(contentRect: CGRect, topSize: CGSize, bottomSize: CGSize, alignTop: Bool, alignBottom: Bool) -> CGRect {
        let extraWidth = contentRect.size.width - topSize.width
        var x = contentRect.origin.x
        if (alignTop) {
            switch (contentHorizontalAlignment) {
            case .center:
                x += extraWidth / 2.0
            case .right:
                x += extraWidth
            default:
                break
            }
        }
        else {
            x += extraWidth / 2.0
        }
        
        let extraHeight = (contentRect.size.height - (topSize.height + bottomSize.height + padding))
        var y = contentRect.origin.y
        if (alignTop || alignBottom) {
            switch (contentVerticalAlignment) {
            case .center:
                y += extraHeight / 2.0
            case .bottom:
                y += alignTop ? extraHeight : extraHeight / 2.0
            default:
                break
            }
        }
        else {
            y += extraHeight / 2.0
        }
        
        let width = (alignTop && contentHorizontalAlignment == .fill) ? contentRect.size.width : topSize.width
        
        var height = topSize.height
        if (contentVerticalAlignment == .fill) {
            if (alignTop && alignBottom) {
                height += extraHeight / 2.0
            }
            else if (alignTop) {
                height += extraHeight
            }
        }
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func bottomRect(contentRect: CGRect, topSize: CGSize, bottomSize: CGSize, alignTop: Bool, alignBottom: Bool) -> CGRect {
        let extraWidth = contentRect.size.width - bottomSize.width
        var x = contentRect.origin.x
        if (alignBottom) {
            switch (contentHorizontalAlignment) {
            case .center:
                x += extraWidth / 2.0
            case .right:
                x += extraWidth
            default:
                break
            }
        }
        else {
            x += extraWidth / 2.0
        }
        
        let extraHeight = (contentRect.size.height - (topSize.height + bottomSize.height + padding))
        var y = contentRect.origin.y + topSize.height + padding
        if (alignTop || alignBottom) {
            switch (contentVerticalAlignment) {
            case .center:
                y += extraHeight / 2.0
            case .top:
                if (!alignBottom) {
                    y += extraHeight / 2.0
                }
            case .bottom:
                y += extraHeight
            case .fill:
                if (alignBottom && alignTop) {
                    y += extraHeight / 2.0
                }
                else if (alignBottom) {
                    y += extraHeight
                }
            }
        }
        else {
            y += extraHeight / 2.0
        }
        
        let width = (alignBottom && contentHorizontalAlignment == .fill) ? contentRect.size.width : bottomSize.width
        
        var height = bottomSize.height
        if (contentVerticalAlignment == .fill) {
            if (alignTop && alignBottom) {
                height += extraHeight / 2.0
            }
            else if (alignBottom) {
                height += extraHeight
            }
        }
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func leftRect(contentRect: CGRect, leftSize: CGSize, rightSize: CGSize, alignLeft: Bool, alignRight: Bool) -> CGRect {
        let extraWidth = (contentRect.size.width - (leftSize.width + rightSize.width + padding))
        var x = contentRect.origin.x
        if (alignLeft || alignRight) {
            switch (contentHorizontalAlignment) {
            case .center:
                x += extraWidth / 2.0
            case .right:
                x += alignLeft ? extraWidth : extraWidth / 2.0
            default:
                break
            }
        }
        else {
            x += extraWidth / 2.0
        }
        
        let extraHeight = contentRect.size.height - leftSize.height
        var y = contentRect.origin.y
        if (alignLeft) {
            switch (contentVerticalAlignment) {
            case .center:
                y += extraHeight / 2.0
            case .bottom:
                y += extraHeight
            default:
                break
            }
        }
        else {
            y += extraHeight / 2.0
        }
        
        var width = leftSize.width
        if (contentHorizontalAlignment == .fill) {
            if (alignLeft && alignRight) {
                width += extraWidth / 2.0
            }
            else if (alignLeft) {
                width += extraWidth
            }
        }
        
        let height = (alignLeft && contentVerticalAlignment == .fill) ? contentRect.size.height : leftSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func rightRect(contentRect: CGRect, leftSize: CGSize, rightSize: CGSize, alignLeft: Bool, alignRight: Bool) -> CGRect {
        let extraWidth = (contentRect.size.width - (leftSize.width + rightSize.width + padding))
        var x = contentRect.origin.x + leftSize.width + padding
        if (alignLeft || alignRight) {
            switch (contentHorizontalAlignment) {
            case .center:
                x += extraWidth / 2.0
            case .left:
                if (!alignRight) {
                    x += extraWidth / 2.0
                }
            case .right:
                x += extraWidth
            case .fill:
                if (alignRight && alignLeft) {
                    x += extraWidth / 2.0
                }
                else if (alignRight) {
                    x += extraWidth
                }
            }
        }
        else {
            x += extraWidth / 2.0
        }
        
        let extraHeight = contentRect.size.height - rightSize.height
        var y = contentRect.origin.y
        if (alignRight) {
            switch (contentVerticalAlignment) {
            case .center:
                y += extraHeight / 2.0
            case .bottom:
                y += extraHeight
            default:
                break
            }
        }
        else {
            y += extraHeight / 2.0
        }
        
        var width = rightSize.width
        if (contentHorizontalAlignment == .fill) {
            if (alignLeft && alignRight) {
                width += extraWidth / 2.0
            }
            else if (alignRight) {
                width += extraWidth
            }
        }
        
        let height = (alignRight && contentVerticalAlignment == .fill) ? contentRect.size.height : rightSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }

    override var intrinsicContentSize: CGSize {
        let indent = traceIn("intrinsicContentSize", object: self)
        var intrinsicSize: CGSize
        
        if (currentTitle != nil && currentImage != nil) {
            if (currentTitle == "The quick brown fox jumped over the lazy dog") {
                print("Woo hoo!")
            }

            let imageSize = (self.imageSize != CGSize.zero)
                ? self.imageSize :
                super.imageRect(forContentRect: CGRect(x: 0, y: 0, width: MaxDimension, height: MaxDimension)).size

            var lineBreakMode = cachedLabel!.lineBreakMode
            let attributedText: NSAttributedString? = cachedLabel!.attributedText
            if (attributedText != nil) {
                attributedText!.enumerateAttribute(NSParagraphStyleAttributeName, in: NSMakeRange(0, attributedText!.length), options: []) {
                    value, range, stop in
                    let lbm = (value as? NSParagraphStyle)?.lineBreakMode
                    if (lbm != nil) {
                        lineBreakMode = lbm!
                    }
                }
            }

            let contentWidth: CGFloat
            switch (lineBreakMode) {
            case .byWordWrapping, // Wrap at word boundaries, default
                 .byCharWrapping: // Wrap at character boundaries
                contentWidth = self.frame.size.width - (contentEdgeInsets.left + contentEdgeInsets.right)
            case .byClipping, // Simply clip
                 .byTruncatingHead, // Truncate at head of line: "...wxyz"
                 .byTruncatingTail, // Truncate at tail of line: "abcd..."
                 .byTruncatingMiddle: // Truncate middle of line:  "ab...yz"
                contentWidth = MaxDimension
            }
            
            let titleSize = titleRect(forContentRect: CGRect(
                x: contentEdgeInsets.left,
                y: contentEdgeInsets.top,
                width: contentWidth,
                height: MaxDimension))
            
            switch (titlePositionEnum) {
            case .top, .bottom:
                trace("intrinsicContentSize titleSize:", titleSize, "imageSize:", imageSize, indent: indent)
                intrinsicSize = CGSize(width:
                    contentEdgeInsets.left + contentEdgeInsets.right +
                        max(titleSize.width + titleEdgeInsets.left + titleEdgeInsets.right,
                            imageSize.width + imageEdgeInsets.left + imageEdgeInsets.right),
                                       height:
                    contentEdgeInsets.top + contentEdgeInsets.bottom
                        + titleSize.height + titleEdgeInsets.top + titleEdgeInsets.bottom
                        + imageSize.height + imageEdgeInsets.top + imageEdgeInsets.bottom
                        + padding)
            case .left, .right:
                trace("intrinsicContentSize titleSize:", titleSize, "imageSize:", imageSize, indent: indent)
                intrinsicSize = CGSize(width:
                    contentEdgeInsets.left + contentEdgeInsets.right
                        + titleSize.width + titleEdgeInsets.left + titleEdgeInsets.right
                        + imageSize.width + imageEdgeInsets.left + imageEdgeInsets.right
                        + padding,
                                       height:
                    contentEdgeInsets.top + contentEdgeInsets.bottom
                        + max(titleSize.height + titleEdgeInsets.top + titleEdgeInsets.bottom,
                              imageSize.height + imageEdgeInsets.top + imageEdgeInsets.bottom))
            }
        }
        else if (currentTitle != nil) {
            intrinsicSize = super.intrinsicContentSize
            intrinsicSize.width += titleEdgeInsets.left + titleEdgeInsets.right
            intrinsicSize.height += titleEdgeInsets.top + titleEdgeInsets.bottom
        }
        else if (currentImage != nil) {
            intrinsicSize = (self.imageSize != CGSize.zero) ? self.imageSize : super.intrinsicContentSize
            intrinsicSize.width += imageEdgeInsets.left + imageEdgeInsets.right
            intrinsicSize.height += imageEdgeInsets.top + imageEdgeInsets.bottom
        }
        else {
            intrinsicSize = super.intrinsicContentSize
        }

        traceOut("intrinsicContentSize intrinsicSize:", intrinsicSize, object: self)
        return intrinsicSize
    }
}
