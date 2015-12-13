//
//  SpringAnimation.swift
//  QuizletSearch
//
//
// Derived from: Easy Animation
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

class SpringAnimation {
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
                    
                    //TODO: refine the spring animation setup
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