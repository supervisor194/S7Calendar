import SwiftUI

@available(iOS 15.0, *)
public struct WrappedYearlyView<Content: View> : View {
    
    let yearlyView: Content
    
    let model: YearlyViewModel
    
    let toSelect: Int
    
    
    public init(_ content: Content, _ toSelect: Int) {
        self.yearlyView = content
        let yv = content as! YearlyView
        self.model = yv.model
        self.toSelect = toSelect
    }
    
    public var body: some View {
        yearlyView
            .onAppear {
                if let backFromMonths = self.model.backFromMonths {
                    self.model.backFromMonths = nil
                    self.model.selected = model.buildId(y:backFromMonths.y, m:backFromMonths.m)
                } else {
                    self.model.selected = toSelect
                }
            }
            .onDisappear {
                self.model.selected = nil
            }
            
    }
}

@available(iOS 15.0, *)
public struct YearlyView: View {
    
    @State var fontSize: CGFloat = 100
    @State var width: CGFloat = 375
    @State var columnWidth: CGFloat = 375
    @State var cellWidth: CGFloat = 375
    
    
    @ObservedObject var model: YearlyViewModel
    let calendarModel: CalendarModel
    var monthItemLayout = [GridItem(.flexible(), alignment: .top),
                           GridItem(.flexible(), alignment: .top),
                           GridItem(.flexible(), alignment: .top)]
    
    @State var aSelection: Int? = nil
    
    public init(calendarModel: CalendarModel, begin: String, numYears: Int) {
        self.model = YearlyViewModel(begin: begin, numYears: numYears)
        self.calendarModel = calendarModel
    }
    
    public func getIdForToday() -> Int {
        model.navViaToday
    }
    
    func getMonth(_ c: Int) -> Int {
        return (c-1)%15-2
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            NavBarColorsView(calendarModel)
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
                    .onChange(of: model.selected) { v in
                        if let target = model.selected {
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
                    if model.selected == model.navViaToday {
                        aSelection = model.navViaToday
                    }
                    model.selected = model.navViaToday
                }) {
                    Text("Today")
                        .foregroundColor(calendarModel.colors.navIcons)
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
                .foregroundColor(ymDateFormatter.isCurrentYear(y: ym.y) ? .red : .black)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if ym.m > 0 {
            NavigationLink(destination: WrappedMonthsView(calendarModel.monthsView!,
                                                          model.toMonthsMonth(ym)),
                           tag: c,
                           selection: $aSelection) {
                YearlyMonthView(year: ym.y, month: ym.m, calendarModel: calendarModel,
                                fontSize: $fontSize, columnWidth: $columnWidth, cellWidth: $cellWidth)
            }
                           .frame(maxWidth: .infinity)
            
                           .onAppear {
                               model.visibleItems[c] = true
                           }
                           .onDisappear {
                               model.visibleItems.removeValue(forKey: c)
                               if let selected = model.selected {
                                   if selected == c {
                                       model.selected = nil
                                   }
                               }
                           }
            
        } else {
            Text("foo")
                .hidden()
        }
    }
    
}

struct YM {
    var y: Int
    var m: Int
}

@available(iOS 15.0, macOS 11.0, *)
class YearlyViewModel : ObservableObject {
    
    @Published var selected: Int? = nil
    
    let navViaToday: Int
    
    var yearForToday: Int
    var monthForToday: Int
    
    var visibleItems: [Int: Bool] = [:]
    
    let baseYear: Int
    
    let firstMonth: Date
    var monthComponents = DateComponents()
    let numYears: Int
    let numMonths: Int
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
        let mit = ymDateFormatter.getMIT(ymd: begin)
        self.baseYear = mit.year
        self.firstMonth = ymDateFormatter.getDate(ymd: begin)
        self.numYears = numYears
        self.numMonths = numYears * 12
        self.numCells = numYears * 15
        let y = ymDateFormatter.getYearForToday()
        let m = ymDateFormatter.getMonthForToday()
        self.yearForToday = y
        self.monthForToday = m
        self.navViaToday = (y - mit.year) * 15 + m + 3
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
    
    let mit: MonthInfoAndToday
    let begin: Int
    let end: Int
    let weekdayAdjustment: Int
    let start: Int
    
    let calendarModel: CalendarModel
    
    var dayItemLayout : [GridItem] = Array(repeating: GridItem(.flexible(minimum: 5, maximum: 100), spacing: 0), count: 7)
    
    init(year: Int, month: Int, calendarModel: CalendarModel, fontSize: Binding<CGFloat>, columnWidth: Binding<CGFloat>, cellWidth: Binding<CGFloat>) {
        _fontSize = fontSize
        _columnWidth = columnWidth
        _cellWidth = cellWidth
        self.calendarModel = calendarModel
        self.mit = ymDateFormatter.getMIT(ymd: String(year) + " " + String(month) + " 1")
        self.begin = mit.weekday + 7 - ymDateFormatter.firstWeekdayAdjustment
        self.end = mit.weekday + mit.count + 6 - ymDateFormatter.firstWeekdayAdjustment
        self.weekdayAdjustment = -mit.weekday - 6 + ymDateFormatter.firstWeekdayAdjustment
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
            Text(mit.name)
                .font(.system(.title3))
                .fontWeight(.bold)
                .foregroundColor(mit.isMonth ? .red : calendarModel.colors.text)
                .frame(maxWidth: columnWidth, alignment: .leading)
            
            ForEach ( model.rowStarts  ) { rsv in
                HStack(spacing: 0) {
                    ForEach ( (0..<7) ) { i in
                        let theI = rsv.id + i
                        if theI>=begin && theI<=end {
                            let day = theI + weekdayAdjustment
                            calendarModel.cellBuilder.yearlyViewDayCell(calendarModel, mit, day, fontSize)
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

