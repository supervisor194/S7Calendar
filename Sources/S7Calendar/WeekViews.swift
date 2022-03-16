import SwiftUI
import Combine


public struct WrappedWeekView<Content: View> : View {
    
    let weekView: Content
    
    let model: WeekViewModel
    
    let toSelect: Int
    
    public init(_ content: Content, _ toSelect: Int) {
        self.weekView = content
        let wv = content as! WeekView
        self.model = wv.model
        self.toSelect = toSelect
    }
    
    public var body: some View {
        weekView
            .onAppear {
                self.model.selected = toSelect
            }
    }
    
}


public struct WeekView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var model : WeekViewModel
    
    @State var cellWidth: CGFloat = 55.0
    @State var useH: CGFloat = 55.0
    
    let calendarModel: CalendarModel
    let numDays : Int
    
    public init(calendarModel: CalendarModel, begin: String, numDays: Int) {
        self.calendarModel = calendarModel
        self.numDays = numDays
        self.model = WeekViewModel(beginAroundYMD: begin, numDays: numDays)
    }
    
    public func getTagForDay(day: Int, mit: MonthInfoAndToday) -> Int {
        model.getTagForDay(day, mit)
    }
    
    public var body: some View {
        let _ = Self._printChanges()
        
        VStack(spacing: 0) {
            HStack {
                ForEach( (0...model.dayHeading.count-1), id: \.self) { i in
                    Text(model.dayHeading[i])
                        .font(.caption2)
                        // .padding(.bottom,5)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.leading, 4)
            .padding(.trailing, 4)
            .readSize { s in
                cellWidth = s.width / 7.0
            }
            .background(.cyan)
            ScrollViewReader { proxy in
                OriginAwareScrollView(name: calendarModel.name, axes: [.horizontal], showIndicators: false, onOriginChange: { model.origin.send($0) }) {
                    LazyHStack(spacing:0) {
                        ForEach( (1...numDays), id: \.self) { i in
                            buildButton(i, proxy)
                        }
                        .frame(width: cellWidth)
                        .background(.blue)
                    }
                    .onChange(of: model.selected) { v in
                        model.setYMD()
                        let target = model.snap()
                        withAnimation {
                            proxy.scrollTo(target, anchor: .leading)
                        }
                    }
                    .onAppear {
                        Task.detached {
                            async let doSN = model.doScrollSnap(proxy)
                            await doSN
                            await model.setupSubscription(proxy)
                        }
                    }
                }
                .background(.red)
                .coordinateSpace(name: calendarModel.name)
            }
            .background(.green)
               // .padding(0)
                
            DayView(calendarModel: calendarModel, ymd: model.selectedYMD)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
                                Button(action: {
            if let monthsView = calendarModel.monthsView {
                let ymd = model.getYMD(model.selected)
                let ymdMonth = ymd.replacingOccurrences(of: #"[\d-]+$"#, with: "1", options: .regularExpression)
                let monthTag = monthsView.model.getTag(ymdMonth)
                monthsView.model.backFromWeek = monthTag
            }
            self.presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image(systemName: "arrow.left")
            }
        })
    }
    
    
    @ViewBuilder
    func buildButton(_ i:Int, _ proxy: ScrollViewProxy) -> some View {
        Button(action: {
            model.selected = i
        })
        {
            Image(systemName: "circle.fill")
                .font(.largeTitle)
                .foregroundColor( model.selected == i ? .black : .white)
                .overlay(
                    Text(model.dayLabels[i])
                        .foregroundColor( model.selected == i ? .white : .black ))
        }
        .onAppear {
            model.visibleItems[Int(i)] = true
        }
        .onDisappear {
            model.visibleItems.removeValue(forKey: Int(i))
        }
        .id(Int(i))
    }
}

class WeekViewModel : ObservableObject {
    
    @Published var selected: Int = 1
    @Published var selectedYMD: String
    
    var visibleItems: [Int:Bool] = [:]
    
    var dayHeading: [String] = []
    let firstDay: Date
    var dayComponent = DateComponents()
    var dayLabels: [String] = []
    let origin: CurrentValueSubject<CGPoint, Never>
    let originPublisher: AnyPublisher<CGPoint, Never>
    var subscription: AnyCancellable? = nil
    
    var tagsByYMD: [String:Int] = [:]
    var tagsById: [Int:String] = [:]
    
    init(beginAroundYMD: String, numDays: Int) {
        self.origin = CurrentValueSubject<CGPoint, Never>(.zero)
        self.originPublisher = self.origin
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
        
        // first setup the day heading values, like S M T W T F S  in locale order
        let c = Calendar.current
        let firstWeekday = c.firstWeekday
        let shortWeekdaySymbols:[String] = c.shortWeekdaySymbols
        for i in firstWeekday...7 {
            let s = shortWeekdaySymbols[i-1]
            dayHeading.append(String(s[0]))
        }
        var i = 0
        while dayHeading.count < 7 {
            dayHeading.append(shortWeekdaySymbols[i])
            i+=1
        }
        
        func dayOfWeek(_ date: Date) -> Int {
            c.dateComponents([.weekday], from: date).weekday!
        }
        
        // find the first day to begin with that matches the first day of the week in locale
        var possibleFirstDay = ymDateFormatter.getDate(ymd: beginAroundYMD)
        while dayOfWeek(possibleFirstDay) != firstWeekday {
            possibleFirstDay = c.date(byAdding: .day, value: -1, to: possibleFirstDay)!
        }
        self.firstDay = possibleFirstDay
        
        
        dayComponent.day = 1 - 1
        let selectedDate = ymDateFormatter.addComponents(components: dayComponent, to: firstDay)
        selectedYMD = ymDateFormatter.getYMDForDate(selectedDate)
        
        for day in 1...numDays {
            dayComponent.day = day - 1
            let selectedDate = ymDateFormatter.addComponents(components: dayComponent, to: firstDay)
            let ymd = ymDateFormatter.getYMDForDate(selectedDate)
            addTag(ymd, day)
        }
       
        computeDayLabels(numDays: numDays)
    }
    
    
    func addTag(_ ymd: String, _ i:Int) {
        tagsByYMD[ymd] = i
        tagsById[i] = ymd
    }
    
    func getTag(_ ymd: String) -> Int {
        tagsByYMD[ymd]!
    }
    
    func getYMD(_ i:Int) -> String {
        tagsById[i]!
    }
    
    func getTagForDay(_ day: Int, _ mit: MonthInfoAndToday) -> Int {
        let ymd = String(mit.year) + " " + String(mit.month) + " " + String(day)
        return getTag(ymd)
    }
    
    @MainActor
    func isSnapToVisible() async -> Bool {
        let snapTo = Int(Double(selected-1)/7.0) * 7 + 1
        return visibleItems[snapTo] != nil
    }
    
    @MainActor
    func doScrollSnap(_ proxy: ScrollViewProxy) async -> Int {
        let snapTo = Int(Double(selected-1)/7.0) * 7 + 1
        proxy.scrollTo(snapTo, anchor: .leading)
        return 1
    }
    
    
    func setupSubscription(_ proxy: ScrollViewProxy) {
        subscription = originPublisher.sink { [unowned self] v in
            let target = self.snap()
            self.subscription?.cancel()
            withAnimation {
                proxy.scrollTo(target, anchor: .leading)
            }
            self.setupSubscription(proxy)
            
            let mod = selected % 7
            let pos = mod == 0 ? 6 : mod - 1
            self.selected = target + pos
            
        }
    }
    
    func snap() -> Int {
        let sorted = visibleItems.sorted(by: {$0.0 < $1.0})
        if let f = sorted.first {
            let snapTo = Int(round(Double(f.key-1)/7.0)) * 7 + 1
            return snapTo
        } else {
            return 1
        }
    }
    
    private func computeDayLabels(numDays: Int) {
        let c = Calendar.current
        self.dayLabels.append("foo")
        for i in 1...numDays {
            let date = c.date(byAdding: .day, value: i-1, to: firstDay)!
            let l = String(c.dateComponents([.day], from: date).day!)
            self.dayLabels.append(l)
        }
    }
    
    func setYMD() {
        dayComponent.day = selected - 1
        let selectedDate = ymDateFormatter.addComponents(components: dayComponent, to: firstDay)
        selectedYMD = ymDateFormatter.getYMDForDate(selectedDate)
    }
    
}

struct DayView : View {
    
    let day: Date
    let mit: MonthInfoAndToday
    let calendarModel: CalendarModel
    
    init(calendarModel: CalendarModel, ymd: String) {
        self.calendarModel = calendarModel
        day = ymDateFormatter.getDate(ymd: ymd)
        mit = ymDateFormatter.getMIT(date: day)
    }
    
    var body: some View {
        Text(ldf1.dateFormatter.string(from: day))
        Divider()
            .frame(height: 0.5)
            .padding(.horizontal)
        
        ScrollView {
            VStack {
                ForEach( (0...23), id: \.self) { hour in
                    HourView(calendarModel: calendarModel, mit: mit, day: day, hour: hour)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 5)
            .padding(.trailing, 5)
            
        }
    }
}


struct HourView : View {
    
    let calendarModel: CalendarModel
    let mit: MonthInfoAndToday
    let day: Date
    let hour: Int
    
    var body: some View {
        VStack {
            HStack {
                Text(hourFormatter.string(from: day.advanced(by: TimeInterval(hour*60*60))))
                    .font(.footnote)
                VStack {
                    Divider()
                }.frame(maxWidth: .infinity)
            }
            calendarModel.cellBuilder.dayViewHourCell(calendarModel, mit, hour)
                .frame(maxWidth: .infinity)
            
        }
    }
}


struct ScrollOriginPreferenceKey: PreferenceKey {
    typealias Value = CGRect
    static var defaultValue: Value = .zero
    static func reduce(value: inout Value, nextValue:()->Value) { }
}

struct OriginAwareScrollView<Content:View> : View {
    let axes: Axis.Set
    let showIndicators: Bool
    let onOriginChange: (CGPoint) -> Void
    let content: Content
    let name: String
    
    init(name: String, axes: Axis.Set = .vertical, showIndicators: Bool = true, onOriginChange: @escaping (CGPoint)->Void = { _ in }, @ViewBuilder content: ()->Content) {
        self.name = name
        self.axes = axes
        self.showIndicators = showIndicators
        self.onOriginChange = onOriginChange
        self.content = content()
    }
    
    var body: some View {
        ScrollView(axes, showsIndicators: showIndicators) {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    Color.clear.preference(key: ScrollOriginPreferenceKey.self, value: geometry.frame(in: .named(name)))
                }.frame(width:0,height:0)
                content
            }.fixedSize(horizontal: false, vertical: true).background(.red)
            
        }
        .onPreferenceChange(ScrollOriginPreferenceKey.self) { value in
            onOriginChange(value.origin)
        }
    }
}


