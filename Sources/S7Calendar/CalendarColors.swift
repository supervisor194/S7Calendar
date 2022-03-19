import Foundation
import SwiftUI



public class CalendarUIColor : UIColor {
    
    convenience init(light: UIColor, dark: UIColor) {
        self.init { t in
            switch t.userInterfaceStyle {
            case .light, .unspecified :
                return light
            case .dark:
                return dark
            @unknown default:
                return light
            }
        }
    }
}

public class CalendarColor {
    
    let _color: Color
    
    public var color : Color { get
        {
            return _color
        }
    }
    
    public init(light: Color, dark: Color) {
        _color = Color(CalendarUIColor(light: UIColor(light), dark: UIColor(dark)))
    }
    
}


public protocol CalendarColors {
    
    var background: Color  { get  }
    var text: Color { get }
    var navIcons: Color { get }
    var navBackground: Color { get }
    var weekViewHeader: Color { get }
    
}

public struct DefaultCalendarColors : CalendarColors {
    var _background = CalendarColor(light: .white, dark: .black)
    public var background: Color {
        get {
            _background.color
        }
    }
    
    var _text = CalendarColor(light: .black, dark: .white)
    public var text : Color {
        get {
            _text.color
        }
    }
    var _navIcons = CalendarColor(light: .red, dark: .red)
    public var navIcons: Color {
        get {
            _navIcons.color
        }
    }
    var _navBackground = CalendarColor(light: Color(UIColor.lightGray), dark: Color(UIColor.darkGray))
    public var navBackground: Color  {
        get {
            _navBackground.color
        }
    }
    var _weekViewHeader = CalendarColor(light: Color(UIColor.lightGray), dark: Color(UIColor.darkGray))
    public var weekViewHeader: Color {
        get {
            _weekViewHeader.color
        }
    }
}

let defaultCalendarColors = DefaultCalendarColors()
