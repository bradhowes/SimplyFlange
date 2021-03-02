// Copyright © 2021 Brad Howes. All rights reserved.

#if os(iOS)

import UIKit
public typealias Color = UIColor
public typealias Label = UILabel
public typealias Slider = UISlider
public typealias Storyboard = UIStoryboard
public typealias View = UIView

#elseif os(macOS)

import AppKit
public typealias Color = NSColor
public typealias Label = NSTextField
public typealias Slider = NSSlider
public typealias Storyboard = NSStoryboard
public typealias View = NSView

public extension NSView {
    func setNeedsDisplay() { self.needsDisplay = true }
    func setNeedsLayout() { self.needsLayout = true }

    @objc func layoutSubviews() { self.layout() }

    var backgroundColor: NSColor? {
        get {
            guard let colorRef = self.layer?.backgroundColor else { return nil }
            return NSColor(cgColor: colorRef)
        }
        set {
            self.wantsLayer = true
            self.layer?.backgroundColor = newValue?.cgColor
        }
    }
}

public extension NSTextField {
    var text: String? {
        get { self.stringValue }
        set { self.stringValue = newValue ?? "" }
    }
}

public extension NSSlider {
    var minimumValue: Float {
        get { Float(self.minValue) }
        set { self.minValue = Double(newValue) }
    }

    var maximumValue: Float {
        get { Float(self.maxValue) }
        set { self.maxValue = Double(newValue) }
    }

    var value: Float {
        get { self.floatValue }
        set { self.floatValue = newValue }
    }
}

#endif
