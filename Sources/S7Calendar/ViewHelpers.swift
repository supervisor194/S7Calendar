import SwiftUI

struct SizePreferenceKey: PreferenceKey {
    typealias Value = CGSize
    static var defaultValue: Value = .zero
    static func reduce(value: inout Value, nextValue: ()-> Value) {}
}

@available(iOS 15.0, macOS 10.15, *)
extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background( GeometryReader { g in
            Color.clear.preference(key: SizePreferenceKey.self, value: g.size)
        })
            .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}


public struct NavBarColorsView : View {
    
    let model: CalendarModel
    
    public init(_ model: CalendarModel) {
        self.model = model
    }
    
    public var body: some View {
        HStack {
        }
        .frame(maxWidth: .infinity, maxHeight: 1)
        .background(model.colors.navBackground)
    }
}
