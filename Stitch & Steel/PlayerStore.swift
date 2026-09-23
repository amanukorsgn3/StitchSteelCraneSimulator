import UIKit

struct LiftStage {
    let name: String
    let caption: String
    let targetSets: Int
    let lives: Int
    let wind: CGFloat
    let swayGain: CGFloat
    let placeRadius: CGFloat
    let stableLimit: CGFloat
    let hoistRate: CGFloat
    let fleetCount: Int
    let girderShare: CGFloat
    let gustRate: CGFloat

    var goalText: String {
        "GOAL  \(targetSets) SETS"
    }

    static let all = [
        LiftStage(
            name: "Slab Yard",
            caption: "CALM DECK",
            targetSets: 3,
            lives: 4,
            wind: 0.18,
            swayGain: 0.55,
            placeRadius: 0.10,
            stableLimit: 0.55,
            hoistRate: 0.55,
            fleetCount: 2,
            girderShare: 0.20,
            gustRate: 0.35
        ),
        LiftStage(
            name: "Tie Beams",
            caption: "FIRST GIRDERS",
            targetSets: 4,
            lives: 4,
            wind: 0.28,
            swayGain: 0.70,
            placeRadius: 0.09,
            stableLimit: 0.48,
            hoistRate: 0.52,
            fleetCount: 3,
            girderShare: 0.45,
            gustRate: 0.50
        ),
        LiftStage(
            name: "Cross Frame",
            caption: "MID GRID",
            targetSets: 5,
            lives: 3,
            wind: 0.38,
            swayGain: 0.82,
            placeRadius: 0.08,
            stableLimit: 0.42,
            hoistRate: 0.50,
            fleetCount: 3,
            girderShare: 0.50,
            gustRate: 0.70
        ),
        LiftStage(
            name: "Mid Rise",
            caption: "LONGER CABLE",
            targetSets: 5,
            lives: 3,
            wind: 0.48,
            swayGain: 0.95,
            placeRadius: 0.075,
            stableLimit: 0.38,
            hoistRate: 0.46,
            fleetCount: 4,
            girderShare: 0.55,
            gustRate: 0.85
        ),
        LiftStage(
            name: "Gust Front",
            caption: "HIGH WIND",
            targetSets: 6,
            lives: 3,
            wind: 0.70,
            swayGain: 1.10,
            placeRadius: 0.07,
            stableLimit: 0.34,
            hoistRate: 0.44,
            fleetCount: 4,
            girderShare: 0.55,
            gustRate: 1.20
        ),
        LiftStage(
            name: "Tight Pins",
            caption: "PRECISION SET",
            targetSets: 6,
            lives: 3,
            wind: 0.58,
            swayGain: 1.05,
            placeRadius: 0.055,
            stableLimit: 0.28,
            hoistRate: 0.42,
            fleetCount: 4,
            girderShare: 0.60,
            gustRate: 0.95
        ),
        LiftStage(
            name: "Fleet Yard",
            caption: "BUSY GROUND",
            targetSets: 7,
            lives: 3,
            wind: 0.66,
            swayGain: 1.15,
            placeRadius: 0.06,
            stableLimit: 0.30,
            hoistRate: 0.40,
            fleetCount: 6,
            girderShare: 0.65,
            gustRate: 1.10
        ),
        LiftStage(
            name: "Crown Deck",
            caption: "TOP FLOOR",
            targetSets: 8,
            lives: 2,
            wind: 0.82,
            swayGain: 1.28,
            placeRadius: 0.05,
            stableLimit: 0.24,
            hoistRate: 0.38,
            fleetCount: 5,
            girderShare: 0.70,
            gustRate: 1.35
        )
    ]
}

final class PlayerStore {
    static let shared = PlayerStore()

    private let defaults = UserDefaults.standard
    private let bestKey = "stitch_best"
    private let runsKey = "stitch_runs"
    private let hitsKey = "stitch_hits"
    private let stageKey = "stitch_stage"
    private let unlockedKey = "stitch_unlocked"
    private let soundKey = "stitch_sound"
    private let hapticsKey = "stitch_haptics"

    var best: Int { defaults.integer(forKey: bestKey) }
    var runs: Int { defaults.integer(forKey: runsKey) }
    var totalHits: Int { defaults.integer(forKey: hitsKey) }
    var stagesOpened: Int { highestUnlocked + 1 }
    var selectedStage: Int {
        get {
            let value = defaults.integer(forKey: stageKey)
            return min(max(value, 0), LiftStage.all.count - 1)
        }
        set { defaults.set(newValue, forKey: stageKey) }
    }
    var highestUnlocked: Int {
        get {
            let stored = defaults.object(forKey: unlockedKey) == nil ? 0 : defaults.integer(forKey: unlockedKey)
            return min(max(stored, 0), LiftStage.all.count - 1)
        }
        set { defaults.set(min(max(newValue, 0), LiftStage.all.count - 1), forKey: unlockedKey) }
    }
    var soundEnabled: Bool {
        get { defaults.object(forKey: soundKey) == nil ? true : defaults.bool(forKey: soundKey) }
        set { defaults.set(newValue, forKey: soundKey) }
    }
    var hapticsEnabled: Bool {
        get { defaults.object(forKey: hapticsKey) == nil ? true : defaults.bool(forKey: hapticsKey) }
        set { defaults.set(newValue, forKey: hapticsKey) }
    }

    func isUnlocked(_ index: Int) -> Bool {
        index >= 0 && index <= highestUnlocked
    }

    func bestScore(for index: Int) -> Int {
        defaults.integer(forKey: bestKey(for: index))
    }

    func finish(stageIndex: Int, score: Int, hits: Int, cleared: Bool) {
        defaults.set(runs + 1, forKey: runsKey)
        defaults.set(totalHits + hits, forKey: hitsKey)
        if score > best {
            defaults.set(score, forKey: bestKey)
        }
        if score > bestScore(for: stageIndex) {
            defaults.set(score, forKey: bestKey(for: stageIndex))
        }
        if cleared, stageIndex >= highestUnlocked, stageIndex + 1 < LiftStage.all.count {
            highestUnlocked = stageIndex + 1
        }
        if cleared {
            selectedStage = min(stageIndex + 1, LiftStage.all.count - 1)
        }
    }

    private func bestKey(for index: Int) -> String {
        "stitch_stage_best_\(index)"
    }
}

final class ProfileManager {
    static let shared = ProfileManager()

    private let nameKey = "player_display_name"
    private let photoFileName = "player_portrait.jpg"
    private var cachedPortrait: UIImage?

    private init() {}

    var displayName: String {
        get {
            let stored = UserDefaults.standard.string(forKey: nameKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let stored, !stored.isEmpty else { return "Tower Hand" }
            return stored
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: nameKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: nameKey)
            }
            NotificationCenter.default.post(name: .playerProfileDidChange, object: nil)
        }
    }

    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }
        return letters.isEmpty ? "TH" : letters.joined()
    }

    func portrait() -> UIImage? {
        if let cachedPortrait {
            return cachedPortrait
        }
        guard let data = try? Data(contentsOf: portraitAddress()),
              let image = UIImage(data: data) else {
            return nil
        }
        cachedPortrait = image
        return image
    }

    @discardableResult
    func savePortrait(_ image: UIImage) -> Bool {
        let normalized = squareThumbnail(from: image, side: 640)
        guard let data = normalized.jpegData(compressionQuality: 0.9) else { return false }
        do {
            try data.write(to: portraitAddress(), options: [.atomic])
            cachedPortrait = normalized
            NotificationCenter.default.post(name: .playerProfileDidChange, object: nil)
            return true
        } catch {
            print("[Profile] Failed to store portrait: \(error.localizedDescription)")
            return false
        }
    }

    func removePortrait() {
        cachedPortrait = nil
        try? FileManager.default.removeItem(at: portraitAddress())
        NotificationCenter.default.post(name: .playerProfileDidChange, object: nil)
    }

    private func portraitAddress() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent(photoFileName)
    }

    private func squareThumbnail(from image: UIImage, side: CGFloat) -> UIImage {
        let minimumSide = min(image.size.width, image.size.height)
        guard minimumSide > 0 else { return image }
        let cropRect = CGRect(
            x: (image.size.width - minimumSide) / 2,
            y: (image.size.height - minimumSide) / 2,
            width: minimumSide,
            height: minimumSide
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.image { _ in
            let target = CGRect(
                x: -cropRect.origin.x * side / minimumSide,
                y: -cropRect.origin.y * side / minimumSide,
                width: image.size.width * side / minimumSide,
                height: image.size.height * side / minimumSide
            )
            image.draw(in: target)
        }
    }
}

extension Notification.Name {
    static let playerProfileDidChange = Notification.Name("playerProfileDidChange")
}
