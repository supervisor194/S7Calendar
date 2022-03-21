import SwiftUI

@available(iOS 15.0, *)
public struct WrappedYearlyView : View {
    
    let yearlyView: YearlyView
    let uuid: UUID

    @ObservedObject var model: YearlyViewModel
    @ObservedObject var cModel: CalendarModel
    
    let toSelect: Int
    
    
    public init(_ cModel: CalendarModel, _ toSelect: Int) {
        yearlyView = cModel.yearlyView!
        self.uuid = yearlyView.uuid
        self.model = yearlyView.model
        self.cModel = cModel
        self.toSelect = toSelect
    }
    
    public var body: some View {
        yearlyView
            .onAppear {
                if let backFromMonths = self.model.backFromMonths {
                    self.model.backFromMonths = nil
                    self.cModel.selected[uuid] = model.buildId(y:backFromMonths.y, m:backFromMonths.m)
                } else {
                    self.cModel.selected[uuid] = toSelect
                }
            }
            .onDisappear {
                self.cModel.selected[uuid] = nil
            }
            
    }
}

@available(iOS 15.0, *)
public struct YearlyView: View, CalendarView {
    
    var _uuid = UUID.init()
    
    public var uuid: UUID {
        get {
            _uuid
        }
    }
    
    public var calendarModel: CalendarModel {
        get {
            return cModel
        }
        
    }

    
    @ObservedObject var model: YearlyViewModel
    @ObservedObject var  cModel: CalendarModel
    
    @State var fontSize: CGFloat = 100
    @State var width: CGFloat = 375
    @State var columnWidth: CGFloat = 375
    @State var cellWidth: CGFloat = 375
    
    var monthItemLayout = [GridItem(.flexible(), alignment: .top),
                           GridItem(.flexible(), alignment: .top),
                           GridItem(.flexible(), alignment: .top)]
        
    public init(calendarModel: CalendarModel, begin: String, numYears: Int) {
        self.model = YearlyViewModel(begin: begin, numYears: numYears)
        self.cModel = calendarModel
    }
    
    public func toMonthsMonth(_ ym: YM) -> Int {
        model.toMonthsMonth(ym)
    }
    
    public func getIdForYM(_ ym: YM) -> Int {
        model.idForYM(y: ym.y, m: ym.m)
    }
    
    public func getIdForToday() -> Int {
        model.idForToday()
    }
    
    func getMonth(_ c: Int) -> Int {
        return (c-1)%15-2
    }
    
    public var body: some View {
        let _ = Self._printChanges()
        VStack(spacing: 0) {
            NavBarColorsView(cModel)
            Spacer()
                .frame(maxHeight: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: monthItemLayout, spacing: 0) {
                        ForEach( (1...model.numCells), id: \.self) { c in
                            buildCell(c: c)
                                .id(c)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: cModel.selected[_uuid]) { v in
                        if let target = cModel.selected[_uuid] {
                            withAnimation {
                                proxy.scrollTo(target, anchor: .center)
                            }
                        }
                    }
                }
            }.readSize { s in
                width = s.width
                columnWidth = ((s.width/3.0)-4.0)
                cellWidth = columnWidth / 7.0
                fontSize = max(floor(((s.width-8.0)/3.0)/20.0 - 1.0), 10.0)
            }
            .padding(.leading, 4)
            .padding(.trailing, 4)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button( action: {
                    // todo: perhaps use TodayInfo ???
                    let idForToday = model.idForToday()
                    if cModel.selected[_uuid] == idForToday {
                        cModel.subSelection[_uuid] = idForToday
                    }
                    cModel.selected[_uuid] = idForToday
                }) {
                    Text("Today")
                        .foregroundColor(cModel.colors.navIcons)
                }
            }
        }
    }
    
    @ViewBuilder
    func buildCell(c: Int) -> some View {
        let ym = model.idToYM(c)
        if ym.m == -2 {
            Text(String(ym.y))
                .font(.system(.title))
                .fontWeight(.bold)
                .foregroundColor(ymDateFormatter.isCurrentYear(y: ym.y) ? .red : cModel.colors.text)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if ym.m > 0 {
            NavigationLink(destination: WrappedMonthsView(cModel,
                                                          model.toMonthsMonth(ym)),
                           tag: model.toMonthsMonth(ym),
                           selection: $cModel.subSelection[_uuid]) {
                YearlyMonthView(year: ym.y, month: ym.m, calendarModel: cModel,
                                fontSize: $fontSize, columnWidth: $columnWidth, cellWidth: $cellWidth)
            }
                           .frame(maxWidth: .infinity)
            
                           .onAppear {
                               model.visibleItems[c] = true
                           }
                           .onDisappear {
                               model.visibleItems.removeValue(forKey: c)
                               if let selected = cModel.selected[_uuid] {
                                   if selected == c {
                                       cModel.selected[_uuid] = nil
                                   }
                               }
                           }
            
        } else {
            Text("foo")
                .hidden()
        }
    }
    
}

@available(iOS 15.0, macOS 11.0, *)
class YearlyViewModel : ObservableObject {
    
    // @Published var selected: Int? = nil
            
    var visibleItems: [Int: Bool] = [:]
    
    let baseYear: Int
    
    let firstMonth: Date
    let beginningMonthInfo: MonthInfo
    let numYears: Int
    let numCells: Int
    
    var tagsByYMD: [String:Int] = [:]
    var tagsById: [Int: String] = [:]
    
    var _backFromMonths: YM? = nil
    var backFromMonths: YM?  {
        get {
            _backFromMonths
        }
        set {
            _backFromMonths = newValue
        }
    }
    
    init(begin:String, numYears: Int) {
        self.beginningMonthInfo = ymDateFormatter.monthInfo(ymd: begin)
        self.baseYear = beginningMonthInfo.year
        self.firstMonth = ymDateFormatter.getDate(ymd: begin)
        self.numYears = numYears
        self.numCells = numYears * 15
    }
    
    func idForYM(y: Int, m: Int) -> Int {
        (y - beginningMonthInfo.year) * 15 + m + 3
    }
    
    func idForToday() -> Int {
        let y = TodayInfo.shared.year
        let m = TodayInfo.shared.month
        return idForYM(y: y, m: m)
    }
    
    /*
    @MainActor
    func proxySnap(_ proxy: ScrollViewProxy) async -> Int {
        if let target = selected {
            proxy.scrollTo(target, anchor: .center)
        }
        return 1
    }
    
    @MainActor
    func isVis(_ i: Int) -> Bool {
        if let v = visibleItems[i] {
            return v
        }
        return false
    }
     */
    
    func toMonthsMonth(_ ym: YM) -> Int {
        (ym.y - baseYear) * 12 + ym.m
    }
    
    func idToYM(_ id: Int) -> YM {
        let y = id / 15 + baseYear
        let m =  (id - 1) % 15 - 2
        return YM(y:y, m:m)
    }
    
    
    func buildId(y: Int, m: Int) -> Int {
        let id = (y - baseYear) * 15 + m + 3
        return id
    }

    
}


struct RowStartValue : Identifiable {
    let id: Int
}

class YearlyMonthViewModel : ObservableObject {
    
    var start: Int = 0
    var rowStarts: [RowStartValue] = []
    
    init() {
        
    }
}

struct YearlyMonthView : View {
    
    @Binding var columnWidth: CGFloat
    @Binding var cellWidth: CGFloat
    @Binding var fontSize: CGFloat
    
    @ObservedObject var model = YearlyMonthViewModel()
    @ObservedObject var calendarModel: CalendarModel
    @ObservedObject var todayInfo : TodayInfo = TodayInfo.shared

    let monthInfo: MonthInfo
    let begin: Int
    let end: Int
    let weekdayAdjustment: Int
    let start: Int
    
    
    var dayItemLayout : [GridItem] = Array(repeating: GridItem(.flexible(minimum: 5, maximum: 100), spacing: 0), count: 7)
    
    init(year: Int, month: Int, calendarModel: CalendarModel, fontSize: Binding<CGFloat>, columnWidth: Binding<CGFloat>, cellWidth: Binding<CGFloat>) {
        _fontSize = fontSize
        _columnWidth = columnWidth
        _cellWidth = cellWidth
        self.calendarModel = calendarModel
        let ymd = YMD(year, month, 1)
        self.monthInfo = ymDateFormatter.monthInfo(ymd: ymd)
        self.begin = monthInfo.weekday + 7 - ymDateFormatter.firstWeekdayAdjustment
        self.end = monthInfo.weekday + monthInfo.numDays + 6 - ymDateFormatter.firstWeekdayAdjustment
        self.weekdayAdjustment = -monthInfo.weekday - 6 + ymDateFormatter.firstWeekdayAdjustment
        if begin>7 {
            start = 8
        } else {
            start = 1
        }
        // todo: move to model
        var s = start
        while s < 42 {
            model.rowStarts.append(RowStartValue(id: s))
            s+=7
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(monthInfo.name)
                .font(.system(.title3))
                .fontWeight(.bold)
                .foregroundColor( monthInfo.month == todayInfo.month ? .red : calendarModel.colors.text)
                .frame(maxWidth: columnWidth, alignment: .leading)
            
            ForEach ( model.rowStarts  ) { rsv in
                HStack(spacing: 0) {
                    ForEach ( (0..<7) ) { i in
                        let theI = rsv.id + i
                        if theI>=begin && theI<=end {
                            let day = theI + weekdayAdjustment
                            calendarModel.cellBuilder.yearlyViewDayCell(calendarModel, monthInfo, day, fontSize)
                                .frame(width: cellWidth)
                        } else {
                            Text("88")
                                .font(.system(size: fontSize))
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .frame(width: cellWidth)
                                .hidden()
                        }
                    }
                }
            }
        }
    }
}

