//
//  TwicketSegmentedControl.swift
//  TwicketSegmentedControlDemo
//
//  Created by Pol Quintana on 7/11/15.
//  Copyright © 2015 Pol Quintana. All rights reserved.
//

import UIKit

// Add @objc to workaround bug: 'IBOutlet' property cannot have non-'@objc' protocol type 'TwicketSegmentedControlDelegate'
@objc public protocol TwicketSegmentedControlDelegate: class {
    func didSelect(_ segmentIndex: Int)
}

@IBDesignable

open class TwicketSegmentedControl: UIControl {
    open static let height: CGFloat = Constants.height + Constants.topBottomMargin * 2
    
    static func colorFromRGB(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) -> UIColor {
        func amount(_ amount: CGFloat, with alpha: CGFloat) -> CGFloat {
            return (1 - alpha) * 255 + alpha * amount
        }
        
        let red = amount(red, with: alpha)/255
        let green = amount(green, with: alpha)/255
        let blue = amount(blue, with: alpha)/255
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
    
    static func addShadow(_ view: UIView, with color: UIColor) {
        view.layer.shadowColor = color.cgColor
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.7
        view.layer.shadowOffset = CGSize(width: 0, height: 5)
    }

    fileprivate struct Constants {
        static let height: CGFloat = 30
        static let topBottomMargin: CGFloat = 5
        static let topBottomInset: CGFloat = 5
        static let leadingTrailingMargin: CGFloat = 10
    }
    
    class SliderView: UIView {
        // MARK: - Properties
        fileprivate let sliderMaskView = UIView()
        
        var cornerRadius: CGFloat! {
            didSet {
                layer.cornerRadius = cornerRadius
                sliderMaskView.layer.cornerRadius = cornerRadius
            }
        }
        
        override var frame: CGRect {
            didSet {
                sliderMaskView.frame = frame
            }
        }
        
        override var center: CGPoint {
            didSet {
                sliderMaskView.center = center
            }
        }
        
        init() {
            super.init(frame: .zero)
            setup()
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            setup()
        }
        
        private func setup() {
            layer.masksToBounds = true
            sliderMaskView.backgroundColor = .black
            TwicketSegmentedControl.addShadow(sliderMaskView, with: .black)
        }
    }
    
    struct SegmentItem {
        var text: String?
        var defaultImage: UIImage?
        var highlightImage: UIImage?
        var imageSize: CGSize
        var imageInsets: CGRect
        
        func isEmpty() -> Bool {
            return text == nil && defaultImage == nil && highlightImage == nil && imageSize == CGSize.zero && imageInsets == CGRect.zero
        }
        
        func hasImages() -> Bool {
            return defaultImage != nil || highlightImage != nil
        }
    }

    @IBOutlet open weak var delegate: TwicketSegmentedControlDelegate!
    
    @IBInspectable open var defaultColor: UIColor = TwicketSegmentedControl.colorFromRGB(red: 9, green: 26, blue: 51, alpha: 0.4) {
        didSet {
            updateTextColor(with: defaultColor, selected: false)
        }
    }
    
    @IBInspectable open var highlightColor: UIColor = UIColor.white {
        didSet {
            updateTextColor(with: highlightColor, selected: true)
        }
    }
    
    @IBInspectable open var segmentColor: UIColor = TwicketSegmentedControl.colorFromRGB(red: 237, green: 242, blue: 247, alpha: 0.7) {
        didSet {
            backgroundView.backgroundColor = segmentColor
        }
    }
    
    @IBInspectable open var sliderColor: UIColor = TwicketSegmentedControl.colorFromRGB(red: 44, green: 131, blue: 255) {
        didSet {
            selectedContainerView.backgroundColor = sliderColor
        }
    }
    
    open var font: UIFont = UIFont.systemFont(ofSize: 15) { // , weight: UIFontWeightMedium) {
        didSet {
            updateFont(with: font)
        }
    }
    
    @IBInspectable var fontSize: CGFloat = 15.0 {
        didSet {
            self.font = UIFont.systemFont(ofSize: fontSize)
        }
    }
    
    @IBInspectable var text0: String? {
        get { return inspectableItems[0].text }
        set (newText) { inspectableItems[0].text = newText ; updateSegments() }
    }
    
    @IBInspectable var text1: String? {
        get { return inspectableItems[1].text }
        set (newText) { inspectableItems[1].text = newText ; updateSegments() }
    }
    
    @IBInspectable var text2: String? {
        get { return inspectableItems[2].text }
        set (newText) { inspectableItems[2].text = newText ; updateSegments() }
    }
    
    @IBInspectable var text3: String? {
        get { return inspectableItems[3].text }
        set (newText) { inspectableItems[3].text = newText ; updateSegments() }
    }
    
    open var lineBreakMode: NSLineBreakMode = .byTruncatingMiddle {
        didSet {
            updateLineBreakMode(with: lineBreakMode)
        }
    }
    
    @IBInspectable var lineBreak: Int {
        get {
            return self.lineBreakMode.rawValue
        }
        set (position) {
            self.lineBreakMode = NSLineBreakMode(rawValue: position) ?? .byTruncatingMiddle
        }
    }
    
    @IBInspectable var contentInsets: CGRect = CGRect.zero {
        didSet {
            updateContentInsets(with: contentInsets)
        }
    }
    
    @IBInspectable var titleInsets: CGRect = CGRect.zero {
        didSet {
            updateTitleInsets(with: contentInsets)
        }
    }
    
    @IBInspectable var defaultImage0: UIImage? {
        get { return inspectableItems[0].defaultImage }
        set (newImage) { inspectableItems[0].defaultImage = newImage ; updateSegments() }
    }
    
    @IBInspectable var defaultImage1: UIImage? {
        get { return inspectableItems[1].defaultImage }
        set (newImage) { inspectableItems[1].defaultImage = newImage ; updateSegments() }
    }
    
    @IBInspectable var defaultImage2: UIImage? {
        get { return inspectableItems[2].defaultImage }
        set (newImage) { inspectableItems[2].defaultImage = newImage ; updateSegments() }
    }
    
    @IBInspectable var defaultImage3: UIImage? {
        get { return inspectableItems[3].defaultImage }
        set (newImage) { inspectableItems[3].defaultImage = newImage ; updateSegments() }
    }
    
    @IBInspectable var highlightImg0: UIImage? {
        get { return inspectableItems[0].highlightImage }
        set (newImage) { inspectableItems[0].highlightImage = newImage ; updateSegments() }
    }
    
    @IBInspectable var highlightImg1: UIImage? {
        get { return inspectableItems[1].highlightImage }
        set (newImage) { inspectableItems[1].highlightImage = newImage ; updateSegments() }
    }
    
    @IBInspectable var highlightImg2: UIImage? {
        get { return inspectableItems[2].highlightImage }
        set (newImage) { inspectableItems[2].highlightImage = newImage ; updateSegments() }
    }
    
    @IBInspectable var highlightImg3: UIImage? {
        get { return inspectableItems[3].highlightImage }
        set (newImage) { inspectableItems[3].highlightImage = newImage ; updateSegments() }
    }
    
    @IBInspectable var imageSize0: CGSize {
        get { return inspectableItems[0].imageSize }
        set (newSize) { inspectableItems[0].imageSize = newSize ; updateSegments() }
    }
    
    @IBInspectable var imageSize1: CGSize {
        get { return inspectableItems[1].imageSize }
        set (newSize) { inspectableItems[1].imageSize = newSize ; updateSegments() }
    }
    
    @IBInspectable var imageSize2: CGSize {
        get { return inspectableItems[2].imageSize }
        set (newSize) { inspectableItems[2].imageSize = newSize ; updateSegments() }
    }
    
    @IBInspectable var imageSize3: CGSize {
        get { return inspectableItems[3].imageSize }
        set (newSize) { inspectableItems[3].imageSize = newSize ; updateSegments() }
    }
    
    @IBInspectable var imageInsets0: CGRect {
        get { return inspectableItems[0].imageInsets }
        set (newSize) { inspectableItems[0].imageInsets = newSize ; updateSegments() }
    }
    
    @IBInspectable var imageInsets1: CGRect {
        get { return inspectableItems[1].imageInsets }
        set (newSize) { inspectableItems[1].imageInsets = newSize ; updateSegments() }
    }
    
    @IBInspectable var imageInsets2: CGRect {
        get { return inspectableItems[2].imageInsets }
        set (newSize) { inspectableItems[2].imageInsets = newSize ; updateSegments() }
    }
    
    @IBInspectable var imageInsets3: CGRect {
        get { return inspectableItems[3].imageInsets }
        set (newSize) { inspectableItems[3].imageInsets = newSize ; updateSegments() }
    }
    
    private var inspectableItems = [SegmentItem](
        repeating: SegmentItem(text: nil, defaultImage: nil, highlightImage: nil, imageSize: CGSize.zero, imageInsets: CGRect.zero), count: 4)
    
    private(set) open var selectedSegmentIndex: Int = 0
    
    fileprivate var segments: [SegmentItem] = []
    
    fileprivate var numberOfSegments: Int {
        return segments.count
    }
    
    fileprivate var segmentWidth: CGFloat {
        return self.backgroundView.frame.width / CGFloat(numberOfSegments)
    }
    
    fileprivate var correction: CGFloat = 0
    
    fileprivate lazy var containerView: UIView = UIView()
    fileprivate lazy var backgroundView: UIView = UIView()
    fileprivate lazy var selectedContainerView: UIView = UIView()
    fileprivate lazy var sliderView: SliderView = SliderView()
    
    private var hasImages = false
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private var awake = false
    
    override open func awakeFromNib() {
        awake = true
        updateSegments()
    }
    
    override open func prepareForInterfaceBuilder() {
        awake = true
        updateSegments()
    }
    
    // MARK: Setup
    
    fileprivate func setup() {
        addSubview(containerView)
        containerView.addSubview(backgroundView)
        containerView.addSubview(selectedContainerView)
        containerView.addSubview(sliderView)
        
        selectedContainerView.layer.mask = sliderView.sliderMaskView.layer
        addTapGesture()
        addDragGesture()
    }
    
    private func updateSegments() {
        if (!awake) {
            return
        }
        
        var length = 0
        for i in (0..<4).reversed() {
            if (!inspectableItems[i].isEmpty()) {
                length = i + 1
                break
            }
        }
        
        var items: [SegmentItem] = []
        for i in 0..<length {
            items.append(inspectableItems[i])
        }
        
        setSegmentItems(items)
    }
    
    func setSegmentItems(_ segments: [SegmentItem]) {
        self.segments = segments

        hasImages = false
        for item in segments {
            hasImages = hasImages || item.hasImages()
        }
        
        configureViews()
        clearLabels()
        
        for (index, item) in segments.enumerated() {
            let baseLabel = createImageLabel(with: item, at: index, selected: false)
            let selectedLabel = createImageLabel(with: item, at: index, selected: true)
            backgroundView.addSubview(baseLabel)
            selectedContainerView.addSubview(selectedLabel)
        }
        
        setupAutoresizingMasks()
    }
    
    fileprivate func configureViews() {
        if (hasImages) {
            containerView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        }
        else {
            containerView.frame = CGRect(x: Constants.leadingTrailingMargin,
                                         y: Constants.topBottomMargin,
                                         width: bounds.width - Constants.leadingTrailingMargin * 2,
                                         height: bounds.height - Constants.topBottomMargin * 2)
        }
        
        let frame = containerView.bounds
        backgroundView.frame = frame
        selectedContainerView.frame = frame
        sliderView.frame = CGRect(x: 0, y: 0, width: segmentWidth, height: backgroundView.frame.height)
        
        let cornerRadius = hasImages ? 0 : backgroundView.frame.height / 2
        [backgroundView, selectedContainerView].forEach { $0.layer.cornerRadius = cornerRadius }
        sliderView.cornerRadius = cornerRadius
        
        backgroundView.backgroundColor = segmentColor
        selectedContainerView.backgroundColor = sliderColor
        
        TwicketSegmentedControl.addShadow(selectedContainerView, with: sliderColor)
    }
    
    fileprivate func setupAutoresizingMasks() {
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        selectedContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sliderView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleWidth, .flexibleHeight]
    }
    
    // MARK: Labels
    
    fileprivate func clearLabels() {
        backgroundView.subviews.forEach { $0.removeFromSuperview() }
        selectedContainerView.subviews.forEach { $0.removeFromSuperview() }
    }
    
    fileprivate func createLabel(with text: String?, at index: Int, selected: Bool) -> UILabel {
        let rect = CGRect(x: CGFloat(index) * segmentWidth, y: 0, width: segmentWidth, height: backgroundView.frame.height)
        let label = UILabel(frame: rect)
        label.text = text
        label.textAlignment = .center
        label.textColor = selected ? highlightColor : defaultColor
        label.font = font
        label.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleWidth]
        return label
    }
    
    fileprivate func createImageLabel(with item: SegmentItem, at index: Int, selected: Bool) -> ImageLabelButton {
        let rect = CGRect(x: CGFloat(index) * segmentWidth, y: 0, width: segmentWidth, height: backgroundView.frame.height)
        let label = ImageLabelButton(frame: rect)
        label.setTitle(item.text, for: UIControlState.normal)
        label.setImage(selected ? (item.highlightImage ?? item.defaultImage) : item.defaultImage, for: UIControlState.normal)
        label.imageSize = item.imageSize
        label.setTitleColor(selected ? highlightColor : defaultColor, for: UIControlState.normal)
        label.titleLabel?.font = font
        label.titleLabel?.lineBreakMode = lineBreakMode
        label.contentEdgeInsets = UIEdgeInsets(top: contentInsets.origin.y, left: contentInsets.origin.x,
                                               bottom: contentInsets.size.height, right: contentInsets.size.width)
        label.imageEdgeInsets = UIEdgeInsets(top: item.imageInsets.origin.y, left: item.imageInsets.origin.x,
                                             bottom: item.imageInsets.size.height, right: item.imageInsets.size.width)
        label.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleWidth, .flexibleHeight]
        return label
    }
    
    // Intercept touch events to the button and propagate to the parent instead, otherwise
    // tapping to switch does not work because the button consumes the event
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        var hitView: UIView? = super.hitTest(point, with: event)
        if (hitView is ImageLabelButton) {
            hitView = hitView?.superview
        }
        return hitView
    }
    
    fileprivate func updateTextColor(with color: UIColor, selected: Bool) {
        let containerView = selected ? selectedContainerView : backgroundView
        containerView.subviews.forEach { ($0 as? ImageLabelButton)?.titleLabel?.textColor = color }
    }
    
    fileprivate func updateFont(with font: UIFont) {
        selectedContainerView.subviews.forEach { ($0 as? ImageLabelButton)?.titleLabel?.font = font }
        backgroundView.subviews.forEach { ($0 as? ImageLabelButton)?.titleLabel?.font = font }
    }
    
    fileprivate func updateLineBreakMode(with lineBreakMode: NSLineBreakMode) {
        selectedContainerView.subviews.forEach { ($0 as? ImageLabelButton)?.titleLabel?.lineBreakMode = lineBreakMode }
        backgroundView.subviews.forEach { ($0 as? ImageLabelButton)?.titleLabel?.lineBreakMode = lineBreakMode }
    }
    
    fileprivate func updateContentInsets(with insets: CGRect) {
        let edgeInsets = UIEdgeInsets(top: insets.origin.y, left: insets.origin.x, bottom: insets.size.height, right: insets.size.width)
        selectedContainerView.subviews.forEach { ($0 as? ImageLabelButton)?.contentEdgeInsets = edgeInsets }
        backgroundView.subviews.forEach { ($0 as? ImageLabelButton)?.contentEdgeInsets = edgeInsets }
    }
    
    fileprivate func updateTitleInsets(with insets: CGRect) {
        let edgeInsets = UIEdgeInsets(top: insets.origin.y, left: insets.origin.x, bottom: insets.size.height, right: insets.size.width)
        selectedContainerView.subviews.forEach { ($0 as? ImageLabelButton)?.titleEdgeInsets = edgeInsets }
        backgroundView.subviews.forEach { ($0 as? ImageLabelButton)?.titleEdgeInsets = edgeInsets }
    }
    
    override open var intrinsicContentSize: CGSize {
        let topBottomInset: CGFloat
        if (hasImages) {
            topBottomInset = Constants.topBottomInset * 2
        }
        else {
            topBottomInset = Constants.topBottomInset * 4
        }
        
        var size = CGSize(width: 0, height: 0)
        var count = 0

        for view in backgroundView.subviews {
            let labelSize = view.intrinsicContentSize
            size.width = max(labelSize.width, size.width)
            size.height = max(labelSize.height + topBottomInset, size.height)
            count += 1
        }
        for view in selectedContainerView.subviews {
            let labelSize = view.intrinsicContentSize
            size.width = max(labelSize.width, size.width)
            size.height = max(labelSize.height + topBottomInset, size.height)
        }

        size.width = size.width * CGFloat(count)
        
        if (!hasImages) {
            size.width += Constants.leadingTrailingMargin * 2
            size.height += Constants.topBottomMargin * 2
        }
        return size
    }
    
    // MARK: Tap gestures
    
    fileprivate func addTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
    }
    
    fileprivate func addDragGesture() {
        let drag = UIPanGestureRecognizer(target: self, action: #selector(didPan))
        sliderView.addGestureRecognizer(drag)
    }
    
    @objc fileprivate func didTap(tapGesture: UITapGestureRecognizer) {
        moveToNearestPoint(basedOn: tapGesture)
    }
    
    @objc fileprivate func didPan(panGesture: UIPanGestureRecognizer) {
        switch panGesture.state {
        case .cancelled, .ended, .failed:
            moveToNearestPoint(basedOn: panGesture, velocity: panGesture.velocity(in: sliderView))
        case .began:
            correction = panGesture.location(in: sliderView).x - sliderView.frame.width/2
        case .changed:
            let location = panGesture.location(in: self)
            sliderView.center.x = location.x - correction
        case .possible: ()
        }
    }
    
    // MARK: Slider position
    
    fileprivate func moveToNearestPoint(basedOn gesture: UIGestureRecognizer, velocity: CGPoint? = nil) {
        var location = gesture.location(in: self)
        if let velocity = velocity {
            let offset = velocity.x / 12
            location.x += offset
        }
        let index = segmentIndex(for: location)
        move(to: index)
        delegate?.didSelect(index)
    }
    
    open func move(to index: Int) {
        let correctOffset = center(at: index)
        animate(to: correctOffset)
        
        selectedSegmentIndex = index
    }
    
    fileprivate func segmentIndex(for point: CGPoint) -> Int {
        if (sliderView.frame.width == 0) {
            return 0
        }
        var index = Int(point.x / sliderView.frame.width)
        if index < 0 { index = 0 }
        if index > numberOfSegments - 1 { index = numberOfSegments - 1 }
        return index
    }
    
    fileprivate func center(at index: Int) -> CGFloat {
        let xOffset = CGFloat(index) * sliderView.frame.width + sliderView.frame.width / 2
        return xOffset
    }
    
    fileprivate func animate(to position: CGFloat) {
        UIView.animate(withDuration: 0.2) {
            self.sliderView.center.x = position
        }
    }
}
