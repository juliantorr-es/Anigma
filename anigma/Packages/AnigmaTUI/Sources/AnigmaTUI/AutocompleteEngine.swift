import Foundation

// MARK: - AutocompleteEngine
public actor AutocompleteEngine {
    private let frecency: FrecencyStore

    public init(frecency: FrecencyStore) {
        self.frecency = frecency
    }

    public func getSuggestions(for query: String, candidates: [String]) async -> [String] {
        // 1. Perform Fuzzy Match
        let matches = candidates.filter { $0.localizedCaseInsensitiveContains(query) }

        // 2. Apply Frecency Weights
        let sorted = await withTaskGroup(of: (String, Double).self) { group in
            for match in matches {
                group.addTask {
                    let score = await self.frecency.score(match)
                    return (match, score)
                }
            }

            var results: [(String, Double)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.1 > $1.1 }.map { $0.0 }
        }

        return sorted
    }
}
