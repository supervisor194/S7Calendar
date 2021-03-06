import SwiftUI
import Combine


public struct WrappedWeekView : View {
    
    let weekView: WeekView
    let uuid: UUID
    
    @ObservedObject var model: WeekViewModel
    @ObservedObject var cModel: CalendarModel
    
    let toSelect: Int
    
    public init(_ cModel: CalendarModel, _ toSelect: Int) {
        self.weekView = cModel.weekView!
        self.uuid = weekView.uuid
        self.model = weekView.model
        self.cModel = cModel
        self.toSelect = toSelect
    }
    
    public var body: some View {
        weekView
            .onAppear {
                if self.model.userNavSelection != nil {
                    self.model.userNavSelection = nil
                } else {
                    print("wanting to select: \(toSelect)")
                    self.model.selected = toSelect
                }
            }
    }
    
}

/*
 The WeekView runs over all the days, months, years in the CalendarModel
 */

public struct WeekView: View, CalendarView {
    
    
    public var viewModel: CalendarViewModel {
        get {
            model
        }
    }
    
    
    public var uuid: UUID {
        get {
            model._uuid
        }
    }
    
    public var calendarModel: CalendarModel {
        get {
            return cModel
        }
        
    }
    
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var model : WeekViewModel
    @ObservedObject var  cModel: CalendarModel
    
    @State var cellWidth: CGFloat = 55.0
    @State var useH: CGFloat = 55.0
    
    public init(calendarModel: CalendarModel, begin: String, numDays: Int) {
        self.cModel = calendarModel
        self.model = WeekViewModel(beginAroundYMD: begin, numDays: numDays, calendarModel: calendarModel)
    }
    
    public func getIdForYMD(_ ymd: YMD) -> Int {
        model.getTag(ymd)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            NavBarColorsView(calendarModel)
            
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
            .background(calendarModel.colors.weekViewHeader)
            ScrollViewReader { proxy in
                OriginAwareScrollView(name: calendarModel.name, axes: [.horizontal], showIndicators: false, onOriginChange: {
                    model.origin.send($0)
                }) {
                    LazyHStack(spacing:0) {
                        ForEach( (1...model.numDays), id: \.self) { i in
                            buildButton(i, proxy)
                        }
                        .frame(width: cellWidth)
                        .background(.blue)
                    }
                    .onChange(of: model.selected) { v in
                        model.cancelSubscription()
                        Task.detached {
                            await model.setYMD()
                            while await model.notShowing() {
                                async let showing = model.doScrollSnap(proxy)
                                if await showing {
                                    break
                                }
                                try? await Task.sleep(nanoseconds: 100000000)
                            }
                            await model.setupSubscription(proxy)
                        }
                    }
                    .onDisappear {
                        model.subscription?.cancel()
                    }
                }
                .background(.red)
            }
            .coordinateSpace(name: calendarModel.name)

            // .padding(0)
            
            DayView(calendarModel: calendarModel, ymd: model.selectedYMD)
        }
        
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
                                Button(action: {
            if let monthsView = calendarModel.monthsView {
                let ymd = model.getYMD(model.selected!)
                let ymdMonth = YMD(ymd.year, ymd.month, 1)
                let monthTag = monthsView.model.getTag(ymdMonth)
                print("back to: \(monthTag)")
                monthsView.model.backFromWeek = monthTag
            }
            self.presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image(systemName: "arrow.left")
            }
        }, trailing:
                                calendarModel.cellBuilder.dayViewAdditionLink(calendarModel, model.getYMD(model.selected ?? 1), "userNav",  $model.userNavSelection)
        )
        .onAppear {
            cModel.weekViewVisible = true
            model.isVisible = true
        }
        .onDisappear {
            cModel.weekViewVisible = false
            model.isVisible = false
        }
        
    }
    
    
    @ViewBuilder
    func userAdditionLink() -> some View {
        EmptyView()
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

class WeekViewModel : ObservableObject, CalendarViewModel {
    
    var name: String = "WeekViewModel"
    
    var isVisible: Bool = false 
    
    
    @Published public var selected: Int?
    @Published public var subSelected: Int?
    
    var _uuid = UUID.init()
    
    @Published var selectedYMD: String
    @Published var userNavSelection: String? = nil
    
    var visibleItems: [Int:Bool] = [:]
    
    let numDays: Int
    var dayHeading: [String] = []
    let firstDay: Date
    var dayComponent = DateComponents()
    var dayLabels: [String] = []
    let origin: CurrentValueSubject<CGPoint, Never>
    let originPublisher: AnyPublisher<CGPoint, Never>
    var subscription: AnyCancellable? = nil
    var sem: DispatchSemaphore? = nil
    
    var tagsByYMD: [YMD:Int] = [:]
    var tagsById: [Int:YMD] = [:]
    
    let cModel: CalendarModel
    
    
    init(beginAroundYMD: String, numDays: Int, calendarModel: CalendarModel) {
        self.cModel = calendarModel
        self.numDays = numDays
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
        selectedYMD = ymDateFormatter.getYMDString(selectedDate)
        
        for day in 1...numDays {
            dayComponent.day = day - 1
            let selectedDate = ymDateFormatter.addComponents(components: dayComponent, to: firstDay)
            let ymd = ymDateFormatter.getYMD(date: selectedDate)
            addTag(ymd, day)
        }
        
        computeDayLabels(numDays: numDays)
    }
    
    func addTag(_ ymd: YMD, _ i:Int) {
        tagsByYMD[ymd] = i
        tagsById[i] = ymd
    }
    
    public func getTag(_ ymd: YMD) -> Int {
        tagsByYMD[ymd]!
    }
    
    func getYMD(_ i:Int) -> YMD {
        tagsById[i]!
    }

    
    @MainActor
    func notShowing() async -> Bool {
        let snapTo = Int(Double(selected!-1)/7.0) * 7 + 1
        return visibleItems[snapTo] == nil || visibleItems[snapTo+6] == nil
    }
    
    @MainActor
    func doScrollSnap(_ proxy: ScrollViewProxy) async -> Bool {
        let snapTo = Int(Double(selected!-1)/7.0) * 7 + 1
        proxy.scrollTo(snapTo, anchor: .leading)
        return visibleItems[snapTo] != nil && visibleItems[snapTo+6] != nil
    }
    
    func cancelSubscription() {
        subscription?.cancel()
    }
    
    func setupSubscription(_ proxy: ScrollViewProxy) {
        subscription = originPublisher.sink { [unowned self] v in
            let target = self.snap()
            withAnimation {
                proxy.scrollTo(target, anchor: .leading)
            }
            let mod = selected! % 7
            let pos = mod == 0 ? 6 : mod - 1
            if selected != target + pos {
                selected = target + pos
            }
        }
    }
    
    func snap() -> Int {
        let sorted = visibleItems.sorted(by: {$0.0 < $1.0})
        if let f = sorted.first {
            let snapTo = Int(round(Double(f.key-1)/7.0)) * 7 + 1
            return snapTo
        } else {
            return -1
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
    
    @MainActor
    func setYMD() async {
        dayComponent.day = selected! - 1
        let selectedDate = ymDateFormatter.addComponents(components: dayComponent, to: firstDay)
        selectedYMD = ymDateFormatter.getYMDString(selectedDate)
    }
    
}

struct DayView : View {
    
    @ObservedObject var calendarModel: CalendarModel
    
    let day: Date
    let monthInfo: MonthInfo
    
    init(calendarModel: CalendarModel, ymd: String) {
        self.calendarModel = calendarModel
        day = ymDateFormatter.getDate(ymd: ymd)
        monthInfo = ymDateFormatter.monthInfo(date: day)
    }
    
    var body: some View {
        Text(ldf1.dateFormatter.string(from: day))
        Divider()
            .frame(height: 0.5)
            .padding(.horizontal)
        
        ScrollView {
            VStack {
                ForEach( (0...23), id: \.self) { hour in
                    HourView(calendarModel: calendarModel, monthInfo: monthInfo, day: day, hour: hour)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 5)
            .padding(.trailing, 5)
            
        }
    }
}


struct HourView : View {
    
    @ObservedObject var calendarModel: CalendarModel
    let monthInfo: MonthInfo
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
            calendarModel.cellBuilder.dayViewHourCell(calendarModel, monthInfo, hour)
                .frame(maxWidth: .infinity)
            
        }
    }
}


struct ScrollOriginPreferenceKey: PreferenceKey {
    typealias Value = CGRect
    static var defaultValue: Value = .zero
    static func reduce(value: inout Value, nextValue:()->Value) { }
}

struct SOPreferenceKey : PreferenceKey {
    typealias Value = CGPoint
    static var defaultValue: Value = .zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = nextValue()
    }
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
    /*
     var body: some View {
         ScrollView(axes, showsIndicators: showIndicators) {
             ZStack {
             Text("0")
                 .frame(maxWidth: .infinity)
                 .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: ScrollOriginPreferenceKey.self, value: proxy.frame(in: .named("foo")))
                    })
                 VStack(spacing: 0) {
                 content
                 }
             }
         }
         .fixedSize(horizontal: false, vertical: true)
         .background(.red)
         .coordinateSpace(name: "foo")
         .onPreferenceChange(ScrollOriginPreferenceKey.self) { value in
             onOriginChange(value.origin)
         }
     }
     */
    /*
     var body: some View {
         ScrollView(axes, showsIndicators: showIndicators) {
             ZStack {
                 GeometryReader { geometry in
                     Color.clear.preference(key: ScrollOriginPreferenceKey.self, value: geometry.frame(in: .named("foo")))
                 }.frame(width:0,height:0)
                 VStack(spacing: 0) {
                 content
                 }
             }.fixedSize(horizontal: false, vertical: true).background(.red)
             
         }
         .coordinateSpace(name: "foo")
         .onPreferenceChange(ScrollOriginPreferenceKey.self) { value in
             onOriginChange(value.origin)
         }
     }
     */
    
    
    var body: some View {
        ScrollView(axes, showsIndicators: showIndicators) {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    Color.clear.preference(key: ScrollOriginPreferenceKey.self, value: geometry.frame(in: .named("name")))
                }.frame(width:0,height:0)
                content
            }.fixedSize(horizontal: false, vertical: true).background(.red)
        }
        .onPreferenceChange(ScrollOriginPreferenceKey.self) { value in
            onOriginChange(value.origin)
        }
    }
     
    
}


