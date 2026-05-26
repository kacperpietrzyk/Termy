import Foundation

public struct CommandRegistry: Sendable {
    public let actions: [CommandAction]

    public init(actions: [CommandAction]) {
        self.actions = actions
    }

    public func search(_ query: String) -> [CommandAction] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return actions }

        let tokens = normalizedQuery.split(separator: " ").map(String.init)
        return actions
            .compactMap { action -> (CommandAction, Int)? in
                let haystack = ([action.id, action.title, action.subtitle] + action.keywords)
                    .joined(separator: " ")
                    .lowercased()
                guard tokens.allSatisfy({ haystack.contains($0) }) else {
                    return nil
                }

                var score = 0
                if action.id == normalizedQuery || action.title.lowercased() == normalizedQuery {
                    score += 100
                }
                if action.id.contains(normalizedQuery) {
                    score += 40
                }
                if action.title.lowercased().contains(normalizedQuery) {
                    score += 30
                }
                score += action.keywords.filter { $0.lowercased().contains(normalizedQuery) }.count * 20
                return (action, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.title < rhs.0.title
                }
                return lhs.1 > rhs.1
            }
            .map(\.0)
    }
}
