//
//  Common.swift
//  QuizletSearch
//
//  Created by Doug Stein on 7/28/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit

let IsFaultTolerant = false

let IsTraceEnabled = false

func trace(_ items: Any?..., separator: String = " ", terminator: String = "\n") {
    traceItems(items: items, separator: separator, terminator: terminator)
}

func traceItems(items: [Any?], separator: String = " ", terminator: String = "\n") {
    if (!IsTraceEnabled) {
        return
    }
    
    var s = ""
    for i in items {
        if (!s.isEmpty && !separator.isEmpty) {
            s = s + separator
        }
        if (i != nil) {
            s += String(describing: i!)
        }
        else {
            s += "nil"
        }
    }
    print(s, terminator: terminator)
}

var traceIndentMap: [ObjectIdentifier: Int] = [:]

func traceIn(_ items: Any?..., object: AnyObject) -> Int {
    let id = ObjectIdentifier(object)

    var indentLevel = traceIndentMap[id]
    if (indentLevel == nil) {
        indentLevel = 0
    }
    traceIndentMap[id] = indentLevel! + 1
    
    var newItems: [Any?] = []
    newItems.append(indentSpacing(indentLevel: indentLevel!))
    newItems.append("->")
    newItems += items
    traceItems(items: newItems)
    
    return indentLevel!
}

func trace(_ items: Any?..., indent: Int) {
    var newItems: [Any?] = []
    newItems.append(indentSpacing(indentLevel: indent))
    newItems.append(" +")
    newItems += items
    traceItems(items: newItems)
}

func traceOut(_ items: Any?..., object: AnyObject) {
    let id = ObjectIdentifier(object)
    
    var indentLevel = traceIndentMap[id]
    if (indentLevel == nil) {
        indentLevel = 0
    }
    else {
        indentLevel! -= 1
        traceIndentMap[id] = indentLevel!
    }

    var newItems: [Any?] = []
    newItems.append(indentSpacing(indentLevel: indentLevel!))
    newItems.append("<-")
    newItems += items
    traceItems(items: newItems)
}

func indentSpacing(indentLevel: Int) -> String {
    var s = ""
    for _ in 0..<indentLevel {
        s += "  "
    }
    return s
}

/*
func max<T : Comparable>(_ items: T?...) -> T? {
    var m: T? = nil
    for item in items {
        if (item != nil) {
            if (m != nil) {
                m = max(m!, item!)
            }
            else {
                m = item
            }
        }
    }
    return m
}
*/

func dispatchSyncMain(_ block: ()->()) -> Void {
    if (Thread.isMainThread) {
        block()
    }
    else {
        DispatchQueue.main.sync(execute: block)
    }
}

class Common {
    static let isSampleMode = false
    
    class func isEmpty(_ s: String?) -> Bool {
        return s == nil || s!.trimWhitespace().isEmpty
    }
    
    class func preferredFontForTextStyle(_ textStyle: UIFont.TextStyle) -> UIFont? {
        // choose the font size
        let fontSize: CGFloat = preferredFontSize()

        // choose the font weight
        if (textStyle == UIFont.TextStyle.headline || textStyle == UIFont.TextStyle.subheadline) {
            return UIFont.boldSystemFont(ofSize: fontSize)
        } else {
            return UIFont.systemFont(ofSize: fontSize)
        }
    }
    
    class func preferredFontSize() -> CGFloat {
        let fontSize: CGFloat
        
        switch (UIApplication.shared.preferredContentSizeCategory) {
        case UIContentSizeCategory.extraSmall:
            fontSize = 12.0
        case UIContentSizeCategory.small:
            fontSize = 12.0
        case UIContentSizeCategory.medium:
            fontSize = 13.0
        case UIContentSizeCategory.large:
            fontSize = 14.0
        case UIContentSizeCategory.extraLarge:
            fontSize = 16.0
        case UIContentSizeCategory.extraExtraLarge:
            fontSize = 18.0
        case UIContentSizeCategory.extraExtraExtraLarge:
            fontSize = 20.0
        case UIContentSizeCategory.accessibilityMedium:
            fontSize = 24.0
        case UIContentSizeCategory.accessibilityLarge:
            fontSize = 28.0
        case UIContentSizeCategory.accessibilityExtraLarge:
            fontSize = 32.0
        case UIContentSizeCategory.accessibilityExtraExtraLarge:
            fontSize = 36.0
        case UIContentSizeCategory.accessibilityExtraExtraExtraLarge:
            fontSize = 40.0
        default:
            fontSize = 12.0
        }
        
        return fontSize
    }
    
    static let Arial = "ArialMT"
    static let ArialBold = "Arial-BoldMT"

    class func preferredFontForFamily(_ fontFamily: String) -> UIFont? {
        // NSLog("%@", UIFont.fontNamesForFamilyName("Arial"))
        
        let fontSize: CGFloat = preferredFontSizeForFamily(fontFamily)
        return UIFont(name: fontFamily, size: fontSize)
    }
    
    class func preferredFontSizeForFamily(_ fontFamily: String) -> CGFloat {
        let fontSize: CGFloat
        
        switch (UIApplication.shared.preferredContentSizeCategory) {
        case UIContentSizeCategory.extraSmall:
            fontSize = 12.0
        case UIContentSizeCategory.small:
            fontSize = 14.0
        case UIContentSizeCategory.medium:
            fontSize = 16.0
        case UIContentSizeCategory.large:
            fontSize = 18.0
        case UIContentSizeCategory.extraLarge:
            fontSize = 20.0
        case UIContentSizeCategory.extraExtraLarge:
            fontSize = 22.0
        case UIContentSizeCategory.extraExtraExtraLarge:
            fontSize = 24.0
        case UIContentSizeCategory.accessibilityMedium:
            fontSize = 28.0
        case UIContentSizeCategory.accessibilityLarge:
            fontSize = 32.0
        case UIContentSizeCategory.accessibilityExtraLarge:
            fontSize = 36.0
        case UIContentSizeCategory.accessibilityExtraExtraLarge:
            fontSize = 40.0
        case UIContentSizeCategory.accessibilityExtraExtraExtraLarge:
            fontSize = 44.0
        default:
            fontSize = 16.0
        }
        
        return fontSize
    }
    
    class func findTextField(_ view: UIView) -> UITextField? {
//        return view.valueForKey("_searchField") as? UITextField
        for i in 0..<view.subviews.count {
            let subview = view.subviews[i]
            if let textField = subview as? UITextField {
                return textField
            }
            let textField = Common.findTextField(subview)
            if (textField != nil) {
                return textField
            }
        }
        return nil
    }
    
    class func findTableViewIndex(_ view: UIView) -> UIView? {
        for i in 0..<view.subviews.count {
            let subview = view.subviews[i]
            if (type(of: subview).description() == "UITableViewIndex") {
                return subview
            }
            let tableViewIndex = Common.findTableViewIndex(subview)
            if (tableViewIndex != nil) {
                return tableViewIndex
            }
        }
        return nil
    }
    
    class func getIndexWidthForTableView(_ tableView: UITableView, observedTableIndexViewWidth: inout CGFloat?, checkTableIndex: Bool) -> CGFloat {
        if (checkTableIndex && observedTableIndexViewWidth == nil) {
            let tableViewIndex = Common.findTableViewIndex(tableView)
            if (tableViewIndex != nil) {
                observedTableIndexViewWidth = tableViewIndex!.bounds.width
            }
            else {
                observedTableIndexViewWidth = 0
            }
        }
        
        if let width = observedTableIndexViewWidth {
            return (width != 0) ? width: Common.hardcodedTableIndexViewWidth
        }
        return Common.hardcodedTableIndexViewWidth
    }
    
    class func launchQuizletForSet(id: Int64, deadline: DispatchTime, execute work: @escaping @convention(block) () -> Swift.Void) {
        let url = URL(string: "http://quizlet.com/\(id)")
        
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url!, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: {(b) in
                DispatchQueue.main.asyncAfter(deadline: deadline, execute: work)
            })
        } else {
            // Fallback on earlier versions
            UIApplication.shared.openURL(url!)
            DispatchQueue.main.asyncAfter(deadline: deadline, execute: work)
        }
    }
    
    // iPhone 4s, 5, 5s, 6, 6s, 6 Plus, 6s Plus : 15
    // iPad Air, Air 2, Retina : 30
    static var hardcodedTableIndexViewWidth: CGFloat = {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        let minDimension = Swift.min(screenWidth, screenHeight)
        let maxDimension = Swift.max(screenWidth, screenHeight)
        
        if (maxDimension < 850) {
            // iPhone 4s, 5, 5s, 6, 6s, 6 Plus, 6s Plus
            
            // From experimenting on iPhone I know the correct value to be 15
            // smaller values fail for "used... 를" (2nd largest font size)
            // width = 14: fails for "comes after the *noun*..." (2nd largest font size)
            // width = 15: OK!
            // width = 16: fails for "attached to a place and indicates going to a destination" (largest font size)
            // width = 17: fails for "we went to the zoo..." (2nd largest font size)
            
            // From experimenting on iPhone Plus I know the correct value to be 15
            // width = 19, 20, 21, 22, 23: fails for "I also traveled to..."
            // width = 18: fails for user 'overlordb', term "the Chinese dynasty (from 246 BC to 206 BC)..."
            
            return 15
        }
        else {
            // iPad Air, Air 2, Retina
            return 30
        }
        }()
    
    class func toUppercase(_ c: Character) -> Character {
        let up = String(c).uppercased()
        return up[up.startIndex]
    }
    
    class func isAlphaNumeric(_ c: Character) -> Bool {
        let s = String(c)
        let view = s.utf16
        let uc: unichar = view[view.startIndex]
        return CharacterSet.alphanumerics.contains(UnicodeScalar(uc)!)
        
        // Over 4x slower:
        // return String(c).rangeOfCharacterFromSet(NSCharacterSet.alphanumericCharacterSet()) != nil
        
        // 2.5x slower:
        // return NSCharacterSet.alphanumericCharacterSet().characterIsMember(String(c).utf16.first!)
        
        // 1.2x slower:
        // let alphaNumCharSet = NSCharacterSet.alphanumericCharacterSet()
        // for uc in String(c).unicodeScalars {
        //     if (!alphaNumCharSet.longCharacterIsMember(uc.value)) {
        //         return false
        //     }
        // }
        // return true
    }

    class func isWhitespace(_ c: Character) -> Bool {
        let s = String(c)
        let view = s.utf16
        let uc: unichar = view[view.startIndex]
        return CharacterSet.whitespacesAndNewlines.contains(UnicodeScalar(uc)!)
        
        // Over 4x slower:
        // return String(c).rangeOfCharacterFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) != nil
        
        // 1.2x slower
        // let whiteCharSet = NSCharacterSet.whitespaceCharacterSet()
        // for uc in String(c).unicodeScalars {
        //     if (!whiteCharSet.longCharacterIsMember(uc.value)) {
        //         return false
        //     }
        // }
        // return true
    }
    
    class func firstNonWhitespaceCharacter(_ text: String) -> Character? {
        let trimmedText = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return !trimmedText.isEmpty ? trimmedText[trimmedText.startIndex] : nil

        // Can be over 20x slower, depending on the amount of leading whitespace:
        // var firstCharacter: Character? = nil
        // for index in text.startIndex ..< text.endIndex {
        //     let c = text[index]
        //     if (!Common.isWhitespace(c)) {
        //         firstCharacter = c
        //         break
        //     }
        // }
        // return firstCharacter
    }

    class func cloneView(_ view: UIView) -> UIView {
        let archivedData = NSKeyedArchiver.archivedData(withRootObject: view)
        return NSKeyedUnarchiver.unarchiveObject(with: archivedData) as! UIView
    }
}

class UnicharIterator {
    let string: StringWithBoundaries
    var unicharIndex: Int
    var characterIndex: Int
    var characterSubIndex: Int
    let skipWhitespaceOption: Bool
    
    init(string: StringWithBoundaries, options: NSString.CompareOptions) {
        self.string = string
        self.unicharIndex = 0
        self.characterIndex = 0
        self.characterSubIndex = 0
        self.skipWhitespaceOption = options.contains(.WhitespaceInsensitiveSearch)
    }
    
    init(stringAndIndex: UnicharIterator) {
        self.string = stringAndIndex.string
        self.unicharIndex = stringAndIndex.unicharIndex
        self.characterIndex = stringAndIndex.characterIndex
        self.characterSubIndex = stringAndIndex.characterSubIndex
        self.skipWhitespaceOption = stringAndIndex.skipWhitespaceOption
    }
    
    func isEnd() -> Bool {
        skipWhitespace()
        return unicharIndex == string.nsString.length
    }
    
    func isLastCharacter() -> Bool {
        return characterIndex >= (string.characterBoundaries.count - 2)
    }
    
    func currentUnichar() -> unichar {
        return string.nsString.character(at: unicharIndex)
    }
    
    func advance() {
        unicharIndex += 1
        if (unicharIndex == string.characterBoundaries[characterIndex + 1]) {
            characterIndex += 1
            characterSubIndex = 0
        } else {
            characterSubIndex += 1
        }
    }
    
    func isCharacterBoundary() -> Bool {
        return unicharIndex == string.characterBoundaries[characterIndex]
    }
    
    func advanceToCharacterBoundary() {
        if (unicharIndex != string.characterBoundaries[characterIndex]) {
            while (unicharIndex != string.characterBoundaries[characterIndex + 1]) {
                unicharIndex += 1
            }
            characterIndex += 1
            characterSubIndex = 0
        }
    }
    
    func advanceCharacter() {
        characterIndex += 1
        unicharIndex = string.characterBoundaries[characterIndex]
        characterSubIndex = 0
    }
    
    func skipWhitespace() {
        if (skipWhitespaceOption) {
            while (unicharIndex < string.nsString.length && UnicharIterator.isWhitespace(string.nsString.character(at: unicharIndex))) {
                advance()
            }
        }
    }
    
    class func isWhitespace(_ character: unichar) -> Bool {
        return CharacterSet.whitespacesAndNewlines.contains(UnicodeScalar(character)!)
    }
}

class StringWithBoundaries {
    let string: String
    let nsString: NSString
    let characterBoundaries: [Int]
    
    init(string: String) {
        self.string = string
        self.nsString = string as NSString
        characterBoundaries = StringWithBoundaries.calculateCharacterBoundaries(string as NSString)
    }

    init(string: String, characterBoundaries: [Int]) {
        self.string = string
        self.nsString = string as NSString
        self.characterBoundaries = characterBoundaries
    }
    
    func characterRangeToUnicharRange(_ characterRange: NSRange) -> NSRange {
        let start = characterBoundaries[characterRange.location]
        let end = characterBoundaries[characterRange.location + characterRange.length]
        return NSMakeRange(start, end - start)
    }
    
    func characterRangesToUnicharRanges(_ characterRanges: [NSRange]) -> [NSRange] {
        var unicharRanges = [NSRange]()
        for cr in characterRanges {
            let start = characterBoundaries[cr.location]
            let end = characterBoundaries[cr.location + cr.length]
            unicharRanges.append(NSMakeRange(start, end - start))
        }
        return unicharRanges
    }

    class func calculateCharacterBoundaries(_ text: NSString) -> [Int] {
        var index = 0
        var characterBoundaries: [Int] = []
        while (index < text.length) {
            characterBoundaries.append(index)
            index += text.rangeOfComposedCharacterSequence(at: index).length
        }
        characterBoundaries.append(index)
        return characterBoundaries
    }

    // 'sourceString' and 'targetString' should already be lowercased, decomposed, and normalized when calling this function
    static func characterRangesOfUnichars(_ sourceString: StringWithBoundaries, targetString: StringWithBoundaries, options: NSString.CompareOptions = NSString.CompareOptions(rawValue: 0)) -> [NSRange] {
        
        var source = UnicharIterator(string: sourceString, options: options)
        let target = UnicharIterator(string: targetString, options: options)
        if (target.isEnd()) {
            return []
        }
        
        let firstTargetCharacter = target.currentUnichar()
        var ranges = [NSRange]()
        
        while ((source.string.nsString.length - source.unicharIndex) >= target.string.nsString.length) {
            // while (!source.isEnd()) {
            if (source.currentUnichar() == firstTargetCharacter) {
                let sourceSubstring = UnicharIterator(stringAndIndex: source)
                let targetSubstring = UnicharIterator(stringAndIndex: target)
                
                sourceSubstring.advance()
                targetSubstring.advance()
                
                var foundMismatch = false
                var prevSourceSubstringCharacterIndex = source.characterIndex
                
                while (!foundMismatch && !sourceSubstring.isEnd() && !targetSubstring.isEnd()) {
                    prevSourceSubstringCharacterIndex = sourceSubstring.characterIndex
                    foundMismatch = (sourceSubstring.currentUnichar() != targetSubstring.currentUnichar()) ||
                        (!targetSubstring.isLastCharacter() && sourceSubstring.characterSubIndex != targetSubstring.characterSubIndex)
                    sourceSubstring.advance()
                    targetSubstring.advance()
                }
                
                if (!foundMismatch && targetSubstring.isEnd()) {
                    ranges.append(NSMakeRange(source.characterIndex, prevSourceSubstringCharacterIndex - source.characterIndex + 1))
                    source = sourceSubstring
                    source.advanceToCharacterBoundary()
                } else {
                    source.advanceCharacter()
                }
            } else {
                source.advanceCharacter()
            }
        }
        
        return ranges
    }
}

extension NSString.CompareOptions {
    static var WhitespaceInsensitiveSearch: NSString.CompareOptions = NSString.CompareOptions(rawValue: 0x8000)
}

extension String {
    func beginsWith(_ str: String) -> Bool {
        if let range = self.range(of: str) {
            return range.lowerBound == self.startIndex
        }
        return false
    }
    
    func endsWith(_ str: String) -> Bool {
        if let range = self.range(of: str, options: .backwards) {
            return range.upperBound == self.endIndex
        }
        return false
    }
    
    func contains(_ str: String, options: NSString.CompareOptions? = nil) -> Bool {
        if let opt = options {
            return self.range(of: str, options: opt) != nil
        }
        else {
            return self.range(of: str) != nil
        }
    }

    func isWhitespace() -> Bool {
        let string = self as NSString
        for i in 0..<string.length {
            if (!UnicharIterator.isWhitespace(string.character(at: i))) {
                return false
            }
        }
        return true
    }
    
    func trimInlineWhitespace() -> String {
        return self.trimmingCharacters(in: CharacterSet.whitespaces)
    }
    
    func trimWhitespace() -> String {
        return self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    func guessLanguage() -> String? {
        return CFStringTokenizerCopyBestStringLanguage(self as CFString, CFRangeMake(0, 0)) as String
    }
    
    func spellCheckForLanguage(_ lang: String) -> [String]? {
        let textChecker = UITextChecker()
        let range = NSMakeRange(0, (self as NSString).length)
        
        let misspelled = textChecker.rangeOfMisspelledWord(in: self, range: range, startingAt: range.location, wrap: false, language: lang)
        if (misspelled.location == NSNotFound) {
            return nil
        }
        
        let guesses = textChecker.guesses(forWordRange: misspelled, in: self, language: lang)
        if (guesses == nil) {
            return nil
        }
        
        var guessStrings = [String]()
        for g in guesses! {
            guessStrings.append(g )
        }
        return guessStrings
    }

    func decomposeAndNormalize() -> StringWithBoundaries {
        let from = self.decomposedStringWithCanonicalMapping as NSString
        var to = [unichar]()
        var boundaries = [Int]()
        
        var index = 0
        var boundaryIndex = 0
        while (index < from.length) {
            boundaries.append(boundaryIndex)
            let sequenceLength = from.rangeOfComposedCharacterSequence(at: index).length
            for sequenceIndex in index..<(index+sequenceLength) {
                let fromUnichar = from.character(at: sequenceIndex)
                let normalizedUnichars = String.normalizeTable[fromUnichar]
                if (normalizedUnichars != nil) {
                    for u in normalizedUnichars! {
                        to.append(u)
                    }
                    boundaryIndex += normalizedUnichars!.count
                }
                else {
                    to.append(fromUnichar)
                    boundaryIndex += 1
                }
            }
            index += sequenceLength
        }
        boundaries.append(boundaryIndex)
        return StringWithBoundaries(string: NSString(characters: to, length: to.count) as String, characterBoundaries: boundaries)
    }

    fileprivate static let normalizeTable: [unichar: [unichar]] = [
        0x1100: [ 0x3131 ],         // G ᄀ
        0x1101: [ 0x3132 ],         // GG ᄁ
        0x1102: [ 0x3134 ],         // N ᄂ
        0x1103: [ 0x3137 ],         // D ᄃ
        0x1104: [ 0x3137, 0x3137 ], // DD ᄄ
        0x1105: [ 0x3139 ],         // R ᄅ
        0x1106: [ 0x3141 ],         // M ᄆ
        0x1107: [ 0x3142 ],         // B ᄇ
        0x1108: [ 0x3142, 0x3142 ], // BB ᄈ
        0x1109: [ 0x3145 ],         // S ᄉ
        0x110A: [ 0x3145, 0x3145 ], // SS ᄊ
        0x110B: [ 0x3147 ],         //   ᄋ
        0x110C: [ 0x3148 ],         // J ᄌ
        0x110D: [ 0x3148, 0x3148 ], // JJ ᄍ
        0x110E: [ 0x314A ],         // C ᄎ
        0x110F: [ 0x314B ],         // K ᄏ
        0x1110: [ 0x314C ],         // T ᄐ
        0x1111: [ 0x314D ],         // P ᄑ
        0x1112: [ 0x314E ],         // H ᄒ
        
        0x1161: [ 0x314F ],         // A ᅡ
        0x1162: [ 0x3150 ],         // AE ᅢ
        0x1163: [ 0x3151 ],         // YA ᅣ
        0x1164: [ 0x1164 ],         // YAE ᅤ
        0x1165: [ 0x3153 ],         // EO ᅥ
        0x1166: [ 0x3154 ],         // E ᅦ
        0x1167: [ 0x3155 ],         // YEO ᅧ
        0x1168: [ 0x1168 ],         // YE ᅨ
        0x1169: [ 0x3157 ],         // O ᅩ
        0x116A: [ 0x3157, 0x314F ], // WA ᅪ
        0x116B: [ 0x3157, 0x3150 ], // WAE ᅫ
        0x116C: [ 0x3157, 0x3163 ], // OE ᅬ
        0x116D: [ 0x315B ],         // YO ᅭ
        0x116E: [ 0x315C ],         // U ᅮ
        0x116F: [ 0x315C, 0x3153 ], // WEO ᅯ
        0x1170: [ 0x315C, 0x3154 ], // WE ᅰ
        0x1171: [ 0x315C, 0x3163 ], // WI ᅱ
        0x1172: [ 0x3160 ],         // YU ᅲ
        0x1173: [ 0x3161 ],         // EU ᅳ
        0x1174: [ 0x3161, 0x3163 ], // YI ᅴ
        0x1175: [ 0x3163 ],         // I ᅵ
        
        0x11A8: [ 0x3131 ],         // G ᆨ
        0x11A9: [ 0x3131, 0x3131 ], // GG ᆩ
        0x11AA: [ 0x3131, 0x3145 ], // GS ᆪ
        0x11AB: [ 0x3134 ],         // N ᆫ
        0x11AC: [ 0x3134, 0x3148 ], // NJ ᆬ
        0x11AD: [ 0x3134, 0x314E ], // NH ᆭ
        0x11AE: [ 0x3137 ],         // D ᆮ
        0x11AF: [ 0x3139 ],         // L ᆯ
        0x11B0: [ 0x3139, 0x3131 ], // LG ᆰ
        0x11B1: [ 0x3139, 0x3134 ], // LM ᆱ
        0x11B2: [ 0x3139, 0x3142 ], // LB ᆲ
        0x11B3: [ 0x3139, 0x3145 ], // LS ᆳ
        0x11B4: [ 0x3139, 0x314C ], // LT ᆴ
        0x11B5: [ 0x3139, 0x314D ], // LP ᆵ
        0x11B6: [ 0x3139, 0x314E ], // LH ᆶ
        0x11B7: [ 0x3141 ],         // M ᆷ
        0x11B8: [ 0x3142 ],         // B ᆸ
        0x11B9: [ 0x3142, 0x3145 ], // BS ᆹ
        0x11BA: [ 0x3145 ],         // S ᆺ
        0x11BB: [ 0x3145, 0x3145 ], // SS ᆻ
        0x11BC: [ 0x3147 ],         // NG ᆼ
        0x11BD: [ 0x3148 ],         // J ᆽ
        0x11BE: [ 0x314A ],         // C ᆾ
        0x11BF: [ 0x314B ],         // K ᆿ
        0x11C0: [ 0x314C ],         // T ᇀ
        0x11C1: [ 0x314D ],         // P ᇁ
        0x11C2: [ 0x314E ],          // H ᇂ

        0x3132: [ 0x3131, 0x3131 ],  // ㄲ
        0x3138: [ 0x3137, 0x3137 ],  // ㄸ
        0x3143: [ 0x3142, 0x3142 ],  // ㅃ
        0x3146: [ 0x3145, 0x3145 ],  // ㅆ
        0x3149: [ 0x3148, 0x3148 ],  // ㅉ
        0x3158: [ 0x3157, 0x314F ],  // ㅘ
        0x3162: [ 0x3161, 0x3163 ]   // ㅢ
        
        /*
        1	G	ᄀ	ㄱ	&#x1100;
        2	GG	ᄁ	ㄲ	&#x1101;
        3	N	ᄂ	ㄴ	&#x1102;
        4	D	ᄃ	ㄷ	&#x1103;
        5	DD	ᄄ	ㄸ	&#x1104;
        6	R	ᄅ	ㄹ	&#x1105;
        7	M	ᄆ	ㅁ	&#x1106;
        8	B	ᄇ	ㅂ	&#x1107;
        9	BB	ᄈ	ㅃ	&#x1108;
        10	S	ᄉ	ㅅ	&#x1109;
        11	SS	ᄊ	ㅆ	&#x110A;
        12	 	ᄋ	ㅇ	&#x110B;
        13	J	ᄌ	ㅈ	&#x110C;
        14	JJ	ᄍ	ㅉ	&#x110D;
        15	C	ᄎ	ㅊ	&#x110E;
        16	K	ᄏ	ㅋ	&#x110F;
        17	T	ᄐ	ㅌ	&#x1110;
        18	P	ᄑ	ㅍ	&#x1111;
        19	H	ᄒ	ㅎ	&#x1112;
        
        1	A	ᅡ	ㅏ	&#x1161;
        2	AE	ᅢ	ㅐ	&#x1162;
        3	YA	ᅣ	ㅑ	&#x1163;
        4	YAE	ᅤ	ㅒ	&#x1164;
        5	EO	ᅥ	ㅓ	&#x1165;
        6	E	ᅦ	ㅔ	&#x1166;
        7	YEO	ᅧ	ㅕ	ㅕ	&#x1167;
        8	YE	ᅨ	ㅖ	&#x1168;
        9	O	ᅩ	ㅗ	&#x1169;
        10	WA	ᅪ	ㅘ	&#x116A;
        11	WAE	ᅫ	ㅙ	&#x116B;
        12	OE	ᅬ	ㅚ	&#x116C;
        13	YO	ᅭ	ㅛ	&#x116D;
        14	U	ᅮ	ㅜ	&#x116E;
        15	WEO	ᅯ	ㅝ	&#x116F;
        16	WE	ᅰ	ㅞ	&#x1170;
        17	WI	ᅱ	ㅟ	&#x1171;
        18	YU	ᅲ	ㅠ	&#x1172;
        19	EU	ᅳ	ㅡ	&#x1173;
        20	YI	ᅴ	ㅢ	&#x1174;
        21	I	ᅵ	ㅣ	ㅣ	&#x1175;
        
        1	G	ᆨ	ㄱ	&#x11A8;
        2	GG	ᆩ	ㄲ	&#x11A9;
        3	GS	ᆪ	ㄳ	&#x11AA;
        4	N	ᆫ	ㄴ	&#x11AB;
        5	NJ	ᆬ	ㄵ	&#x11AC;
        6	NH	ᆭ	ㄶ	&#x11AD;
        7	D	ᆮ	ㄷ	&#x11AE;
        8	L	ᆯ	ㄹ	&#x11AF;
        9	LG	ᆰ	ㄺ	&#x11B0;
        10	LM	ᆱ	ㄻ	&#x11B1;
        11	LB	ᆲ	ㄼ	&#x11B2;
        12	LS	ᆳ	ㄽ	&#x11B3;
        13	LT	ᆴ	ㄾ	&#x11B4;
        14	LP	ᆵ	ㄿ	&#x11B5;
        15	LH	ᆶ	ㅀ	&#x11B6;
        16	M	ᆷ	ㅁ	&#x11B7;
        17	B	ᆸ	ㅂ	&#x11B8;
        18	BS	ᆹ	ㅄ	&#x11B9;
        19	S	ᆺ	ㅅ	&#x11BA;
        20	SS	ᆻ	ㅆ	&#x11BB;
        21	NG	ᆼ	ㅇ	&#x11BC;
        22	J	ᆽ	ㅈ	&#x11BD;
        23	C	ᆾ	ㅊ	&#x11BE;
        24	K	ᆿ	ㅋ	&#x11BF;
        25	T	ᇀ	ㅌ	&#x11C0;
        26	P	ᇁ	ㅍ	&#x11C1;
        27	H	ᇂ	ㅎ	&#x11C2;
        
        6F2457	3131	E384B1	ㄱ	Korean hangul
        6F2458	3134	E384B4	ㄴ	Korean hangul
        6F2459	3137	E384B7	ㄷ	Korean hangul
        6F245A	3139	E384B9	ㄹ	Korean hangul
        6F245B	3141	E38581	ㅁ	Korean hangul
        6F245C	3142	E38582	ㅂ	Korean hangul
        6F245D	3145	E38585	ㅅ	Korean hangul
        6F245E	3147	E38587	ㅇ	Korean hangul
        6F245F	3148	E38588	ㅈ	Korean hangul
        6F2460	314A	E3858A	ㅊ	Korean hangul
        6F2461	314B	E3858B	ㅋ	Korean hangul
        6F2462	314C	E3858C	ㅌ	Korean hangul
        6F2463	314D	E3858D	ㅍ	Korean hangul
        6F2464	314E	E3858E	ㅎ	Korean hangul
        6F2465	3132	E384B2	ㄲ	Korean hangul
        6F2469	3138	E384B8	ㄸ	Korean hangul
        6F246E	3143	E38583	ㅃ	Korean hangul
        6F2470	3146	E38586	ㅆ	Korean hangul
        6F2471	3149	E38589	ㅉ	Korean hangul
        6F2472	314F	E3858F	ㅏ	Korean hangul
        6F2473	3150	E38590	ㅐ	Korean hangul
        6F2474	3151	E38591	ㅑ	Korean hangul
        6F2476	3153	E38593	ㅓ	Korean hangul
        6F2477	3154	E38594	ㅔ	Korean hangul
        6F2478	3155	E38595	ㅕ	Korean hangul
        6F247A	3157	E38597	ㅗ	Korean hangul
        6F247B	3158	E38598	ㅘ	Korean hangul
        6F247E	315B	E3859B	ㅛ	Korean hangul
        6F2521	315C	E3859C	ㅜ	Korean hangul		
        6F2525	3160	E385A0	ㅠ	Korean hangul		
        6F2526	3161	E385A1	ㅡ	Korean hangul		
        6F2527	3162	E385A2	ㅢ	Korean hangul		
        6F2528	3163	E385A3	ㅣ	Korean hangul		
        */
    ]
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
