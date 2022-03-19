import Foundation

/*
 // MonthInfo has the beginning day of the month 1 Sunday 7 Saturday
 //
 // begin = 3, then weekends are Tues (3,1) Wed 3,2 Th 3,3, f 3,4
 
 begin = 1, ->  1  7,8  14, 15  21, 22  28, 29
 begin = 2, ->     6,7  13, 14  20, 21, 27, 28
 begin = 3, ->     5,6  12, 13  19, 20  26, 27
 begin = 4  ->     4,5  11, 12  18, 19  25, 26
 begin = 5  ->     3,4  10, 11  17, 18  24, 25
 begin = 6  ->     2,3   9, 10  16, 17  23, 24  30, 31
 begin = 7  ->     1,2   8, 9   15, 16  22, 23  29, 30
 
 7-begin  + (1,2)+7*n
 let d1 = 7-begin + 1
 let d2 = 7-begin + 2
 
 begin = 1
 7-1   + (1,2)+7*n  == 6 + (1,2)+7*n == (7,8) + 7*n
 
 if day-d1 % 7 == 0 || day -d2 % 7 == 0 {
 1-7 % 7 != 0    || 1-8 % 7 == 0
 // weekend
 } else {
 weekday
 
 */


public struct MonthInfo {
    public let weekday: Int   // day of the week this month begins, 1 Sunday in USA
    public let numDays: Int     // number of days in this month
    public let name: String   // name of the month as 3 letters, Jan
    public let year: Int      // the year for this month
    public let month: Int     // month number, Jan == 1 ... Dec == 12
}


// todo: setup like the ymDateFormatter but with template

public class LocalizedDateFormatter1 {
    let dateFormatter = DateFormatter()
    
    init() {
        let pref = Locale.preferredLanguages[0]
        dateFormatter.locale = Locale(identifier: pref)
        dateFormatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d, yyyy")
    }
}

public let ldf1 = LocalizedDateFormatter1()

public struct YMD : Hashable {
    public let year: Int
    public let month: Int
    public let day: Int
    
    public init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(year)
        hasher.combine(month)
        hasher.combine(day)
    }
    
    public static func == (lhs: YMD, rhs: YMD) -> Bool {
        lhs.day == rhs.day && lhs.month == rhs.month && lhs.year == rhs.year
    }
}

@available(iOS 15.0, *)
public class YMDateFormatter {
    let dateFormatter: DateFormatter
    let calendar: Calendar
    let monthFormatter: DateFormatter
    
    let _firstWeekdayAdjustment: Int
    
    var firstWeekdayAdjustment: Int {
        get {
            return _firstWeekdayAdjustment
        }
    }
    
    init() {
        let pref = Locale.preferredLanguages[0]
        let locale = Locale(identifier: pref)
        dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.dateFormat = "yyyy M d"
        
        var c = Calendar.current
        c.locale = locale
        self.calendar = c
        
        monthFormatter = DateFormatter()
        monthFormatter.locale = locale
        monthFormatter.dateFormat = "MMM"
        
        _firstWeekdayAdjustment = calendar.firstWeekday - 1
    }
    
    func getFirstWeekdayAdjustment() -> Int {
        calendar.firstWeekday - 1
    }
    
    func getDate(ymd: String) -> Date {
        dateFormatter.date(from: ymd)!
    }
    
    func getDate(ymd: YMD) -> Date {
        getDate(ymd: String(ymd.year) + " " + String(ymd.month) + " " + String(ymd.day))
    }
    
    func addComponents(components: DateComponents, to: Date) -> Date {
        return calendar.date(byAdding: components, to: to)!
    }
    
    // todo: not used ???
    func getYMDString(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from:   date)
        return String(c.year!) + " " + String(c.month!) + " " + String(c.day!)
    }
    
    func getYMDStringFirstOfMonthForToday() -> String {
        let c = calendar.dateComponents([.year, .month], from: Date())
        return String(c.year!) + " " + String(c.month!) + " 1"
    }
    
    // todo: not used ???
    func getYMDStringForToday() -> String {
        return getYMDString(Date())
    }
    
    func getIntervalDays(_ begin: Date, _ end: Date) -> Int {
        return calendar.dateComponents([.day], from: begin, to: end).day!
    }
    
    
    func getYearForToday() -> Int {
        let todayComponents = calendar.dateComponents([.year], from: Date())
        return todayComponents.year!
    }
    
    func getMonthForToday() -> Int {
        let todayComponents = calendar.dateComponents([.month], from: Date())
        return todayComponents.month!
    }
    
    func getYMD(date: Date) -> YMD {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return YMD(components.year!, components.month!, components.day!)
    }
    
    func getYMDForToday() -> YMD {
        getYMD(date: Date())
    }
    
    func isCurrentYear(y: Int) -> Bool {
        let todayYear = calendar.dateComponents([.year], from: Date()).year!
        return y == todayYear
    }
    
    func monthInfo(ymd: YMD) -> MonthInfo {
        let date = getDate(ymd: ymd)
        return monthInfo(date: date)
    }
    
    func monthInfo(ymd: String) -> MonthInfo {
        let date = dateFormatter.date(from: ymd)!
        return monthInfo(date: date)
    }
    
    func monthInfo(date: Date) -> MonthInfo {
        let dateComponents = calendar.dateComponents([.weekday, .day, .month, .year], from: date)
        let interval = calendar.dateInterval(of: .month, for: date)!
        let intervalDays = calendar.dateComponents([.day], from: interval.start, to: interval.end)
        let count = intervalDays.day!
        let name = monthFormatter.string(from: date)
       
        return MonthInfo(weekday: dateComponents.weekday!,
                         numDays: count,
                         name: name,
                         year: dateComponents.year!,
                         month: dateComponents.month!)
    }
    
}

public let ymDateFormatter = YMDateFormatter()


extension StringProtocol {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
}


public let hourFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .none
    f.timeStyle = .short
    return f
}()

