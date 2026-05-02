import TelemetryCore

public extension TelemetryClient {
    func trackEvent(name: String, properties: [String: String] = [:]) async {
        let values = properties.reduce(into: [String: TelemetryValue]()) { partial, pair in
            partial[pair.key] = .hashedToken(TelemetryHash(input: pair.value))
        }

        _ = await emit(
            category: .workflow,
            name: name,
            privacyClassification: .restricted,
            values: values
        )
    }
}
