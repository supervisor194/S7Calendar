import Foundation
import SwiftUI

@available(iOS 15.0, *)
public protocol CellBuilder {
    func yearlyViewDayCell(_ model: CalendarModel, _ monthInfo:MonthInfo, _ day: Int, _ fontSize: CGFloat) -> AnyView
    
    func monthlyViewDayCell(_ model: CalendarModel, _ monthInfo: MonthInfo, _ day: Int, _ fontSize: CGFloat) -> AnyView
    func monthlyViewNameCell(_ model: CalendarModel, _ monthInfo: MonthInfo, _ fontSize: CGFloat) -> AnyView
    func monthlyViewEmptyCell(_ model: CalendarModel, _ fontSize: CGFloat) -> AnyView
    
    func dayViewHourCell(_ model: CalendarModel, _ monthInfo: MonthInfo, _ hour: Int) -> AnyView
    func dayViewAdditionLink(_ model: CalendarModel, _ ymd: YMD) -> AnyView?
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

open class CalendarConfigBase : CalendarConfig {
    public let name: String
    
    public let cellBuilder: CellBuilder
    
    public var yearlyView: ((CalendarModel) -> YearlyView)? = nil
    
    public var weekView: ((CalendarModel) -> WeekView)? = nil
    
    public var monthsView: ((CalendarModel) -> MonthsView)? = nil
    
    public var colors: ((CalendarModel) -> CalendarColors)? = nil
    
    public init(name: String, cellBuilder: CellBuilder) {
        self.name = name
        self.cellBuilder = cellBuilder
    }
    
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

public class TodayInfo : ObservableObject {
    @Published public var dayChangeCount: Int = 1
    @Published public var today: Date
    @Published public var year: Int
    @Published public var month: Int
    @Published public var day: Int
    @Published public var ymd: YMD
    
    public static let shared = TodayInfo()
   
    private init() {
        let ymd = ymDateFormatter.getYMDForToday()
        today = Date()
        self.ymd = ymd
        year = ymd.year
        month = ymd.month
        day = ymd.day

        setupTimer()
    }
    
    
    @MainActor
    func isNew() async -> Bool {
        print("isNew() \(Thread.current)")
        let ymd = ymDateFormatter.getYMDForToday()
        var changed = false
        if self.year != ymd.year {
            self.year = ymd.year
            changed = true
        }
        if self.month != ymd.month {
            self.month = ymd.month
            changed = true
        }
        if self.day != ymd.day {
            self.day = ymd.day
            changed = true
        }
        if changed {
            self.ymd = ymd
            self.dayChangeCount += 1
        }
        return changed
    }
    
    // set a timer for every second, update dayCount if day changes
    func setupTimer() {
        Task.detached {
            print("on detached timer \(Thread.current)")
            async let n = self.isNew()
            await n
            print("back on detached \(Thread.current)")
            usleep(1000*1000)
            self.setupTimer()
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

