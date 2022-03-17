# S7Calendar

A simple SwiftUI calendar library with year, month, week and day views.  Developers customize
the cells to render notifications, meetings, etc.  


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
                WrappedYearlyView(cml.getModel("foo").yearlyView, 1)
            }
            .navigationViewStyle(StackNavigationViewStyle())
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
    
    func yearlyViewDayCell(_ model: CalendarModel, _ dac:MonthInfoAndToday, _ day: Int, _ fontSize: CGFloat) -> AnyView {
        AnyView(MyYearlyViewDayCell(model: model, dac: dac,day: day,fontSize: fontSize))
    }
    
    func monthlyViewDayCell(_ model: CalendarModel, _ mit: MonthInfoAndToday, _ day: Int, _ fontSize: CGFloat) -> AnyView {
        AnyView(MyMonthlyViewDayCell(model: model, mit:mit, day: day, fontSize:fontSize))
    }
    
    func monthlyViewNameCell(_ model: CalendarModel, _ mit: MonthInfoAndToday, _ fontSize: CGFloat) -> AnyView {
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
    
    func dayViewHourCell(_ model: CalendarModel, _ mit: MonthInfoAndToday, _ hour: Int) -> AnyView {
        AnyView(MyDayViewHourCell(model: model, mit: mit, hour: hour))
    }
    
    func dayViewAdditionLink(_ model: CalendarModel, _ ymd: String) -> AnyView? {
        AnyView(MyDayViewAdditionLink(model: model, ymd: ymd))
    }
    
}


class MyConfig : CalendarConfig {
    
    let name: String
    let cellBuilder: CellBuilder
    let weekView: ((CalendarModel) -> WeekView)?
    let monthsView: ((CalendarModel) -> MonthsView)?
    let yearlyView: ((CalendarModel) -> YearlyView)?
    
    init() {
        name = "foo"
        cellBuilder = MyCellBuilder()
        
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
    
    let model: CalendarModel
    let mit: MonthInfoAndToday
    let day: Int
    let fontSize: CGFloat
    
    @ViewBuilder
    var body: some View {
        NavigationLink(destination: WrappedWeekView(model.weekView, model.weekView!.getTagForDay(day: day, mit: mit))) {
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
        let d1 = 7 - mit.weekday+1
        let d2 = 7 - mit.weekday+2
        if isToday(mit: mit, day: day) {
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
    
    var model: CalendarModel
    var ymd: String
    
    init(model: CalendarModel, ymd: String) {
        self.model = model
        self.ymd = ymd
    }
    
    var body:some View {
        NavigationLink(destination: Text("add some event for \(ymd)")) {
            Label("Plus", systemImage: "plus")
        }
    }
}

struct MyDayViewHourCell : View {
    
    let model: CalendarModel
    let mit: MonthInfoAndToday
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
                    .foregroundColor(.black)
                    .font(.system(size: 18))
            }
        }
    }
}

struct MyYearlyViewDayCell : View {
    
    let model: CalendarModel
    let dac: MonthInfoAndToday
    let day: Int
    let fontSize: CGFloat
    
    func doit() -> Bool {
        if Int.random(in: 1..<1000) < 10 {
            return true
        }
        return false
    }
    
    var body: some View {
        if isToday(mit: dac, day: day) || doit() {
            Image(systemName: "circle.fill")
                .font(.system(size: fontSize * 1.25))
                .background(.red)
                .foregroundColor(.red)
                .saturation(1.0)
                .blur(radius: fontSize / 3.0 )
                .overlay(Text(String(day))
                            .foregroundColor(.black)
                            .font(.system(size: fontSize)))
            
        } else {
            Text(String(day))
                .font(.system(size: fontSize))
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.black)
        }
    }
}


```
