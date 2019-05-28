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
        case bottom, top, left, right
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
        let indent = traceIn("titleRect title: \"", currentTitle ?? currentAttributedTitle?.string, "\"",
                             "contentRect:", contentRect, object: self)
        if (cachedLabel == nil) {
            return CGRect.zero
        }
        
        var imageSize = adjustedImageRect(forContentRect: contentRect).size
        var titleSize = calculateTitleSize(forContentRect: contentRect, imageSize: imageSize)
        trace("titleRect title: \"", currentTitle ?? currentAttributedTitle?.string, "\"", "titleSize before:", titleSize, indent: indent)

        if (currentTitle != nil || currentAttributedTitle != nil) {
            titleSize = addInsets(size: titleSize, insets: titleEdgeInsets)
        }
        if (currentImage != nil) {
            imageSize = addInsets(size: imageSize, insets: imageEdgeInsets)
        }
        
        let pad: CGFloat = ((currentTitle != nil || currentAttributedTitle != nil) && currentImage != nil) ? self.padding : 0.0

        var titleRect: CGRect
        switch (titlePositionEnum) {
        case .top:
            titleRect = self.topRect(contentRect: contentRect, topSize: titleSize, bottomSize: imageSize, alignTop: alignTitle, alignBottom: alignImage, pad: pad)
        case .bottom:
            titleRect = self.bottomRect(contentRect: contentRect, topSize: imageSize, bottomSize: titleSize, alignTop: alignImage, alignBottom: alignTitle, pad: pad)
        case .left:
            titleRect = self.leftRect(contentRect: contentRect, leftSize: titleSize, rightSize: imageSize, alignLeft: alignTitle, alignRight: alignImage, pad: pad)
        case .right:
            titleRect = self.rightRect(contentRect: contentRect, leftSize: imageSize, rightSize: titleSize, alignLeft: alignImage, alignRight: alignTitle, pad: pad)
        }
        
        titleRect = removeInsets(rect: titleRect, insets: titleEdgeInsets)
        
        trace("titleRect title: \"", currentTitle ?? currentAttributedTitle?.string, "\"",
              "titleSize:", titleSize, "imageSize:", imageSize, indent: indent)
        
        traceOut("titleRect title: \"", currentTitle ?? currentAttributedTitle?.string, "\"",
                 "contentRect:", contentRect, "titleRect:", titleRect, object: self)
        return titleRect
    }
    
    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        let indent = traceIn("imageRect title: \"", currentTitle ?? currentAttributedTitle?.string,
                             "\"", "contentRect:", contentRect, object: self)

        var imageRect = adjustedImageRect(forContentRect: contentRect)
        trace("imageRect title: \"", currentTitle ?? currentAttributedTitle?.string, "\"",
              "imageRect before:", imageRect, indent: indent)
        
        if (currentImage != nil && (currentTitle != nil || currentAttributedTitle != nil)) {
            var titleSize = calculateTitleSize(forContentRect: contentRect, imageSize: imageRect.size)

            let imageSize = addInsets(size: imageRect.size, insets: imageEdgeInsets)
            titleSize = addInsets(size: titleSize, insets: titleEdgeInsets)
            
            switch (titlePositionEnum) {
            case .top:
                imageRect = self.bottomRect(contentRect: contentRect, topSize: titleSize, bottomSize: imageSize, alignTop: alignTitle, alignBottom: alignImage, pad: padding)
            case .bottom:
                imageRect = self.topRect(contentRect: contentRect, topSize: imageSize, bottomSize: titleSize, alignTop: alignImage, alignBottom: alignTitle, pad: padding)
            case .left:
                imageRect = self.rightRect(contentRect: contentRect, leftSize: titleSize, rightSize: imageSize, alignLeft: alignTitle, alignRight: alignImage, pad: padding)
            case .right:
                imageRect = self.leftRect(contentRect: contentRect, leftSize: imageSize, rightSize: titleSize, alignLeft: alignImage, alignRight: alignTitle, pad: padding)
            }
            
            imageRect = removeInsets(rect: imageRect, insets: imageEdgeInsets)

            trace("imageRect title: \"", currentTitle ?? currentAttributedTitle?.string, "\"",
                  "titleSize:", titleSize, "imageSize:", imageSize, indent: indent)
        }
        
        traceOut("imageRect title: \"", currentTitle ?? currentAttributedTitle?.string, "\"",
                 "contentRect:", contentRect, "imageRect:", imageRect, object: self)
        return imageRect
    }
    
    private func adjustedTitleRect(forContentRect contentRect: CGRect) -> CGRect {
        if (currentTitle == nil && currentAttributedTitle == nil) {
            return CGRect.zero
        }

        let bounds = CGRect(origin: contentRect.origin, size: CGSize(width: contentRect.size.width, height: MaxDimension))
        return cachedLabel!.textRect(forBounds: bounds, limitedToNumberOfLines: cachedLabel!.numberOfLines)
    }
    
    private func adjustedImageRect(forContentRect contentRect: CGRect) -> CGRect {
        if (currentImage == nil) {
            return CGRect.zero
        }
        
        return (self.imageSize != CGSize.zero)
            ? CGRect(origin: CGPoint(x: imageEdgeInsets.left, y: imageEdgeInsets.top), size: self.imageSize)
            : super.imageRect(forContentRect: contentRect)
    }
    
    private func calculateTitleSize(forContentRect contentRect: CGRect, imageSize: CGSize) -> CGSize {
        if (currentTitle == nil && currentAttributedTitle == nil) {
            return CGSize.zero
        }
        
        var titleContentRect = contentRect
        
        if (currentImage != nil && (titlePositionEnum == .left || titlePositionEnum == .right)) {
            let adjustWidth = imageSize.width + padding + imageEdgeInsets.left + imageEdgeInsets.right
            titleContentRect.size.width -= adjustWidth
            if (titlePositionEnum == .right) {
                titleContentRect.origin.x += adjustWidth
            }
        }
        
        return adjustedTitleRect(forContentRect: titleContentRect).size
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
    
    private func topRect(contentRect: CGRect, topSize: CGSize, bottomSize: CGSize, alignTop: Bool, alignBottom: Bool, pad: CGFloat) -> CGRect {
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
        
        let extraHeight = (contentRect.size.height - (topSize.height + bottomSize.height + pad))
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
    
    private func bottomRect(contentRect: CGRect, topSize: CGSize, bottomSize: CGSize, alignTop: Bool, alignBottom: Bool, pad: CGFloat) -> CGRect {
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
        
        let extraHeight = (contentRect.size.height - (topSize.height + bottomSize.height + pad))
        var y = contentRect.origin.y + topSize.height + pad
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
            @unknown default:
                // noop
                _ = 1
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
    
    private func leftRect(contentRect: CGRect, leftSize: CGSize, rightSize: CGSize, alignLeft: Bool, alignRight: Bool, pad: CGFloat) -> CGRect {
        let extraWidth = (contentRect.size.width - (leftSize.width + rightSize.width + pad))
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
    
    private func rightRect(contentRect: CGRect, leftSize: CGSize, rightSize: CGSize, alignLeft: Bool, alignRight: Bool, pad: CGFloat) -> CGRect {
        let extraWidth = (contentRect.size.width - (leftSize.width + rightSize.width + pad))
        var x = contentRect.origin.x + leftSize.width + pad
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
            case .leading:
                if (!alignRight) {
                    x += extraWidth / 2.0
                }

            case .trailing:
                x += extraWidth

            @unknown default:
                // noop
                _ = 1
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
        let indent = traceIn("intrinsicContentSize title: \"", currentTitle ?? currentAttributedTitle?.string, "\"",
                             object: self)
        var intrinsicSize: CGSize
        
        if ((currentTitle != nil || currentAttributedTitle != nil) && currentImage != nil) {
            let imageSize = intrinsicImageSize()
            let titleSize = intrinsicTitleSize()
            
            trace("intrinsicContentSize title: \"", currentTitle ?? currentAttributedTitle?.string, "\"",
                  "titleSize:", titleSize, "imageSize:", imageSize, "self.imageSize:", self.imageSize, indent: indent)
            switch (titlePositionEnum) {
            case .top, .bottom:
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
        else if (currentTitle != nil || currentAttributedTitle != nil) {
            intrinsicSize = intrinsicTitleSize()
            intrinsicSize.width += contentEdgeInsets.left + contentEdgeInsets.right + titleEdgeInsets.left + titleEdgeInsets.right
            intrinsicSize.height += contentEdgeInsets.top + contentEdgeInsets.bottom + titleEdgeInsets.top + titleEdgeInsets.bottom
        }
        else if (currentImage != nil) {
            intrinsicSize = intrinsicImageSize()
            intrinsicSize.width += contentEdgeInsets.left + contentEdgeInsets.right + imageEdgeInsets.left + imageEdgeInsets.right
            intrinsicSize.height += contentEdgeInsets.top + contentEdgeInsets.bottom + imageEdgeInsets.top + imageEdgeInsets.bottom
        }
        else {
            intrinsicSize = super.intrinsicContentSize
        }

        traceOut("intrinsicContentSize title: \"", currentTitle ?? currentAttributedTitle?.string, "\"",
                 "intrinsicSize:", intrinsicSize, object: self)
        return intrinsicSize
    }
    
    func intrinsicImageSize() -> CGSize {
        return (self.imageSize != CGSize.zero)
            ? self.imageSize :
            super.imageRect(forContentRect: CGRect(x: 0, y: 0, width: MaxDimension, height: MaxDimension)).size
    }
    
    func intrinsicTitleSize() -> CGSize {
        var lineBreakMode = cachedLabel!.lineBreakMode
        let attributedText: NSAttributedString? = cachedLabel!.attributedText
        if (attributedText != nil) {
            attributedText!.enumerateAttribute(NSAttributedString.Key.paragraphStyle, in: NSMakeRange(0, attributedText!.length), options: []) {
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
        @unknown default:
            contentWidth = self.frame.size.width - (contentEdgeInsets.left + contentEdgeInsets.right)
        }
        
        return titleRect(forContentRect: CGRect(
            x: contentEdgeInsets.left,
            y: contentEdgeInsets.top,
            width: contentWidth,
            height: MaxDimension)).size
    }
}
