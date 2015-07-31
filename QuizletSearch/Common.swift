//
//  Common.swift
//  QuizletSearch
//
//  Created by Doug Stein on 7/28/15.
//  Copyright (c) 2015 Doug Stein. All rights reserved.
//

import UIKit


class Common {
    static let isSampleMode = false
    
    class func preferredSystemFontForTextStyle(textStyle: String) -> UIFont? {
        // choose the font size
        let fontSize: CGFloat = preferredSystemFontSize()

        // choose the font weight
        if (textStyle == UIFontTextStyleHeadline || textStyle == UIFontTextStyleSubheadline) {
            return UIFont.boldSystemFontOfSize(fontSize)
        } else {
            return UIFont.systemFontOfSize(fontSize)
        }
    }
    
    class func preferredSystemFontSize() -> CGFloat {
        let fontSize: CGFloat
        
        switch (UIApplication.sharedApplication().preferredContentSizeCategory) {
        case UIContentSizeCategoryExtraSmall:
            fontSize = 12.0
        case UIContentSizeCategorySmall:
            fontSize = 12.0
        case UIContentSizeCategoryMedium:
            fontSize = 13.0
        case UIContentSizeCategoryLarge:
            fontSize = 14.0
        case UIContentSizeCategoryExtraLarge:
            fontSize = 16.0
        case UIContentSizeCategoryExtraExtraLarge:
            fontSize = 18.0
        case UIContentSizeCategoryExtraExtraExtraLarge:
            fontSize = 18.0
        default:
            fontSize = 12.0
        }
        
        return fontSize
    }

    class func preferredSearchFontForTextStyle(textStyle: String) -> UIFont? {
        // choose the font size
        let fontSize: CGFloat = preferredSearchFontSize()
        
        // choose the font weight
        if (textStyle == UIFontTextStyleHeadline || textStyle == UIFontTextStyleSubheadline) {
            return UIFont(name: "Arial-Bold", size: fontSize)
        } else {
            return UIFont(name: "Arial", size: fontSize)
        }
    }
    
    class func preferredSearchFontSize() -> CGFloat {
        let fontSize: CGFloat
        
        switch (UIApplication.sharedApplication().preferredContentSizeCategory) {
        case UIContentSizeCategoryExtraSmall:
            fontSize = 12.0
        case UIContentSizeCategorySmall:
            fontSize = 14.0
        case UIContentSizeCategoryMedium:
            fontSize = 16.0
        case UIContentSizeCategoryLarge:
            fontSize = 18.0
        case UIContentSizeCategoryExtraLarge:
            fontSize = 20.0
        case UIContentSizeCategoryExtraExtraLarge:
            fontSize = 22.0
        case UIContentSizeCategoryExtraExtraExtraLarge:
            fontSize = 24.0
        default:
            fontSize = 16.0
        }
        
        return fontSize
    }
    
    class func findTextFieldAndUpdateFont(view: UIView) {
        for i in 0..<view.subviews.count {
            if let subview = view.subviews[i] as? UIView {
                if let textField = subview as? UITextField {
                    textField.font = preferredSearchFontForTextStyle(UIFontTextStyleBody)
                }
                Common.findTextFieldAndUpdateFont(subview)
            }
        }
    }
    
    // TODO: account for converstion of String to NSAttributedString, does not work for unicode
    class func stringRangeToNSRange(text: String, range: Range<String.Index>) -> NSRange {
        let start = distance(text.startIndex, range.startIndex)
        let length = distance(range.startIndex, range.endIndex)
        return NSMakeRange(start, length)
    }
}

extension NSStringCompareOptions {
    static var WhitespaceInsensitiveSearch: NSStringCompareOptions = NSStringCompareOptions(rawValue: 0x8000)
}

extension String {
    init(sep: String, _ lines: String...) {
        self = ""
        for (idx, item) in enumerate(lines) {
            self += "\(item)"
            if idx < lines.count-1 {
                self += sep
            }
        }
    }
    
    init(_ lines: String...) {
        self = ""
        for (idx, item) in enumerate(lines) {
            self += "\(item)"
            if idx < lines.count-1 {
                self += "\n"
            }
        }
    }
    
    private class StringAndIndex {
        let string: String
        var index: String.Index
        let skipWhitespaceOption: Bool
        
        init(string: String, options: NSStringCompareOptions) {
            self.string = string
            self.index = string.startIndex
            self.skipWhitespaceOption = (options.rawValue & NSStringCompareOptions.WhitespaceInsensitiveSearch.rawValue) != 0
        }
        
        init(stringAndIndex: StringAndIndex) {
            self.string = stringAndIndex.string
            self.index = stringAndIndex.index
            self.skipWhitespaceOption = stringAndIndex.skipWhitespaceOption
        }
        
        func isEnd() -> Bool {
            skipWhitespace()
            return index == string.endIndex
        }
        
        func currentCharacter() -> Character {
            return string[index]
        }
        
        func isLastCharacter() -> Bool {
            var next = index.successor()
            if (skipWhitespaceOption) {
                next = StringAndIndex.skipWhitespace(string, index: next)
            }
            return (next == string.endIndex)
        }
        
        func advance() {
            index = index.successor()
        }
        
        func skipWhitespace() {
            if (skipWhitespaceOption) {
                index = StringAndIndex.skipWhitespace(string, index: index)
            }
        }
        
        class func skipWhitespace(string: String, var index: String.Index) -> String.Index {
            while (index < string.endIndex && StringAndIndex.isWhitespace(string[index])) {
                index = index.successor()
            }
            return index
        }

        class func isWhitespace(character: Character) -> Bool {
            var scalars = String(character).unicodeScalars
            if (scalars.startIndex.successor() == scalars.endIndex) {
                return NSCharacterSet.whitespaceAndNewlineCharacterSet().characterIsMember(
                    unichar(scalars[scalars.startIndex].value))
            } else {
                return false
            }
        }
    }
    
    func isWhitespace() -> Bool {
        for i in self.startIndex..<self.endIndex {
            if (!StringAndIndex.isWhitespace(self[i])) {
                return false
            }
        }
        return true
    }
    
    func rangeOfStringWithOptions(aString: String, options: NSStringCompareOptions) -> Range<String.Index>? {
        return rangeOfString(aString, options: options)
    }
    
    func rangeOfStringWithWhitespace(var targetString: String, options: NSStringCompareOptions = NSStringCompareOptions(0)) -> Range<String.Index>? {

        var sourceString = self
        if ((options.rawValue & NSStringCompareOptions.CaseInsensitiveSearch.rawValue) != 0) {
            sourceString = sourceString.lowercaseString
            targetString = targetString.lowercaseString
        }
        
        var source = StringAndIndex(string: sourceString, options: options)
        var target = StringAndIndex(string: targetString, options: options)
        if (target.isEnd()) {
            return nil
        }

        var firstTargetCharacter = target.currentCharacter()
        
        while (!source.isEnd()) {
            var sourceCharacter: Character = source.currentCharacter()
            var targetCharacter: Character = firstTargetCharacter

            if (sourceCharacter == targetCharacter) {
                    var sourceSubstring = StringAndIndex(stringAndIndex: source)
                    var targetSubstring = StringAndIndex(stringAndIndex: target)
                
                    sourceSubstring.advance()
                    targetSubstring.advance()
                
                    var foundMismatch = false
                    while (!foundMismatch && !sourceSubstring.isEnd() && !targetSubstring.isEnd()) {
                        if (sourceSubstring.currentCharacter() != targetSubstring.currentCharacter()) {
                            foundMismatch = true
                        }
                        sourceSubstring.advance()
                        targetSubstring.advance()
                    }
                    if (!foundMismatch && targetSubstring.isEnd()) {
                        return Range<String.Index>(start: source.index, end: sourceSubstring.index)
                    }
            }
            source.advance()
        }
        return nil
    }

    func rangeOfOverlappingUnicharsInString(var targetString: String, options: NSStringCompareOptions = NSStringCompareOptions(0)) -> Range<String.Index>? {

        var sourceString = self
        if ((options.rawValue & NSStringCompareOptions.CaseInsensitiveSearch.rawValue) != 0) {
            sourceString = sourceString.lowercaseString
            targetString = targetString.lowercaseString
        }
        
        sourceString = sourceString.decomposedStringWithCanonicalMapping
        targetString = targetString.decomposedStringWithCanonicalMapping

        var source = StringAndIndex(string: sourceString, options: options)
        var target = StringAndIndex(string: targetString, options: options)
        if (target.isEnd()) {
            return nil
        }

        var firstTargetCharacter = target.currentCharacter()
        var startIndex = 0
        
        while (!source.isEnd()) {
            var sourceCharacter = source.currentCharacter()
            var targetCharacter = firstTargetCharacter

            if (target.isLastCharacter()
                ? String.isUnicharPrefix(sourceCharacter, targetCharacter)
                : sourceCharacter == targetCharacter) {

                var sourceSubstring = StringAndIndex(stringAndIndex: source)
                var targetSubstring = StringAndIndex(stringAndIndex: target)
                    
                sourceSubstring.advance()
                targetSubstring.advance()
                var endIndex = startIndex + 1
                
                var foundMismatch = false
                while (!foundMismatch && !sourceSubstring.isEnd() && !targetSubstring.isEnd()) {
                    if (targetSubstring.isLastCharacter()
                        ? !String.isUnicharPrefix(sourceSubstring.currentCharacter(), targetSubstring.currentCharacter())
                        : sourceSubstring.currentCharacter() != targetSubstring.currentCharacter()) {

                        foundMismatch = true
                    }
                    sourceSubstring.advance()
                    targetSubstring.advance()
                    endIndex++
                }
                if (!foundMismatch && targetSubstring.isEnd()) {
                    var originalStartIndex = advance(self.startIndex, startIndex)
                    var originalEndIndex = advance(originalStartIndex, endIndex - startIndex)
                    return Range<String.Index>(start: originalStartIndex, end: originalEndIndex)
                }
            }
            source.advance()
            startIndex++
        }
        return nil
    }
    
    private static func isUnicharPrefix(sourceCharacter: Character, _ targetCharacter: Character) -> Bool {
        if (sourceCharacter == targetCharacter) {
            return true
        }
        var sourceScalars = String(sourceCharacter).unicodeScalars
        var targetScalars = String(targetCharacter).unicodeScalars
        var sourceIndex = sourceScalars.startIndex
        var targetIndex = targetScalars.startIndex
        var foundMismatch = false
        
        while (!foundMismatch && sourceIndex < sourceScalars.endIndex && targetIndex < targetScalars.endIndex) {
            if (String.normalize(sourceScalars[sourceIndex].value) != (String.normalize(targetScalars[targetIndex].value))) {
                foundMismatch = true
            }
            sourceIndex = sourceIndex.successor()
            targetIndex = targetIndex.successor()
        }
        
        return !foundMismatch && targetIndex == targetScalars.endIndex
    }
    
    private static func normalize(unicodeScalarValue: UInt32) -> UInt32 {
        var n = String.normalizeTable[unicodeScalarValue]
        if (n == nil) {
            n = unicodeScalarValue
        }
        return n!
    }
    
    private static let normalizeTable: [UInt32: UInt32] = [
        0x1100: 0x3131, // G ᄀ
        0x1101: 0x3132, // GG ᄁ
        0x1102: 0x3134, // N ᄂ
        0x1103: 0x3137, // D ᄃ
        0x1104: 0x3138, // DD ᄄ
        0x1105: 0x3139, // R ᄅ
        0x1106: 0x3141, // M ᄆ
        0x1107: 0x3142, // B ᄇ
        0x1108: 0x3143, // BB ᄈ
        0x1109: 0x3145, // S ᄉ
        0x110A: 0x3146, // SS ᄊ
        0x110B: 0x3147, //   ᄋ
        0x110C: 0x3148, // J ᄌ
        0x110D: 0x3149, // JJ ᄍ
        0x110E: 0x314A, // C ᄎ
        0x110F: 0x314B, // K ᄏ
        0x1110: 0x314C, // T ᄐ
        0x1111: 0x314D, // P ᄑ
        0x1112: 0x314E, // H ᄒ
        
        0x1161: 0x314F, // A ᅡ
        0x1162: 0x3150, // AE ᅢ
        0x1163: 0x3151, // YA ᅣ
        // 0x1164: 0x1164, YAE ᅤ
        0x1165: 0x3153, // EO ᅥ
        0x1166: 0x3154, // E ᅦ
        0x1167: 0x3155, // YEO ᅧ
        // 0x1168: 0x1168, YE ᅨ
        0x1169: 0x3157, // O ᅩ
        0x116A: 0x3158, // WA ᅪ
        // 0x116B: 0x116B, WAE ᅫ
        // 0x116C: 0x116C, OE ᅬ
        0x116D: 0x315B, // YO ᅭ
        0x116E: 0x315C, // U ᅮ
        // 0x116F: 0x116F, WEO ᅯ
        // 0x1170: 0x1170, WE ᅰ
        // 0x1171: 0x1171, WI ᅱ
        0x1172: 0x3160, // YU ᅲ
        0x1173: 0x3161, // EU ᅳ
        0x1174: 0x3162, // YI ᅴ
        0x1175: 0x3163, // I ᅵ
        
        0x11A8: 0x3131, // G ᆨ
        0x11A9: 0x3132, // GG ᆩ
        // 0x11AA: 0x11AA, GS ᆪ
        0x11AB: 0x3134, // N ᆫ
        // 0x11AC: 0x11AC, NJ ᆬ
        // 0x11AD: 0x11AD, NH ᆭ
        0x11AE: 0x3137, // D ᆮ
        0x11AF: 0x3139, // L ᆯ
        // 0x11B0: 0x11B0, LG ᆰ
        // 0x11B1: 0x11B1, LM ᆱ
        // 0x11B2: 0x11B2, LB ᆲ
        // 0x11B3: 0x11B3, LS ᆳ
        // 0x11B4: 0x11B4, LT ᆴ
        // 0x11B5: 0x11B5, LP ᆵ
        // 0x11B6: 0x11B6, LH ᆶ
        0x11B7: 0x3141, // M ᆷ
        0x11B8: 0x3142, // B ᆸ
        // 0x11B9: 0x11B9, BS ᆹ
        0x11BA: 0x3145, // S ᆺ
        0x11BB: 0x3146, // SS ᆻ
        0x11BC: 0x3147, // NG ᆼ
        0x11BD: 0x3148, // J ᆽ
        0x11BE: 0x314A, // C ᆾ
        0x11BF: 0x314B, // K ᆿ
        0x11C0: 0x314C, // T ᇀ
        0x11C1: 0x314D, // P ᇁ
        0x11C2: 0x314E, // H ᇂ

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
