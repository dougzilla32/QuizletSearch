//
//  Boyer-Moore.swift
//  QuizletSearch
//
//  Created by Doug Stein on 6/20/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import Foundation

class BoyerMoorePattern {
    let pattern: String
    let patternLength: String.IndexDistance
    fileprivate(set) var skipTable: [Character: Int]
    
    init(pattern: String) {
        self.pattern = pattern

        // Cache the length of the search pattern because we're going to
        // use it a few times and it's expensive to calculate.
        self.patternLength = pattern.count
        if self.patternLength == 0 {
            NSLog("Pattern length is zero: \(pattern)")
        }
        
        // Make the skip table. This table determines how many times successor()
        // needs to be called when a character from the pattern is found.
        self.skipTable = [Character: Int]()
        for (i, c) in pattern.enumerated() {
            skipTable[c] = patternLength - i - 1
        }
    }
}

extension String {
    func findIndexOf(pattern bmp: BoyerMoorePattern) -> String.Index? {
        // This points at the last character in the pattern.
        let p = bmp.pattern.index(before: bmp.pattern.endIndex)
        
        // The pattern is scanned right-to-left, so skip ahead in the string by
        // the length of the pattern. (Minus 1 because startIndex already points
        // at the first character in the source string.)
        var i = self.index(self.startIndex, offsetBy: bmp.patternLength - 1, limitedBy: self.endIndex)!
        
        // Keep going until the end of the string is reached.
        while i < self.endIndex {
            
            // Does the current character match the last character from the pattern?
            if self[i] == bmp.pattern[p] {
                
                // There is a possible match. Do a brute-force search backwards.
                var j = i
                var q = p
                var found = true
                while q != bmp.pattern.startIndex {
                    j = self.index(before: j)
                    q = bmp.pattern.index(before: q)
                    if self[j] != bmp.pattern[q] {
                        found = false
                        break
                    }
                }
                
                // If the pattern matches, we're done. If no match, then we can only
                // safely skip one character ahead.
                if found {
                    return j
                } else {
                    i = self.index(after: i)
                }
            } else {
                // The characters are not equal, so skip ahead. The amount to skip is
                // determined by the skip table. If the character is not present in the
                // pattern, we can skip ahead by the full pattern length. But if the 
                // character *is* present in the pattern, there may be a match up ahead 
                // and we can't skip as far.
                i = self.index(i, offsetBy: bmp.skipTable[self[i]] ?? bmp.patternLength, limitedBy: self.endIndex)!
            }
        }
        return nil
    }
}
