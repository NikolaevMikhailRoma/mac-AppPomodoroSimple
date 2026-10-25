import Foundation
import Testing
@testable import PomodoroCore

/// docs/engine-vectors.json: the same scenarios the Android tests run.
nonisolated(unsafe) private let scenarios: [[String: Any]] = {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/engine-vectors.json")
    let file = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    return file["scenarios"] as! [[String: Any]]
}()

/// Where every scenario's clock starts.
private let t0 = 1_000_000.0

private func intervals(_ o: Any?) -> IntervalSettings {
    try! JSONDecoder().decode(IntervalSettings.self, from: JSONSerialization.data(withJSONObject: o!))
}

private func name(_ event: EngineEvent) -> String {
    switch event {
    case .phaseFinished(let phase): return "finished \(phase.rawValue)"
    case .phaseStarted(let phase): return "started \(phase.rawValue)"
    }
}

/// The state's value against the expected one; times are from the start.
private func matches(_ actual: Any?, _ expected: Any, time: Bool) -> Bool {
    switch (actual, expected) {
    case (is NSNull, is NSNull): return true
    case (let a as String, let e as String): return a == e
    case (let a as NSNumber, let e as NSNumber): return a.doubleValue == e.doubleValue + (time ? t0 : 0)
    default: return false
    }
}

@Suite("Engine vectors")
struct EngineVectorTests {

    @Test("every scenario in docs/engine-vectors.json")
    func all() {
        #expect(!scenarios.isEmpty)
        for scenario in scenarios {
            let title = scenario["name"] as! String
            var engine = PomodoroEngine(settings: intervals(scenario["settings"]),
                                        autoStartNextInterval: scenario["autoStart"] as! Bool)
            for step in scenario["steps"] as! [[String: Any]] {
                let at = step["at"] as! Double
                let now = Date(timeIntervalSince1970: t0 + at)
                var events: [EngineEvent] = []
                switch step["do"] as! String {
                case "start": engine.start(now: now)
                case "pause": engine.pause(now: now)
                case "stop": engine.stop(now: now)
                case "skip": events = engine.skip(now: now)
                case "update": events = engine.update(now: now)
                case "setDuration": engine.setPhaseDuration(step["seconds"] as! Double, now: now)
                case "applySettings": engine.applySettings(intervals(step["settings"]), now: now)
                case let other: Issue.record("\(title): unknown step \(other)")
                }
                if let expected = step["events"] as? [String] {
                    #expect(events.map(name) == expected, "\(title), at \(at)")
                }
                let state = engine.state.json
                for (key, value) in step["expect"] as! [String: Any] {
                    #expect(matches(state[key], value, time: key == "endsAt" || key == "changedAt"),
                            "\(title), at \(at): \(key) is \(state[key] ?? "missing"), expected \(value)")
                }
            }
        }
    }
}
