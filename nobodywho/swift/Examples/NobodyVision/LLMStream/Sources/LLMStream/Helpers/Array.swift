import Foundation

extension Array {
    public subscript(safe index: Int) -> Element? {
        get {
            indices.contains(index) ? self[index] : nil
        }
        set {
            guard indices.contains(index), let newValue else { return }
            self[index] = newValue
        }
    }
}
