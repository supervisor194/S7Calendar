# S7Calendar

A simple SwiftUI calendar library with year, month, week and day views.  Developers customize
the cells to render notifications, meetings, etc.  

Not yet at release 1.0.   Call it 0.7 


A basic iOS 15 App

```
import SwiftUI
import S7Calendar

public let cml = CalendarModelLoader.instance

@main
struct S7CApp: App {
    
    init() {
      cml.addModel(CalendarModel(MyConfig()))
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                WrappedYearlyView(cml.getModel("foo").yearlyView, cml.getModel("foo").yearlyView!.getIdForToday())
            }
           
            .navigationViewStyle(StackNavigationViewStyle())
            .background(.green)
        }
    }
}
```

Customized model and cell builders

```
import Foundation
import SwiftUI
import S7Calendar


class MyCellBuilder : CellBuilder {
    
    func yearlyViewDayCell(_ model: CalendarModel, _ dac:MonthInfo, _ day: Int, _ fontSize: CGFloat) -> AnyView {
        AnyView(MyYearlyViewDayCell(model: model, monthInfo: dac,day: day,fontSize: fontSize))
    }
    
    func monthlyViewDayCell(_ model: CalendarModel, _ mit: MonthInfo, _ day: Int, _ fontSize: CGFloat) -> AnyView {
        AnyView(MyMonthlyViewDayCell(model: model, monthInfo:mit, day: day, fontSize:fontSize))
    }
    
    func monthlyViewNameCell(_ model: CalendarModel, _ mit: MonthInfo, _ fontSize: CGFloat) -> AnyView {
        AnyView(Text(mit.name)
                    .font(.system(size: fontSize))
                    .fontWeight(.medium)
                    .lineLimit(1)
        )
    }
    
    func monthlyViewEmptyCell(_ model: CalendarModel, _ fontSize: CGFloat) -> AnyView {
        AnyView(
            Text("X")
                .frame(height: 30)
                .hidden()
        )
    }
    
    func dayViewHourCell(_ model: CalendarModel, _ mit: MonthInfo, _ hour: Int) -> AnyView {
        AnyView(MyDayViewHourCell(model: model, mit: mit, hour: hour))
    }
    
    func dayViewAdditionLink(_ model: CalendarModel, _ ymd: YMD) -> AnyView? {
        AnyView(MyDayViewAdditionLink(model: model, ymd: ymd))
    }
    
}


public class MyConfig : CalendarConfigBase {
    
    init() {
        super.init(name: "foo", cellBuilder: MyCellBuilder())
        
        self.weekView = { calendarModel in
            WeekView(calendarModel: calendarModel, begin: "2019 1 1", numDays: 365*10)
        }
        
        self.monthsView = { calendarModel in
            MonthsView(calendarModel: calendarModel, begin: "2019 1 1",
                       numMonths: 12*10)
        }
        
        self.yearlyView = { calendarModel in
            YearlyView(calendarModel: calendarModel, begin: "2019 1 1", numYears: 10)
        }
    }
}

struct MyMonthlyViewDayCell : View {
    
    @ObservedObject var model: CalendarModel
    @ObservedObject var todayInfo: TodayInfo = TodayInfo.shared
    
    let monthInfo: MonthInfo
    let day: Int
    let fontSize: CGFloat
    
    @ViewBuilder
    var body: some View {
        NavigationLink(destination: WrappedWeekView(model.weekView, model.weekView!.getTagForDay(day: day, monthInfo: monthInfo))) {
            VStack {
                Divider()
                Text(String(day))
                    .font(.system(size: fontSize))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .padding([.top, .bottom], 10)
                    .foregroundColor(dayColor(day: day))
                Image(systemName: "circle.fill")
                    .font(.system(size: fontSize*0.5))
                Spacer()
            }//.frame(maxWidth: .infinity, minHeight: 70)
            
        }
    }
    
    func dayColor(day: Int) -> Color {
        if Int.random(in: 1..<100) < 10 {
            return Color.green
        }
        let d1 = 7 - monthInfo.weekday+1
        let d2 = 7 - monthInfo.weekday+2
        
        if todayInfo.day == day && monthInfo.year == todayInfo.year && monthInfo.month == todayInfo.month {
            return Color.red
        }
        
        if (day-d1) % 7 == 0 || (day-d2) % 7 == 0 {
            return Color.gray
        }
        return Color.black
    }
}

struct MyMeetingView : View {
    
    var body: some View {
        Text("Here is my meeting")
    }
}

struct MyDayViewAdditionLink : View {
    
    @ObservedObject var model: CalendarModel
    var ymd: YMD
    
    init(model: CalendarModel, ymd: YMD) {
        self.model = model
        self.ymd = ymd
    }
    
    var body:some View {
        NavigationLink(destination: Text("add some event for \(String(ymd.year)) \(ymd.month) \(ymd.day)")) {
            Label("Plus", systemImage: "plus")
        }
    }
}

struct MyDayViewHourCell : View {
    
    @ObservedObject var model: CalendarModel
    let mit: MonthInfo
    let hour: Int
    
    @State var selection: String? = nil
    
    func makeId(_ i:Int) -> String {
        return String("HourCell:" + String(hour) + ":" + String(i))
    }
    
    var body: some View {
        HStack() {
            if hour == 8 {
                ForEach( (1...5), id: \.self) { i in
                    
                    NavigationLink(destination: MyMeetingView()) {
                        
                        Rectangle().fill(.cyan).frame(maxWidth: .infinity, minHeight: 75)
                            .overlay(Text(String("My Big Meeting " + String(i))))                       .border(.blue)
                    }
                }
                
            } else {
                Text(String("."))
                    .foregroundColor(model.colors.text)
                    .font(.system(size: 18))
            }
        }
    }
}

struct MyYearlyViewDayCell : View {
    
    @ObservedObject var model: CalendarModel
    @ObservedObject var todayInfo: TodayInfo = TodayInfo.shared
    
    let monthInfo: MonthInfo
    let day: Int
    let fontSize: CGFloat
    
    func doit() -> Bool {
        if Int.random(in: 1..<1000) < 10 {
            return true
        }
        return false
    }
    
    var body: some View {
        if day == todayInfo.day && monthInfo.month == todayInfo.month && monthInfo.year == todayInfo.year || doit() {
            Image(systemName: "circle.fill")
                .font(.system(size: fontSize * 1.25))
                .background(.red)
                .foregroundColor(.red)
                .saturation(1.0)
                .blur(radius: fontSize / 3.0 )
                .overlay(Text(String(day))
                            .foregroundColor(model.colors.text)
                            .font(.system(size: fontSize)))
            
        } else {
            Text(String(day))
                .font(.system(size: fontSize))
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(model.colors.text)
        }
    }
}
```
