import SwiftUI



public struct WrappedMonthsView: View {
    
    let monthsView: MonthsView
    let uuid: UUID
    
    @ObservedObject var model: MonthsViewModel
    @ObservedObject var cModel: CalendarModel
    
    let toSelect: Int
    
    init(_ cModel: CalendarModel, _ toSelect: Int) {
        self.monthsView = cModel.monthsView!
        self.uuid = monthsView.uuid
        self.model = monthsView.model
        self.cModel = cModel
        self.toSelect = toSelect
    }
    
    public var body: some View {
        monthsView
            .onAppear {
                if let backFromWeek = self.model.backFromWeek {
                    self.model.backFromWeek = nil
                    self.model.selected = backFromWeek
                } else {
                    self.model.selected = toSelect
                }
            }
            .onDisappear {
                self.model.selected = nil
            }
    }
    
}



public struct MonthsView : View, CalendarView {
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
    
    @ObservedObject var model : MonthsViewModel
    @ObservedObject var todayInfo: TodayInfo = .shared
    @ObservedObject var cModel: CalendarModel
    
    @State var fontSize: CGFloat = 30
    
    public init(calendarModel: CalendarModel, begin: String, numMonths: Int) {
        self.model = MonthsViewModel(begin: begin, numMonths: numMonths, calendarModel: calendarModel)
        self.cModel = calendarModel
    }
    
    public func idForYMD(_ ymd: YMD) -> Int {
        let id = cModel.weekView!.model.getTag(ymd)
        return id
    }
    
    public func getIdForToday() -> Int {
        model.findMonthForToday()
    }
    
    func createMonthView(_ i: Int) -> MonthView {
        if let v = model.monthView[i] {
            return v
        }
        let v = MonthView(ymd: model.getYMD(i), calendarModel: cModel, parentModel: model, fontSize: $fontSize)
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
                    .onChange(of: model.selected) { v in
                        if let target = model.selected {
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
    }
}




public class MonthsViewModel : ObservableObject, CalendarViewModel {
    
    @Published public var selected: Int?
    @Published public var subSelected: Int?
    
    var _uuid = UUID.init()
    
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

public class MonthViewModel : ObservableObject, CalendarViewModel {
    
    @Published public var selected: Int?
    @Published public var subSelected: Int?
    
}

public struct MonthView : View {
    
    @ObservedObject var calendarModel: CalendarModel
    @ObservedObject var model:  MonthsViewModel
    @Binding var fontSize: CGFloat
    
    let monthInfo: MonthInfo
    let begin: Int
    let end: Int
    let uuid: UUID
    let weekdayAdjustment: Int
    
    var dayItemLayout : [GridItem] = Array(repeating:
                                            GridItem(.flexible(minimum: 5, maximum: 100),  spacing: 0), count: 7)
    
    
    init(ymd: YMD, calendarModel: CalendarModel, parentModel: MonthsViewModel, fontSize: Binding<CGFloat>) {
        self.calendarModel = calendarModel
        self.model = parentModel
        self.uuid = calendarModel.monthsView!.uuid
        
        self.monthInfo = ymDateFormatter.monthInfo(ymd: ymd)
        
        var begin = monthInfo.weekday + 7 - ymDateFormatter.firstWeekdayAdjustment
        var doSub = false
        if begin-7 <= 0 {
            begin += 7
            doSub = true
        }
        self.begin = begin
        self.end = self.begin + monthInfo.numDays - 1
        self._fontSize = fontSize
        self.weekdayAdjustment = -monthInfo.weekday - 6 + ymDateFormatter.firstWeekdayAdjustment - (doSub ? 7 : 0)
    }
    
    public var body: some View {
        LazyVGrid(columns: dayItemLayout) {
            ForEach( (1..<50) ) { i in
                if i>=begin && i<=end  {
                    let day = i + weekdayAdjustment
                    if let weekView = calendarModel.weekView {
                        let id = weekView.getIdForYMD(YMD(monthInfo.year, monthInfo.month, day))
                        NavigationLink(destination: WrappedWeekView(calendarModel, id),
                                       tag: id,
                                       selection: $model.subSelected) {
                            calendarModel.cellBuilder.monthlyViewDayCell(calendarModel, monthInfo, day, fontSize)
                        }
                    }
                    else {
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

