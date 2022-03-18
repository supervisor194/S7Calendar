import Foundation
import SwiftUI

@available(iOS 15.0, *)
public protocol CellBuilder {
    func yearlyViewDayCell(_ model: CalendarModel, _ dac:MonthInfoAndToday, _ day: Int, _ fontSize: CGFloat) -> AnyView
    
    func monthlyViewDayCell(_ model: CalendarModel, _ mit: MonthInfoAndToday, _ day: Int, _ fontSize: CGFloat) -> AnyView
    func monthlyViewNameCell(_ model: CalendarModel, _ mit: MonthInfoAndToday, _ fontSize: CGFloat) -> AnyView
    func monthlyViewEmptyCell(_ model: CalendarModel, _ fontSize: CGFloat) -> AnyView
    
    func dayViewHourCell(_ model: CalendarModel, _ mit: MonthInfoAndToday, _ hour: Int) -> AnyView
    func dayViewAdditionLink(_ model: CalendarModel, _ ymd: String) -> AnyView?
}


@available(iOS 15.0, *)
public protocol CalendarConfig {
    var name: String { get }
    var cellBuilder : CellBuilder { get }
    
    var yearlyView: ((_ calendarModel: CalendarModel) -> YearlyView)? { get }
    var weekView: ((_ calendarModel: CalendarModel) -> WeekView)? { get }
    var monthsView: ((_ calendarModel: CalendarModel) -> MonthsView)? { get }
    
    var colors: ((_ calendarModel: CalendarModel) -> CalendarColors)? { get }
}


public class CalendarModelLoader {
    public static var instance : CalendarModelLoader = CalendarModelLoader()
    
    private init() {
    }
    
    var _models : [String: CalendarModel] = [:]
    
    public func getModel(_ name: String) -> CalendarModel {
        _models[name]!
    }
    
    public func addModel(_ model: CalendarModel) {
        _models[model.name] = model
     
        if let yearlyView = model.config.yearlyView {
            model.yearlyView = yearlyView(model)
        }
        if let weekView = model.config.weekView {
            model.weekView = weekView(model)
        }
        if let monthsView = model.config.monthsView {
            model.monthsView = monthsView(model)
        }
        if let colors = model.config.colors {
            model.colors = colors(model)
        } 
    }
    
}


public class CalendarModel : ObservableObject {
    
    @Published var name: String
    
    let config : CalendarConfig
    let cellBuilder : CellBuilder
    
    var _weekView: WeekView? = nil
    
    public var weekView : WeekView? {
        get {
            _weekView
        }
        set {
            _weekView = newValue
        }
    }
    
    var _monthsView : MonthsView? = nil
    
    public var monthsView: MonthsView? {
        get {
            _monthsView
        }
        set {
            _monthsView = newValue
        }
    }
    
    
    var _yearlyView: YearlyView? = nil
    
    public var yearlyView: YearlyView? {
        get {
            _yearlyView
        }
        set {
            _yearlyView = newValue
        }
    }
    
    var _colors: CalendarColors
    
    public var colors: CalendarColors {
        get {
            _colors
        }
        
        set {
            _colors = newValue
        }
    }
    
    public init(_ config: CalendarConfig) {
        self.name = config.name
        self.cellBuilder = config.cellBuilder
        self.config = config
        self._colors = DefaultCalendarColors()
    }
}

