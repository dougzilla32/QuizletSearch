//
//  SpringAnimation.swift
//  QuizletSearch
//
//  Created by Doug Stein on 9/29/15.
//  Copyright © 2015 Doug Stein. All rights reserved.
//
//
// 'createSpringAnimationWithDuration' is derived from Easy Animation, covered by the MIT License as follows:
// https://github.com/icanzilb/EasyAnimation
//
// The MIT License (MIT)
// Created by Marin Todorov on 4/11/15.
// Copyright (c) 2015 Underplot ltd. All rights reserved.
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit

enum WhooshStyle {
    case FadeIn, FadeOut
}

class WhooshAnimationContext {
    let animationLabels: [UILabel]
    
    init(animationLabels: [UILabel]) {
        self.animationLabels = animationLabels
    }
    
    func cancel() {
        trace("Animation cancelled!!", animationLabels.count > 0 ? animationLabels[0].text : "")
        CATransaction.begin()
        for label in animationLabels {
            label.layer.removeAllAnimations()
        }
        CATransaction.commit()
    }
}

class CommonAnimation {
    /* Animate all characters in the label's text from the label's location to the
     * target point.  Each letter is animated separately to give a whooshing effect.
     *
     * 'label' is cloned for each animation label, therefore the animation labels inherit all style attributes
     * 'sourcePoint' is a location relative to 'keyWindow' where the animation starts
     * 'targetPoint' is a location relative to 'keyWindow' where the animation ends */
    class func letterWhooshAnimationForLabel(var label: UILabel, sourcePoint: CGPoint, targetPoint: CGPoint, style: WhooshStyle, completionHandler: () -> Void) -> WhooshAnimationContext  {
        
        label = Common.cloneView(label) as! UILabel
        label.hidden = false
        label.frame = CGRect(origin: sourcePoint, size: label.intrinsicContentSize())
        
        let mainWindow = UIApplication.sharedApplication().keyWindow!
        let text = (label.text != nil ? label.text! : "") as NSString
        var velocityFactor: CGFloat = 0
        let clearColor = UIColor.clearColor()
        var index = 0
        var animationLabels = [UILabel]()
        
        // trace("letterWhooshAnimationForLabel sourcePoint:", sourcePoint, "targetPoint:", targetPoint, "mainWindow.layer.position:", mainWindow.layer.position, "mainWindow.layer.anchorPoint:", mainWindow.layer.anchorPoint)
        
        while (index < text.length) {
            let animationLabel = Common.cloneView(label) as! UILabel
            animationLabels.append(animationLabel)
            
            mainWindow.addSubview(animationLabel)
            animationLabel.frame = label.frame
            
            // Starting value for position
            animationLabel.frame.origin = sourcePoint
            
            let attrText = NSMutableAttributedString(string: text as String)
            if (index != 0) {
                attrText.addAttribute(NSForegroundColorAttributeName, value: clearColor, range: NSRange(location: 0, length: index))
            }
            
            if (index != text.length) {
                index++
                if (index != text.length) {
                    attrText.addAttribute(NSForegroundColorAttributeName, value: clearColor, range: NSRange(location: index, length: text.length - index))
                }
            }
            
            animationLabel.attributedText = attrText
            
            let multiplier = (sourcePoint.x < targetPoint.x) ? index+1 : text.length-index
            velocityFactor = CGFloat(multiplier) * 7.5 / CGFloat(text.length+1)
            
            let fadedOpacity: Float = 0.5
            let unfadedOpacity: Float = 1.0
            let fromOpacity = (style == .FadeIn) ? fadedOpacity : unfadedOpacity
            let toOpacity = (style == .FadeIn) ? unfadedOpacity : fadedOpacity
            
            // Starting value for opacity
            animationLabel.layer.opacity = fromOpacity
            
            //enable layer actions
            CATransaction.begin()
            CATransaction.setDisableActions(false)
            
            let isLast = (index == text.length)
            if (isLast) {
                CATransaction.setCompletionBlock({
                    completionHandler()

                    for al in animationLabels {
                        al.superview!.setNeedsDisplay()
                        al.removeFromSuperview()
                    }
                    animationLabels = []
                })
            }

            let duration = 1.0
            let position = CGPoint(
                x: targetPoint.x + animationLabel.frame.size.width / 2.0,
                y: targetPoint.y + animationLabel.frame.size.height / 2.0)
            // trace("Animating from", animationLabel.layer.position, "to", position, "where width is", animationLabel.frame.width, "and height is", animationLabel.frame.height)
            
            animationLabel.layer.addAnimation(
                CommonAnimation.createSpringAnimationWithDuration(duration,
                    delay: 0,
                    options: nil,
                    springDamping: 1.0,
                    springVelocity: velocityFactor,
                    keyPath: "position",
                    fromValue: NSValue(CGPoint: animationLabel.layer.position),
                    toValue: NSValue(CGPoint: position)),
                forKey: "position")
            
            animationLabel.layer.position = position
            
            animationLabel.layer.addAnimation(
                CommonAnimation.createBasicAnimationWithDuration(duration,
                    delay: 0,
                    options: nil,
                    keyPath: "opacity",
                    fromValue: fromOpacity,
                    toValue: toOpacity),
                forKey: "opacity")
            
            animationLabel.layer.opacity = toOpacity
            
            CATransaction.commit()
        }
        
        return WhooshAnimationContext(animationLabels: animationLabels)
    }
    
    class func createBasicAnimationWithDuration(duration: NSTimeInterval, delay: NSTimeInterval, options: UIViewAnimationOptions?,
        keyPath: String, fromValue: AnyObject, toValue: AnyObject) -> CAAnimation {
            return createSpringAnimationWithDuration(duration, delay: delay, options: options, springDamping: 0, springVelocity: 0, keyPath: keyPath, fromValue: fromValue, toValue: toValue)
    }
    
    class func createSpringAnimationWithDuration(duration: NSTimeInterval, delay: NSTimeInterval, options: UIViewAnimationOptions?,
        //spring additions
        springDamping: CGFloat, springVelocity: CGFloat,
        keyPath: String, fromValue: AnyObject, toValue: AnyObject) -> CAAnimation {
        
        let anim: CAAnimation
        
        if (springDamping > 0.0) {
            //create a layer spring animation
            
            if #available(iOS 9, *) { // iOS9!
                anim = CASpringAnimation(keyPath: keyPath)
                if let anim = anim as? CASpringAnimation {
                    anim.fromValue = fromValue
                    anim.toValue = toValue
                    
                    let epsilon = 0.001
                    anim.damping = CGFloat(-2.0 * log(epsilon) / duration)
                    anim.stiffness = CGFloat(pow(anim.damping, 2)) / CGFloat(pow(springDamping * 2, 2))
                    anim.mass = 1.0
                    anim.initialVelocity = springVelocity
                    // trace("Spring values -- damping:", anim.damping, "stiffness:", anim.stiffness, "mass:", anim.mass, "initialVelocity:", anim.initialVelocity, "settlingDuration:", anim.settlingDuration)
                    
                    // Apple recommendeds using the settlingDuration as the duration, otherwise the animation can be too short or too long.  However this causes problems with timed completion handlers.
                    // anim.duration = anim.settlingDuration
                    anim.duration = duration
                }
            } else {
                anim = RBBSpringAnimation(keyPath: keyPath)
                if let anim = anim as? RBBSpringAnimation {
                    anim.from = fromValue
                    anim.to = toValue
                    
                    //todo: refine the spring animation setup
                    //lotta magic numbers to mimic UIKit springs
                    let epsilon = 0.001
                    anim.damping = -2.0 * log(epsilon) / duration
                    anim.stiffness = Double(pow(anim.damping, 2)) / Double(pow(springDamping * 2, 2))
                    anim.mass = 1.0
                    anim.velocity = Double(springVelocity)
                    // trace("Spring values -- damping:", anim.damping, "stiffness:", anim.stiffness, "mass:", anim.mass, "initialVelocity:", anim.initialVelocity, "settlingDuration:", anim.settlingDuration)

                    anim.duration = duration
                }
            }
        } else {
            //create property animation
            anim = CABasicAnimation(keyPath: keyPath)
            (anim as! CABasicAnimation).fromValue = fromValue
            (anim as! CABasicAnimation).toValue = toValue
            anim.duration = duration
        }
        
        if delay > 0.0 {
            anim.beginTime = CACurrentMediaTime() + delay
            anim.fillMode = kCAFillModeBackwards
        }
        
        //options
        if let options = options?.rawValue {
            
            if options & UIViewAnimationOptions.BeginFromCurrentState.rawValue == 0 { //only repeat if not in a chain
                anim.autoreverses = (options & UIViewAnimationOptions.Autoreverse.rawValue == UIViewAnimationOptions.Autoreverse.rawValue)
                anim.repeatCount = (options & UIViewAnimationOptions.Repeat.rawValue == UIViewAnimationOptions.Repeat.rawValue) ? Float.infinity : 0
            }
            
            //easing
            var timingFunctionName = kCAMediaTimingFunctionEaseInEaseOut
            
            if options & UIViewAnimationOptions.CurveLinear.rawValue == UIViewAnimationOptions.CurveLinear.rawValue {
                //first check for linear (it's this way to take up only 2 bits)
                timingFunctionName = kCAMediaTimingFunctionLinear
            } else if options & UIViewAnimationOptions.CurveEaseIn.rawValue == UIViewAnimationOptions.CurveEaseIn.rawValue {
                timingFunctionName = kCAMediaTimingFunctionEaseIn
            } else if options & UIViewAnimationOptions.CurveEaseOut.rawValue == UIViewAnimationOptions.CurveEaseOut.rawValue {
                timingFunctionName = kCAMediaTimingFunctionEaseOut
            }
            
            anim.timingFunction = CAMediaTimingFunction(name: timingFunctionName)
            
            //fill mode
            if options & UIViewAnimationOptions.FillModeBoth.rawValue == UIViewAnimationOptions.FillModeBoth.rawValue {
                //both
                anim.fillMode = kCAFillModeBoth
            } else if options & UIViewAnimationOptions.FillModeForwards.rawValue == UIViewAnimationOptions.FillModeForwards.rawValue {
                //forward
                anim.fillMode = (anim.fillMode == kCAFillModeBackwards) ? kCAFillModeBoth : kCAFillModeForwards
            } else if options & UIViewAnimationOptions.FillModeBackwards.rawValue == UIViewAnimationOptions.FillModeBackwards.rawValue {
                //backwards
                anim.fillMode = kCAFillModeBackwards
            }
        }
        
        return anim
    }
}