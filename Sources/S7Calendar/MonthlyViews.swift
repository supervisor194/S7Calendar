import SwiftUI



public struct WrappedMonthsView<Content: View> : View {
    
    let monthsView: Content
    
    let model: MonthsViewModel
    
    let toSelect: Int
    
    init(_ content: Content, _ toSelect: Int) {
        self.monthsView = content
        let mv = monthsView as! MonthsView
        self.model = mv.model
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



public struct MonthsView : View {
    
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var model : MonthsViewModel
    
    @State var fontSize: CGFloat = 30
    
    let calendarModel: CalendarModel
    
    public init(calendarModel: CalendarModel, begin: String, numMonths: Int) {
        self.model = MonthsViewModel(begin: begin, numMonths: numMonths)
        self.calendarModel = calendarModel
    }
    
    
    
    func createMonthView(_ i: Int) -> MonthView {
        if let v = model.monthView[i] {
            return v
        }
        let v = MonthView(ymd: model.getYMD(i), calendarModel: calendarModel, fontSize: $fontSize)
        model.monthView[i] = v
        return v
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView() {
                    LazyVStack(spacing: 20) {
                        ForEach(1..<model.numMonths) { i  in
                            createMonthView(i)
                                .id(i)
                                .onAppear {
                                    model.visibleItems[Int(i)] = true
                                    //model.computeToolbarYear()
                                }
                                .onDisappear {
                                    model.visibleItems.removeValue(forKey:Int(i))
                                    //model.computeToolbarYear()
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
                .navigationBarTitle(model.toolbarYear)
                .navigationBarBackButtonHidden(true)
                .navigationBarItems(leading:
                                        Button(action: {
                    if let yearlyView = calendarModel.yearlyView {
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
                        }
                    }
                }
            }
            
        }
        
        .readSize { s in
            let fs = max(floor(s.width/20.0 - 1.0), 10.0)
            if fs != fontSize {
                fontSize = fs
            }
        }
    }
}




public class MonthsViewModel : ObservableObject {
    
    @Published var selected: Int? = nil
    @Published var toolbarYear: String = ""
    
    var monthView: [Int:MonthView] = [:]
    
    var visibleItems: [Int:Bool] = [:]
    
    let baseYear: Int
    let baseMonth: Int
    
    let firstMonth: Date
    var monthComponents = DateComponents()
    
    var begin: String
    let numMonths: Int
    
    var tagsByYMD : [String: Int] = [:]
    var tagsById : [Int:String] = [:]
    
    var _backFromWeek: Int? = nil
    var backFromWeek: Int? {
        get {
            return _backFromWeek
        }
        set {
            _backFromWeek = newValue
        }
    }
    
    init(begin: String, numMonths: Int) {
        self.begin = begin
        let mit = ymDateFormatter.getMIT(ymd: begin)
        self.baseYear = mit.year
        self.baseMonth = mit.month
        
        self.firstMonth = ymDateFormatter.getDate(ymd: begin)
        self.numMonths = numMonths
        
        for month in 1...numMonths {
            monthComponents.month = month - 1
            let selectedDate = ymDateFormatter.addComponents(components: monthComponents, to: firstMonth)
            let ymd = ymDateFormatter.getYMDForDate(selectedDate)
            addTag(ymd, month)
        }
    }
    
    func addTag(_ ymd: String, _ month: Int) {
        tagsByYMD[ymd] = month
        tagsById[month] = ymd
    }
    
    func getTag(_ ymd: String) -> Int {
        tagsByYMD[ymd]!
    }
    
    func getYMD(_ id: Int) -> String {
        tagsById[id]!
    }
    
    func findMonthForToday() -> Int {
        let ymd = ymDateFormatter.getYMDMonthForToday()
        return getTag(ymd)
    }
    
    @MainActor
    func isSnapToVisible() async -> Bool {
        if let selected = selected {
            return visibleItems[selected] != nil
        }
        return false
    }
    
    @MainActor
    func doScrollSnap(_ proxy: ScrollViewProxy) async -> Int {
        if let selected = selected {
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
    
    func computeToolbarYear() {
        var m = 7000
        let yearCounts = visibleItems.keys.reduce(into: [Int:Int]()) {  // $0 [:]  $1 == 'id'
            let y = baseYear + ($1-1)/12
            m = min(y,m)
            $0[y,default:0] += 1
        }
        if yearCounts.count > 0 {
            let sorted = yearCounts.sorted { return $0.value < $1.value }
            let equalCounts = sorted.allSatisfy { $0.value == sorted.first!.value }
            toolbarYear = equalCounts ? String(m) : String(sorted.last!.key)
        }
    }
    
}


public struct MonthView : View {
    
    @Binding var fontSize: CGFloat
    
    let mit: MonthInfoAndToday
    let begin: Int
    let end: Int
    let calendarModel: CalendarModel
    
    let weekdayAdjustment: Int
    
    var dayItemLayout : [GridItem] = Array(repeating:
                                            GridItem(.flexible(minimum: 5, maximum: 100),  spacing: 0), count: 7)
    
    
    init(ymd: String, calendarModel: CalendarModel, fontSize: Binding<CGFloat>) {
        self.mit = ymDateFormatter.getMIT(ymd: ymd)
        
        var begin = mit.weekday + 7 - ymDateFormatter.firstWeekdayAdjustment
        var doSub = false
        if begin-7 <= 0 {
            begin += 7
            doSub = true
        }
        self.begin = begin
        // self.begin = mit.weekday + 7 - ymDateFormatter.firstWeekdayAdjustment
        self.end = self.begin + mit.count - 1
        // self.end = mit.weekday + mit.count + 6 - ymDateFormatter.firstWeekdayAdjustment // where 6 is from -1 + 7
        self.calendarModel = calendarModel
        self._fontSize = fontSize
        self.weekdayAdjustment = -mit.weekday - 6 + ymDateFormatter.firstWeekdayAdjustment - (doSub ? 7 : 0)
        
    }
    
    
    public var body: some View {
        LazyVGrid(columns: dayItemLayout) {
            ForEach( (1..<50) ) { i in
                if i>=begin && i<=end  {
                    let day = i + weekdayAdjustment
                    calendarModel.cellBuilder.monthlyViewDayCell(calendarModel, mit, day, fontSize)
                } else if i == begin - 7 {
                    calendarModel.cellBuilder.monthlyViewNameCell(calendarModel, mit, fontSize)
                } else {
                    calendarModel.cellBuilder.monthlyViewEmptyCell(calendarModel, fontSize)
                }
            }
            
        }
        
    }
}

