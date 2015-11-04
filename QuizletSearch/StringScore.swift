//
//  NSString+Score.m
//
//  Created by Nicholas Bruning on 5/12/11.
//  Copyright (c) 2011 Involved Pty Ltd. All rights reserved.
//

//score reference: http://jsfiddle.net/JrLVD/

import Foundation

extension NSString {
    struct StringScoreOptions: OptionSetType {
        let rawValue: Int
        
        static let None = StringScoreOptions(rawValue: 0b00)
        static let FavorSmallerWords = StringScoreOptions(rawValue: 0b01)
        static let ReducedLongStringPenalty = StringScoreOptions(rawValue: 0b10)
    }
    
    var invalidCharacterSet: NSCharacterSet {
        return NSCharacterSet.punctuationCharacterSet()
    }
    
    /*
    var invalidCharacterSet: NSCharacterSet {
        var workingInvalidCharacterSet = NSMutableCharacterSet.lowercaseLetterCharacterSet()
        workingInvalidCharacterSet.formUnionWithCharacterSet(NSCharacterSet.uppercaseLetterCharacterSet())
        workingInvalidCharacterSet.addCharactersInString(" ")
        println("characterSet: \(workingInvalidCharacterSet)")
        return workingInvalidCharacterSet.invertedSet
    }
    */
    
    func scoreAgainst(otherString: NSString) -> Double {
        return self.scoreAgainst(otherString, fuzziness: nil)
    }
    
    func scoreAgainst(otherString: NSString, fuzziness: Double?) -> Double {
        return self.scoreAgainst(otherString, fuzziness: fuzziness, options: .None)
    }
    
    func scoreAgainst(anotherString: NSString, fuzziness: Double?, options: StringScoreOptions) -> Double {
        var string = self.precomposedStringWithCanonicalMapping.componentsSeparatedByCharactersInSet(invalidCharacterSet).joinWithSeparator("") as NSString
        let otherString = anotherString.precomposedStringWithCanonicalMapping.componentsSeparatedByCharactersInSet(invalidCharacterSet).joinWithSeparator("") as NSString
        
        // If the string is equal to the abbreviation, perfect match.
        if (string == otherString) {
            return 1.0
        }
            
            //if it's not a perfect match and is empty return 0
        if (otherString.length == 0) {
            return 0.0
        }
                
        var totalCharacterScore: Double = 0.0
        let otherStringLength = otherString.length
        let stringLength = string.length
        var startOfStringBonus = false
        var otherStringScore: Double
        var fuzzies: Double = 1
        var finalScore: Double
        
        // Walk through abbreviation and add up scores.
        for index in 0..<otherStringLength {
            var characterScore = 0.1
            var indexInString = NSNotFound
            var chr: String
            var rangeChrLowercase: NSRange
            var rangeChrUppercase: NSRange

            chr = (otherString as NSString).substringWithRange(NSMakeRange(index, 1))
            
            //make these next few lines leverage NSNotfound, methinks.
            rangeChrLowercase = string.rangeOfString(chr.lowercaseString)
            rangeChrUppercase = string.rangeOfString(chr.uppercaseString)
            
            if (rangeChrLowercase.location == NSNotFound && rangeChrUppercase.location == NSNotFound) {
                if (fuzziness != nil) {
                    fuzzies += 1 - fuzziness!
                } else {
                    return 0; // this is an error!
                }
                
            } else if rangeChrLowercase.location != NSNotFound && rangeChrUppercase.location != NSNotFound {
                indexInString = min(rangeChrLowercase.location, rangeChrUppercase.location)
                
            } else if rangeChrLowercase.location != NSNotFound || rangeChrUppercase.location != NSNotFound {
                indexInString = rangeChrLowercase.location != NSNotFound ? rangeChrLowercase.location : rangeChrUppercase.location
                
            } else {
                indexInString = min(rangeChrLowercase.location, rangeChrUppercase.location)
                
            }
            
            // Set base score for matching chr
            
            // Same case bonus.
            if (indexInString != NSNotFound && string.substringWithRange(NSMakeRange(indexInString, 1)) == chr) {
                characterScore += 0.1
            }
            
            // Consecutive letter & start-of-string bonus
            if (indexInString == 0) {
                // Increase the score when matching first character of the remainder of the string
                characterScore += 0.6
                if (index == 0) {
                    // If match is the first character of the string
                    // & the first character of abbreviation, add a
                    // start-of-string match bonus.
                    startOfStringBonus = true
                }
            } else if (indexInString != NSNotFound) {
                // Acronym Bonus
                // Weighing Logic: Typing the first character of an acronym is as if you
                // preceded it with two perfect character matches.
                if  (string.substringWithRange(NSMakeRange(indexInString - 1, 1)) == " ")  {
                    characterScore += 0.8
                }
            }
            
            // Left trim the already matched part of the string
            // (forces sequential matching).
            if (indexInString != NSNotFound) {
                string = string.substringFromIndex(indexInString + 1)
            }
            
            totalCharacterScore += characterScore
        }
        
        if (options.contains(.FavorSmallerWords)) {
            // Weigh smaller words higher
            return totalCharacterScore / Double(stringLength)
        }
        
        otherStringScore = totalCharacterScore / Double(otherStringLength)
        
        if (options.contains(.ReducedLongStringPenalty)) {
            // Reduce the penalty for longer words
            let percentageOfMatchedString = Double(otherStringLength) / Double(stringLength)
            let wordScore = otherStringScore * percentageOfMatchedString
            finalScore = (wordScore + otherStringScore) / 2
            
        } else {
            finalScore = ((otherStringScore * (Double(otherStringLength) / Double(stringLength))) + otherStringScore) / 2
        }
        
        finalScore = finalScore / fuzzies
        
        if startOfStringBonus && finalScore + 0.15 < 1 {
            finalScore += 0.15
        }
        
        return finalScore
    }
    
}