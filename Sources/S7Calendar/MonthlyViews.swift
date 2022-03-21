import SwiftUI



public struct WrappedMonthsView<Content: View> : View {
    
    let monthsView: Content
    
    @ObservedObject var model: MonthsViewModel
    @ObservedObject var cModel: CalendarModel

    let toSelect: Int
    let uuid: UUID
    
    init(_ content: Content,  _ calendarModel: CalendarModel, _ toSelect: Int) {
        self.monthsView = content
        let mv = monthsView as! MonthsView
        self.model = mv.model
        self.cModel = calendarModel
        self.uuid = mv.uuid
        self.toSelect = toSelect
    }
    
    public var body: some View {
        monthsView
            .onAppear {
                if let backFromWeek = self.model.backFromWeek {
                    self.model.backFromWeek = nil
                    self.cModel.selected[uuid] = backFromWeek
                } else {
                    self.cModel.selected[uuid] = toSelect
                }
            }
            .onDisappear {
                self.cModel.selected[uuid] = nil
            }
    }
    
}



public struct MonthsView : View, CalendarView {
    
    
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
    
    @ObservedObject var model : MonthsViewModel
    @ObservedObject var todayInfo: TodayInfo = .shared
    @ObservedObject var cModel: CalendarModel

    @State var fontSize: CGFloat = 30
    

    public init(calendarModel: CalendarModel, begin: String, numMonths: Int) {
        self.model = MonthsViewModel(begin: begin, numMonths: numMonths, calendarModel: calendarModel)
        self.cModel = calendarModel
    }
    
    
    func createMonthView(_ i: Int) -> MonthView {
        if let v = model.monthView[i] {
            return v
        }
        let v = MonthView(ymd: model.getYMD(i), calendarModel: cModel, fontSize: $fontSize)
        model.monthView[i] = v
        return v
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            NavBarColorsView(cModel)
            ScrollViewReader { proxy in
                ScrollView() {
                    LazyVStack(spacing: 20) {
                        ForEach(1..<model.numMonths) { i  in
                            createMonthView(i)
                                .id(i)
                                .onAppear {
                                    model.setVisible(i, true)
                                }
                                .onDisappear {
                                    model.setVisible(i, false)
                                }
                            
                        }.frame(maxWidth: .infinity)
                    }
                    .onChange(of: cModel.selected[uuid]) { v in
                        if let target = cModel.selected[uuid] {
                            withAnimation {
                                proxy.scrollTo(target, anchor: .center)
                            }
                        }
                    }
                }
                
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarTitle(model.toolbarYear)
                .navigationBarBackButtonHidden(true)
                .navigationBarItems(leading:
                                        Button(action: {
                    if let yearlyView = cModel.yearlyView {
                        yearlyView.model.backFromMonths = model.earliestVisible()
                    }
                    self.presentationMode.wrappedValue.dismiss()
                    
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                    }
                })
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button( action: {
                            let snapTo = model.findMonthForToday()
                            withAnimation {
                                proxy.scrollTo(snapTo, anchor: .center)
                            }
                        }) {
                            Text("Today")
                                .foregroundColor(cModel.colors.navIcons)
                        }
                    }
                }
            }.readSize { s in
                let fs = max(floor(s.width/20.0 - 1.0), 10.0)
                if fs != fontSize {
                    fontSize = fs
                }
            }
            
        }
        
        /*
         */
        
    }
}




public class MonthsViewModel : ObservableObject {
    
    var _uuid = UUID.init()

    
    // @Published var selected: Int? = nil
    @Published var toolbarYear: String = ""
    
    var monthView: [Int:MonthView] = [:]
    
    var visibleItems: [Int:Bool] = [:]
    
    let baseYear: Int
    let baseMonth: Int
    
    let firstMonth: Date
    var monthComponents = DateComponents()
    
    var begin: String
    let numMonths: Int
    
    var tagsByYMD : [YMD: Int] = [:]
    var tagsById : [Int:YMD] = [:]
    
    var _backFromWeek: Int? = nil
    var backFromWeek: Int? {
        get {
            return _backFromWeek
        }
        set {
            _backFromWeek = newValue
        }
    }
    
    let cModel: CalendarModel
    
    init(begin: String, numMonths: Int, calendarModel: CalendarModel) {
        self.cModel = calendarModel
        self.begin = begin
        let mit = ymDateFormatter.monthInfo(ymd: begin)
        self.baseYear = mit.year
        self.baseMonth = mit.month
        
        self.firstMonth = ymDateFormatter.getDate(ymd: begin)
        self.numMonths = numMonths
        
        for month in 1...numMonths {
            monthComponents.month = month - 1
            let selectedDate = ymDateFormatter.addComponents(components: monthComponents, to: firstMonth)
            let ymd = ymDateFormatter.getYMD(date: selectedDate)
            addTag(ymd, month)
        }
    }
    
    func addTag(_ ymd: YMD, _ month: Int) {
        tagsByYMD[ymd] = month
        tagsById[month] = ymd
    }
    
    func getTag(_ ymd: YMD) -> Int {
        tagsByYMD[ymd]!
    }
    
    func getYMD(_ id: Int) -> YMD {
        tagsById[id]!
    }
    
    // use TodayInfo
    func findMonthForToday() -> Int {
        let ymd = TodayInfo.shared.ymd
        let ymdMonth = YMD(ymd.year, ymd.month, 1)
        return getTag(ymdMonth)
    }
    
    @MainActor
    func isSnapToVisible() async -> Bool {
        if let selected = cModel.selected[_uuid] {
            return visibleItems[selected] != nil
        }
        return false
    }
    
    @MainActor
    func doScrollSnap(_ proxy: ScrollViewProxy) async -> Int {
        if let selected = cModel.selected[_uuid] {
            proxy.scrollTo(selected, anchor: .center)
        }
        return 1
    }
    
    func earliestVisible() -> YM {
        if visibleItems.count > 0 {
            let sorted = visibleItems.sorted { $0.0 < $1.0 }
            let month = sorted.first!.key
            let y = month/12 + baseYear
            let m = (month-1)%12 + 1
            return YM(y:y,m:m)
        }
        return YM(y:0,m:0)
    }
    
    func setVisible(_ i:Int, _ b: Bool) {
        if b {
            visibleItems[i] = true
        } else {
            visibleItems.removeValue(forKey: i)
        }
        var m = 7000
        if visibleItems.keys.count > 0 {
            let yearCounts = visibleItems.keys.reduce(into: [Int:Int]()) {  // $0 [:]  $1 == 'id'
                let y = baseYear + ($1-1)/12
                m = min(y,m)
                $0[y,default:0] += 1
            }
            let sorted = yearCounts.sorted { return $0.value < $1.value }
            let equalCounts = sorted.allSatisfy { $0.value == sorted.first!.value }
            toolbarYear = equalCounts ? String(m) : String(sorted.last!.key)
        } else {
            toolbarYear = ""
        }
    }
    
}


public struct MonthView : View {
    
    @ObservedObject var calendarModel: CalendarModel

    @Binding var fontSize: CGFloat
    
    let monthInfo: MonthInfo
    let begin: Int
    let end: Int
    
    let weekdayAdjustment: Int
    
    var dayItemLayout : [GridItem] = Array(repeating:
                                            GridItem(.flexible(minimum: 5, maximum: 100),  spacing: 0), count: 7)
    
    
    init(ymd: YMD, calendarModel: CalendarModel, fontSize: Binding<CGFloat>) {
        self.calendarModel = calendarModel
        self.monthInfo = ymDateFormatter.monthInfo(ymd: ymd)
        
        var begin = monthInfo.weekday + 7 - ymDateFormatter.firstWeekdayAdjustment
        var doSub = false
        if begin-7 <= 0 {
            begin += 7
            doSub = true
        }
        self.begin = begin
        // self.begin = mit.weekday + 7 - ymDateFormatter.firstWeekdayAdjustment
        self.end = self.begin + monthInfo.numDays - 1
        // self.end = mit.weekday + mit.count + 6 - ymDateFormatter.firstWeekdayAdjustment // where 6 is from -1 + 7
        self._fontSize = fontSize
        self.weekdayAdjustment = -monthInfo.weekday - 6 + ymDateFormatter.firstWeekdayAdjustment - (doSub ? 7 : 0)
        
    }
    
    
    public var body: some View {
        LazyVGrid(columns: dayItemLayout) {
            ForEach( (1..<50) ) { i in
                if i>=begin && i<=end  {
                    let day = i + weekdayAdjustment
                    NavigationLink(destination: WrappedWeekView(calendarModel.weekView,
                                                                calendarModel.weekView!.getTagForDay(day: day, monthInfo: monthInfo))) {
                    calendarModel.cellBuilder.monthlyViewDayCell(calendarModel, monthInfo, day, fontSize)
                    }
                } else if i == begin - 7 {
                    calendarModel.cellBuilder.monthlyViewNameCell(calendarModel, monthInfo, fontSize)
                } else {
                    calendarModel.cellBuilder.monthlyViewEmptyCell(calendarModel, fontSize)
                }
            }
            
        }
        
    }
}

