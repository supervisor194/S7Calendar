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

@available(iOS 15.0, macOS 10.15, *)
extension View {
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view!
        
        let targetSize = view.intrinsicContentSize
        view.bounds = CGRect(origin: .zero, size: targetSize)
        view.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }
}
 


