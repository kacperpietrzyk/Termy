import Foundation

public struct TerminalUTF8StreamDecoder: Sendable {
    private var pending = Data()

    public init() {}

    public mutating func decode(_ data: Data) -> String {
        pending.append(data)

        if let string = String(data: pending, encoding: .utf8) {
            pending.removeAll(keepingCapacity: true)
            return string
        }

        let retainedSuffixLimit = min(3, pending.count)
        if retainedSuffixLimit > 0 {
            for retainedSuffixLength in 1...retainedSuffixLimit {
                let prefixLength = pending.count - retainedSuffixLength
                guard prefixLength > 0 else { continue }

                let prefix = pending.prefix(prefixLength)
                if let string = String(data: prefix, encoding: .utf8) {
                    pending = Data(pending.suffix(retainedSuffixLength))
                    return string
                }
            }
        }

        guard pending.count > 4 else { return "" }

        let string = String(decoding: pending, as: UTF8.self)
        pending.removeAll(keepingCapacity: true)
        return string
    }

    public mutating func flush() -> String {
        guard !pending.isEmpty else { return "" }
        let string = String(decoding: pending, as: UTF8.self)
        pending.removeAll(keepingCapacity: true)
        return string
    }
}
