import Foundation
import SwiftUI

public enum VoteType: String, Codable, CaseIterable {
    case interested = "Interested"
    case notInterested = "Not interested"
    
    public var icon: String {
        switch self {
        case .interested: return "checkmark.circle.fill"
        case .notInterested: return "xmark.circle.fill"
        }
    }
}

public struct Comment: Identifiable, Codable {
    public let id: UUID
    public let author: String
    public let text: String
    
    public init(id: UUID = UUID(), author: String, text: String) {
        self.id = id
        self.author = author
        self.text = text
    }
}

/// A member who voted YES on a trip item, with their display initial & color name
public struct YesVoter: Identifiable, Codable {
    public let id: UUID
    public let initial: String   // "K", "S", "A", "R"
    public let fullName: String  // "Kashish", "Saurabh", "Arjun", "Riya"
    public let colorHex: String  // for avatar color
    
    public init(id: UUID = UUID(), initial: String, fullName: String, colorHex: String) {
        self.id = id
        self.initial = initial
        self.fullName = fullName
        self.colorHex = colorHex
    }
}

public struct TripItem: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var category: String      // "Activity", "Restaurant", "Event"
    public var location: String
    public var imageName: String
    public var ownerName: String     // "K", "S", "A", "R"
    public var ownerFullName: String // "Kashish", "Saurabh", etc.
    public var addedTimeAgo: String
    public var thumbsUpCount: Int
    public var thumbsDownCount: Int
    public var userVote: String?     // "up", "down", nil
    public var duration: String
    public var noteText: String?
    public var noteAuthor: String?
    public var noteTimeAgo: String?
    
    // ── New fields for Day-wise + YES voters + conflict ──
    public var day: Int              // 1, 2, 3 …
    public var tripDate: String      // "Fri, 18 Jul"
    public var timeSlot: String      // "11:30 AM – 2:00 PM"
    public var yesVoters: [YesVoter] // who voted YES
    public var hasConflict: Bool
    public var conflictMessage: String?
    public var isConfirmed: Bool     // true = all in / locked
    
    public init(
        id: UUID = UUID(),
        title: String,
        category: String,
        location: String,
        imageName: String,
        ownerName: String,
        ownerFullName: String = "",
        addedTimeAgo: String,
        thumbsUpCount: Int,
        thumbsDownCount: Int,
        userVote: String? = nil,
        duration: String,
        noteText: String? = nil,
        noteAuthor: String? = nil,
        noteTimeAgo: String? = nil,
        day: Int = 1,
        tripDate: String = "",
        timeSlot: String = "",
        yesVoters: [YesVoter] = [],
        hasConflict: Bool = false,
        conflictMessage: String? = nil,
        isConfirmed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.location = location
        self.imageName = imageName
        self.ownerName = ownerName
        self.ownerFullName = ownerFullName.isEmpty ? ownerName : ownerFullName
        self.addedTimeAgo = addedTimeAgo
        self.thumbsUpCount = thumbsUpCount
        self.thumbsDownCount = thumbsDownCount
        self.userVote = userVote
        self.duration = duration
        self.noteText = noteText
        self.noteAuthor = noteAuthor
        self.noteTimeAgo = noteTimeAgo
        self.day = day
        self.tripDate = tripDate
        self.timeSlot = timeSlot
        self.yesVoters = yesVoters
        self.hasConflict = hasConflict
        self.conflictMessage = conflictMessage
        self.isConfirmed = isConfirmed
    }
}

public struct AIRecommendation: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var price: String
    public var time: String
    public var distance: String
    public var description: String
    public var matchReason: String
    public var slots: Int
    public var imageName: String
    
    public init(id: UUID = UUID(), title: String, price: String, time: String, distance: String, description: String, matchReason: String, slots: Int, imageName: String) {
        self.id = id
        self.title = title
        self.price = price
        self.time = time
        self.distance = distance
        self.description = description
        self.matchReason = matchReason
        self.slots = slots
        self.imageName = imageName
    }
}

public struct Proposal: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var suggestedBy: String
    public var proposedTime: String
    public var price: String
    public var distance: String
    public var reason: String
    public var slots: String
    public var decisionDeadline: String
    public var votes: [String: VoteType]
    public var comments: [Comment]
    public var isApproved: Bool
    public var alternativeSpaOption: String?
    public var itineraryItems: [AIRecommendation]?
    
    public init(id: UUID = UUID(), title: String, suggestedBy: String, proposedTime: String, price: String, distance: String, reason: String, slots: String, decisionDeadline: String, votes: [String : VoteType] = [:], comments: [Comment] = [], isApproved: Bool = false, alternativeSpaOption: String? = nil, itineraryItems: [AIRecommendation]? = nil) {
        self.id = id
        self.title = title
        self.suggestedBy = suggestedBy
        self.proposedTime = proposedTime
        self.price = price
        self.distance = distance
        self.reason = reason
        self.slots = slots
        self.decisionDeadline = decisionDeadline
        self.votes = votes
        self.comments = comments
        self.isApproved = isApproved
        self.alternativeSpaOption = alternativeSpaOption
        self.itineraryItems = itineraryItems
    }
}

public struct ChatMessage: Identifiable, Codable {
    public let id: UUID
    public var sender: String
    public var text: String
    public var recommendations: [AIRecommendation]?
    
    public init(id: UUID = UUID(), sender: String, text: String, recommendations: [AIRecommendation]? = nil) {
        self.id = id
        self.sender = sender
        self.text = text
        self.recommendations = recommendations
    }
}

public struct AddSearchItem: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var category: String
    public var subtitle: String?
    public var imageName: String
    public var visitTimeSlot: String
    public var isBookmarked: Bool
    
    public init(
        id: UUID = UUID(),
        title: String,
        category: String,
        subtitle: String? = nil,
        imageName: String,
        visitTimeSlot: String = "",
        isBookmarked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.subtitle = subtitle
        self.imageName = imageName
        self.visitTimeSlot = visitTimeSlot
        self.isBookmarked = isBookmarked
    }
}

enum ItineraryTiming {
    static let arrivalBufferMinutes = 30
    static let pollDurationMinutes = 15

    static func pollWindow(
        tripDate: String,
        timeSlot: String,
        relativeTo referenceDate: Date = Date()
    ) -> (startsAt: Date, endsAt: Date)? {
        guard let activityStartsAt = activityStartDate(
            tripDate: tripDate,
            timeSlot: timeSlot,
            relativeTo: referenceDate
        ),
        let pollStartsAt = Calendar.current.date(
            byAdding: .minute,
            value: -arrivalBufferMinutes,
            to: activityStartsAt
        ),
        let pollEndsAt = Calendar.current.date(
            byAdding: .minute,
            value: pollDurationMinutes,
            to: pollStartsAt
        ) else {
            return nil
        }

        return (pollStartsAt, pollEndsAt)
    }

    static func pollOpeningTimeText(for timeSlot: String) -> String? {
        let separator = timeSlot.range(of: " – ") ?? timeSlot.range(of: "-")
        let startText = separator.map { String(timeSlot[..<$0.lowerBound]) } ?? timeSlot
        let trimmedStart = startText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedStart.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "h:mm a"

        guard let activityStart = formatter.date(from: trimmedStart),
              let pollStart = Calendar.current.date(
                byAdding: .minute,
                value: -arrivalBufferMinutes,
                to: activityStart
              ) else {
            return nil
        }
        return formatter.string(from: pollStart)
    }

    private static func activityStartDate(
        tripDate: String,
        timeSlot: String,
        relativeTo referenceDate: Date
    ) -> Date? {
        let separator = timeSlot.range(of: " – ") ?? timeSlot.range(of: "-")
        let startText = separator.map { String(timeSlot[..<$0.lowerBound]) } ?? timeSlot
        let trimmedStart = startText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tripDate.isEmpty, !trimmedStart.isEmpty else { return nil }

        let dateHasYear = tripDate.range(of: #"\b\d{4}\b"#, options: .regularExpression) != nil
        let year = Calendar.current.component(.year, from: referenceDate)
        let datedText = dateHasYear ? tripDate : "\(tripDate) \(year)"

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.isLenient = true

        let formats = [
            "EEE, d MMM yyyy h:mm a",
            "d MMM yyyy h:mm a"
        ]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: "\(datedText) \(trimmedStart)") {
                return date
            }
        }
        return nil
    }
}

enum DemoCollaboration {
    private static let kashish = YesVoter(
        initial: "K",
        fullName: "Kashish",
        colorHex: "ec4899"
    )
    private static let saurabh = YesVoter(
        initial: "S",
        fullName: "Saurabh",
        colorHex: "7c5cfc"
    )
    private static let arjun = YesVoter(
        initial: "A",
        fullName: "Arjun",
        colorHex: "22d3a5"
    )
    private static let riya = YesVoter(
        initial: "R",
        fullName: "Riya",
        colorHex: "fbbf24"
    )

    static func applyingSample(to item: TripItem, index: Int) -> TripItem {
        var updated = item

        switch index % 4 {
        case 0:
            updated.thumbsUpCount = 4
            updated.thumbsDownCount = 0
            updated.userVote = "up"
            updated.yesVoters = [kashish, saurabh, arjun, riya]
            updated.isConfirmed = true
        case 1:
            updated.thumbsUpCount = 2
            updated.thumbsDownCount = 0
            updated.userVote = nil
            updated.yesVoters = [saurabh, arjun]
            updated.isConfirmed = false
        case 2:
            updated.thumbsUpCount = 3
            updated.thumbsDownCount = 1
            updated.userVote = "up"
            updated.yesVoters = [kashish, saurabh, arjun]
            updated.isConfirmed = false
        default:
            updated.thumbsUpCount = 1
            updated.thumbsDownCount = 1
            updated.userVote = "down"
            updated.yesVoters = [riya]
            updated.isConfirmed = false
        }

        return updated
    }
}

public struct Collaborator: Identifiable {
    public let id: UUID
    public var name: String
    public var initial: String
    public var colorHex: String
    public var role: String

    public init(id: UUID = UUID(), name: String, initial: String, colorHex: String, role: String) {
        self.id = id
        self.name = name
        self.initial = initial
        self.colorHex = colorHex
        self.role = role
    }
}

// ── Color from hex helper ──────────────────────────────────────────────
extension Color {
    public init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8)  & 0xFF) / 255.0
        let b = Double( rgb        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
