//
//  MagicLabel.swift
//  MagicLabel
//
//  Created by 安然 on 2017/6/21.
//  Copyright © 2017年 MacBook. All rights reserved.
//

import UIKit

// MARK: - 协议
protocol MagicLabelDelegate: class {
    /// 点击协议
    ///
    /// - Parameters:
    ///   - label: 本身
    ///   - text: 被点击的文本
    func labelDidSelectedLinkText(_ label: MagicLabel, text: String)
}

// MARK: - 点击协议的实现,可以实现类似于optional的效果
extension MagicLabelDelegate {
    func labelDidSelectedLinkText(_ label: MagicLabel,
                                  text: String){
        print("您未实现\(label.self)的代理方法")
    }
}


// MARK: - 简单的点击链接Label 使用 TextKit重写
class MagicLabel: UILabel {

    /// 链接文本的颜色
    public var linkTextColor =  UIColor.blue
    /// 点击后链接文本的背景色
    public var selectedBackgroudColor = UIColor.lightGray.withAlphaComponent(0.3)
    /// 正则表达式 用于选择符合一定条件的文本
    public var patterns = ["[a-zA-Z]*://[a-zA-Z0-9/\\.]*",
                           "#.*?#",
                           "\\$.*?\\$",
                           "@[\\u4e00-\\u9fa5a-zA-Z0-9_-]*"]
    /// 代理
    public weak var delegate: MagicLabelDelegate?
    
    public var autoresizingHeight = false {
        didSet{
            if autoresizingHeight {
                self.resizingHeight()
            }
        }
    }
    
    public var adjustCoefficient : CGFloat = 0.1{
        didSet{
            if adjustCoefficient > 1{
                adjustCoefficient = oldValue
            }
            else if adjustCoefficient < 0.01{
                adjustCoefficient = 0.01
            }
        }
    }
    
    private lazy var linkRanges = [NSRange]()
    private var selectedRange: NSRange?
    private lazy var textStorage = NSTextStorage()
    private lazy var layoutManager = NSLayoutManager()
    private lazy var textContainer = NSTextContainer()
    
    // MARK: - 重写父类属性
    
    override public var text: String? {
        didSet {
            updateTextStorage()
        }
    }
    
    override public var attributedText: NSAttributedString? {
        didSet {
            updateTextStorage()
        }
    }

    override public var textColor: UIColor! {
        didSet {
            updateTextStorage()
        }
    }
    
    // MARK: - 系统方法
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        prepareLabel()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
        prepareLabel()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        // 只有在这里才会获得正确的大小
        textContainer.size = bounds.size
    }
    
    public override func drawText(in rect: CGRect) {
        let range = glyphsRange()
        layoutManager.drawBackground(forGlyphRange: range, at: CGPoint.zero)
        layoutManager.drawGlyphs(forGlyphRange: range, at: CGPoint.zero)
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else {
            return
        }
        selectedRange = linkRangeAtLocation(location)
        modifySelectedAttribute(true)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else {
            return
        }
        if let range = linkRangeAtLocation(location) {
            if !(range.location == selectedRange?.location && range.length == selectedRange?.length) {
                modifySelectedAttribute(false)
                selectedRange = range
                modifySelectedAttribute(true)
            }
        } else {
            modifySelectedAttribute(false)
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if selectedRange != nil {
            let text = (textStorage.string as NSString).substring(with: selectedRange!)
            delegate?.labelDidSelectedLinkText(self, text: text)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.25) {
                self.modifySelectedAttribute(false)
            }
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        modifySelectedAttribute(false)
    }
    
    
    // MARK: - 自定义方法
    
    private func setup(){
        textAlignment = .left
        numberOfLines = 0
    }
    
    private func prepareLabel() {
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        textContainer.lineFragmentPadding = 0
        isUserInteractionEnabled = true
    }
    
    /// 设置属性TextStorage关于字体的颜色什么的
    private func updateTextStorage() {
        if attributedText == nil {
            attributedText = NSAttributedString(string: text ?? "")
        }
        if autoresizingHeight {
            resizingHeight()
        }
        let attrStringM = addLineBreak(attributedText!)
        regexLinkRanges(attrStringM)
        addLinkAttribute(attrStringM)
        textStorage.setAttributedString(attrStringM)
        setNeedsDisplay()
    }
    
    /// 自动更具内容计算高度
    private func resizingHeight(){
        let viewSize = CGSize(width: self.bounds.width, height: CGFloat(MAXFLOAT))
        let textHeight = (self.text?.boundingRect(with: viewSize, options: [.usesLineFragmentOrigin], attributes:[NSFontAttributeName: self.font],context: nil).height)! + 1
        self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.bounds.width, height: textHeight)
    }
    
    /// 添加富文属性设置
    ///
    /// - Parameter attrStringM: 富文本
    private func addLinkAttribute(_ attrStringM: NSMutableAttributedString) {
        if attrStringM.length == 0 {
            return
        }
        // 作用相当于指针
        var range = NSRange(location: 0, length: 0)
        var attributes = attrStringM.attributes(at: 0, effectiveRange: &range)
        attributes[NSFontAttributeName] = font
        attributes[NSForegroundColorAttributeName] = textColor
        attrStringM.addAttributes(attributes, range: range)
        attributes[NSForegroundColorAttributeName] = linkTextColor
        for r in linkRanges {
            attrStringM.setAttributes(attributes, range: r)
        }
    }
    
    /// 获取正则匹配结果的NSRange结果
    ///
    /// - Parameter attrString: 富文本
    private func regexLinkRanges(_ attrString: NSAttributedString) {
        linkRanges.removeAll()
        let regexRange = NSRange(location: 0, length: attrString.string.characters.count)
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.dotMatchesLineSeparators) else{
                continue
            }
            let results = regex.matches(in: attrString.string, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: regexRange)
            for r in results {
                linkRanges.append(r.rangeAt(0))
            }
        }
    }

    /// 转换 NSMutableAttributedString
    ///
    /// - Parameter attrString: 参数类型 NSAttributedString
    /// - Returns: 返回 NSMutableAttributedString
    /// - case byWordWrapping     // Wrap at word boundaries, default
    /// - case byCharWrapping     // Wrap at character boundaries
    /// - case byClipping         // Simply clip
    /// - case byTruncatingHead   // Truncate at head of line: "...wxyz"
    /// - case byTruncatingTail   // Truncate at tail of line: "abcd..."
    /// - case byTruncatingMiddle // Truncate middle of line:  "ab...yz"
    private func addLineBreak(_ attrString: NSAttributedString) -> NSMutableAttributedString {
        let attrStringM = NSMutableAttributedString(attributedString: attrString)
        if attrStringM.length == 0 {
            return attrStringM
        }
        var range = NSRange(location: 0, length: 0)
        var attributes = attrStringM.attributes(at: 0, effectiveRange: &range)
        guard let paragraphStyle = attributes[NSParagraphStyleAttributeName] as? NSMutableParagraphStyle else {
            let paragraphStyleM = NSMutableParagraphStyle()
            paragraphStyleM.lineBreakMode = NSLineBreakMode.byCharWrapping
            attributes[NSParagraphStyleAttributeName] = paragraphStyleM
            attrStringM.setAttributes(attributes, range: range)
            return attrStringM
        }
        paragraphStyle.lineBreakMode = NSLineBreakMode.byCharWrapping
        return attrStringM
    }
    
    private func glyphsRange() -> NSRange {
        return NSRange(location: 0, length: textStorage.length)
    }
    
    /// 设置点击后的背景颜色
    ///
    /// - Parameter isSet: 是否点击
    private func modifySelectedAttribute(_ isSet: Bool) {
        if selectedRange == nil {
            return
        }
        var attributes = textStorage.attributes(at: 0, effectiveRange: nil)
        attributes[NSForegroundColorAttributeName] = linkTextColor
        attributes[NSBackgroundColorAttributeName] = isSet ?  selectedBackgroudColor : UIColor.clear
        textStorage.addAttributes(attributes, range: selectedRange!)
        selectedRange = !isSet ? nil : selectedRange
        setNeedsDisplay()
    }
    
    /// 确认点击位置
    ///
    /// - Parameter location: 点击的点
    /// - Returns: 返回Range
    private func linkRangeAtLocation(_ location: CGPoint) -> NSRange? {
        if textStorage.length > 0 {
            let index = layoutManager.glyphIndex(for: location, in: textContainer)
            for r in linkRanges {
                if  NSLocationInRange(index, r) {
                    return r
                }
            }
        }
        return nil
    }



}
