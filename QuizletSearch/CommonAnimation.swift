//
//  CommonAnimation.swift
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
    case fadeIn, fadeOut
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
    class func letterSpin() {
        let letter = "Jun and Doug"
        let label = UILabel()
        label.text = letter
        
        let mainWindow = UIApplication.shared.keyWindow!
        mainWindow.addSubview(label)
        
        let startPosition = CGPoint(x: 60, y: 60)
        let endPosition = CGPoint(x: 150, y: 150)
//        label.frame = CGRect(origin: startPosition, size: label.intrinsicContentSize())
        let intrinsicSize = label.intrinsicContentSize
        label.frame = CGRect(origin: startPosition, size: CGSize(width: intrinsicSize.width*2, height: intrinsicSize.height*4))
        
        /*
        keyframe animation:

        CGFloat direction = 1.0f;  // -1.0f to rotate other way
        view.transform = CGAffineTransformIdentity;
        [UIView animateKeyframesWithDuration:1.0 delay:0.0
            options:UIViewKeyframeAnimationOptionCalculationModePaced | UIViewAnimationOptionCurveEaseInOut
            animations:^{
                [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.0 animations:^{
                view.transform = CGAffineTransformMakeRotation(M_PI * 2.0f / 3.0f * direction);
            }];
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.0 animations:^{
            view.transform = CGAffineTransformMakeRotation(M_PI * 4.0f / 3.0f * direction);
        }];
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.0 animations:^{
            view.transform = CGAffineTransformIdentity;
        }];
        }
        completion:^(BOOL finished) {}];
        */

        if (false) {
        CATransaction.begin()

        let spinAnimation = CABasicAnimation(keyPath: "transform.rotation")
        spinAnimation.toValue = 3 * 2 * M_PI
        spinAnimation.duration = 3.0
        label.layer.add(spinAnimation, forKey: "spinAnimation")
/*
        let positionAnimation = CABasicAnimation(keyPath: "position")
        positionAnimation.fromValue = NSValue(CGPoint: startPosition)
        positionAnimation.toValue = NSValue(CGPoint: endPosition)
        positionAnimation.duration = 3.0
        label.layer.addAnimation(spinAnimation, forKey: "positionAnimation")
*/
        
        CATransaction.commit()
        }
        
        if (true) {
        UIView.animate(withDuration: 1.5, animations: {
            label.layer.transform = CATransform3DMakeRotation(CGFloat(M_PI), -1, 0, 1)
            }, completion: { _ in label.removeFromSuperview() })
        }
        
        if (false) {
        UIView.animateAndChain(withDuration: 1.0, delay: 0.0, /* usingSpringWithDamping: 0.33, initialSpringVelocity: 0.0, */ options: [ .curveLinear ], animations: {

            let translate = CGAffineTransform(translationX: endPosition.x - startPosition.x, y: endPosition.y - startPosition.y)
            // let scale = CGAffineTransformMakeScale(0.6, 0.6)
            // let transform =  CGAffineTransformConcat(translate, scale)
             let transform = translate.rotated(by: CGFloat(M_PI + 0.01))

            label.transform = transform
            
            // label.layer.cornerRadius = 62.5
            //label.layer.borderWidth = 2.0
            //label.layer.borderColor = UIColor.redColor().CGColor
            }, completion: nil)
            .animate(withDuration: 1.0, delay: 0.0, options: [ .curveLinear /* .CurveEaseOut, .Repeat */ ], animations: {
                label.transform = CGAffineTransform.identity
                // label.layer.cornerRadius = 0.0
                //label.layer.borderWidth = 0.0
                //label.layer.borderColor = UIColor.blackColor().CGColor
                }, completion: {_ in label.removeFromSuperview() })
        }
        
        
        if (false) {
        CATransaction.begin()
        
        CATransaction.setCompletionBlock({
            label.removeFromSuperview()
        })

        label.layer.add(
            CommonAnimation.createBasicAnimationWithDuration(1.33,
                delay: 0,
                options: nil,
                keyPath: "position",
                fromValue: NSValue(cgPoint: startPosition),
                toValue: NSValue(cgPoint: endPosition)),
            forKey: "position")
        
        label.layer.position = endPosition
        
        let translateByValueY = mainWindow.bounds.midY - label.bounds.midY
        
        let animRotateZ = CABasicAnimation(keyPath: "transform.rotation.z")
        animRotateZ.duration = 1.5
        animRotateZ.toValue = -0.2 // NSNumber(double: -0.2)
        animRotateZ.byValue = NSNumber(value: 2.0 * M_PI as Double)
        // animRotateZ.delegate = self
        animRotateZ.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        // animRotateZ.setValue(self.diaplayLayer, forKey: "animationLayer")
        // self.animationSequence.append(animRotateZ)
        label.layer.add(animRotateZ, forKey: "transform.translation.z")

        if (false) {
        let animTranslateY = CABasicAnimation(keyPath: "transform.translation.y")
        animTranslateY.duration = 1.5
        animTranslateY.toValue = NSNumber(value: Double(mainWindow.bounds.midY) as Double)
        animTranslateY.byValue = NSNumber(value: Double(translateByValueY) as Double)
        animTranslateY.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        // animTranslateY.setValue(self.diaplayLayer, forKey: "animationLayer")
        // self.animationSequence.append(animTranslateY)
        label.layer.add(animTranslateY, forKey: "transform.translation.y")
        }

        /*
        let Down = 2.0
        let UP = 2.0

        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 1 * M_PI/Down
        animation.toValue = 1 * M_PI/UP
        animation.repeatCount = 0
        animation.duration = 0.8
        animation.removedOnCompletion = true
        //animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];

        label.layer.addAnimation(animation, forKey: "transform.rotation.z")
        var transform = CATransform3DIdentity
        transform.m34 = (1/500.0)
        transform = CATransform3DRotate(transform, CGFloat(1 * M_PI/UP), 1, 0,0)
        label.layer.transform = transform
        */
        
        CATransaction.commit()
        }
    }
    
    /* Animate all characters in the label's text from the label's location to the
     * target point.  Each letter is animated separately to give a whooshing effect.
     *
     * 'label' is cloned for each animation label, therefore the animation labels inherit all style attributes
     * 'sourcePoint' is a location relative to 'keyWindow' where the animation starts
     * 'targetPoint' is a location relative to 'keyWindow' where the animation ends */
    class func letterWhooshAnimationForLabel(_ labelParam: UILabel, sourcePoint: CGPoint, targetPoint: CGPoint, style: WhooshStyle, completionHandler: @escaping () -> Void) -> WhooshAnimationContext  {
        
        let labelCopy = Common.cloneView(labelParam) as! UILabel
        labelCopy.isHidden = false
        labelCopy.frame = CGRect(origin: sourcePoint, size: labelCopy.intrinsicContentSize)
        
        let mainWindow = UIApplication.shared.keyWindow!
        let text = (labelCopy.text ?? "") as NSString
        var velocityFactor: CGFloat = 0
        let clearColor = UIColor.clear
        var index = 0
        var animationLabels = [UILabel]()
        
        // trace("letterWhooshAnimationForLabel sourcePoint:", sourcePoint, "targetPoint:", targetPoint, "mainWindow.layer.position:", mainWindow.layer.position, "mainWindow.layer.anchorPoint:", mainWindow.layer.anchorPoint)
        
        while (index < text.length) {
            let animationLabel = Common.cloneView(labelCopy) as! UILabel
            animationLabels.append(animationLabel)
            
            mainWindow.addSubview(animationLabel)
            animationLabel.frame = labelCopy.frame
            
            // Starting value for position
            animationLabel.frame.origin = sourcePoint
            
            let attrText = NSMutableAttributedString(string: text as String)
            if (index != 0) {
                attrText.addAttribute(NSForegroundColorAttributeName, value: clearColor, range: NSRange(location: 0, length: index))
            }
            
            if (index != text.length) {
                index += 1
                if (index != text.length) {
                    attrText.addAttribute(NSForegroundColorAttributeName, value: clearColor, range: NSRange(location: index, length: text.length - index))
                }
            }
            
            animationLabel.attributedText = attrText
            
            let multiplier = (sourcePoint.x < targetPoint.x) ? index+1 : text.length-index
            velocityFactor = CGFloat(multiplier) * 7.5 / CGFloat(text.length+1)
            
            let fadedOpacity: Float = 0.5
            let unfadedOpacity: Float = 1.0
            let fromOpacity = (style == .fadeIn) ? fadedOpacity : unfadedOpacity
            let toOpacity = (style == .fadeIn) ? unfadedOpacity : fadedOpacity
            
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
            
            animationLabel.layer.add(
                CommonAnimation.createSpringAnimationWithDuration(duration,
                    delay: 0,
                    options: nil,
                    springDamping: 1.0,
                    springVelocity: velocityFactor,
                    keyPath: "position",
                    fromValue: NSValue(cgPoint: animationLabel.layer.position),
                    toValue: NSValue(cgPoint: position)),
                forKey: "position")
            
            animationLabel.layer.position = position
            
            animationLabel.layer.add(
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
    
    class func createBasicAnimationWithDuration(_ duration: TimeInterval, delay: TimeInterval, options: UIViewAnimationOptions?,
        keyPath: String, fromValue: Any, toValue: Any) -> CAAnimation {
            return createSpringAnimationWithDuration(duration, delay: delay, options: options, springDamping: 0, springVelocity: 0, keyPath: keyPath, fromValue: fromValue, toValue: toValue)
    }
    
    class func createSpringAnimationWithDuration(_ duration: TimeInterval, delay: TimeInterval, options: UIViewAnimationOptions?,
        //spring additions
        springDamping: CGFloat, springVelocity: CGFloat,
        keyPath: String, fromValue: Any, toValue: Any) -> CAAnimation {
        
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
            
            if options & UIViewAnimationOptions.beginFromCurrentState.rawValue == 0 { //only repeat if not in a chain
                anim.autoreverses = (options & UIViewAnimationOptions.autoreverse.rawValue == UIViewAnimationOptions.autoreverse.rawValue)
                anim.repeatCount = (options & UIViewAnimationOptions.repeat.rawValue == UIViewAnimationOptions.repeat.rawValue) ? Float.infinity : 0
            }
            
            //easing
            var timingFunctionName = kCAMediaTimingFunctionEaseInEaseOut
            
            if options & UIViewAnimationOptions.curveLinear.rawValue == UIViewAnimationOptions.curveLinear.rawValue {
                //first check for linear (it's this way to take up only 2 bits)
                timingFunctionName = kCAMediaTimingFunctionLinear
            } else if options & UIViewAnimationOptions.curveEaseIn.rawValue == UIViewAnimationOptions.curveEaseIn.rawValue {
                timingFunctionName = kCAMediaTimingFunctionEaseIn
            } else if options & UIViewAnimationOptions.curveEaseOut.rawValue == UIViewAnimationOptions.curveEaseOut.rawValue {
                timingFunctionName = kCAMediaTimingFunctionEaseOut
            }
            
            anim.timingFunction = CAMediaTimingFunction(name: timingFunctionName)
            
            //fill mode
            if options & UIViewAnimationOptions.fillModeBoth.rawValue == UIViewAnimationOptions.fillModeBoth.rawValue {
                //both
                anim.fillMode = kCAFillModeBoth
            } else if options & UIViewAnimationOptions.fillModeForwards.rawValue == UIViewAnimationOptions.fillModeForwards.rawValue {
                //forward
                anim.fillMode = (anim.fillMode == kCAFillModeBackwards) ? kCAFillModeBoth : kCAFillModeForwards
            } else if options & UIViewAnimationOptions.fillModeBackwards.rawValue == UIViewAnimationOptions.fillModeBackwards.rawValue {
                //backwards
                anim.fillMode = kCAFillModeBackwards
            }
        }
        
        return anim
    }
}
