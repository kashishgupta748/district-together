import SwiftUI

public struct TripItemCard: View {
    private static let demoCollaborators: [YesVoter] = [
        YesVoter(initial: "K", fullName: "Kashish", colorHex: "ec4899"),
        YesVoter(initial: "S", fullName: "Saurabh", colorHex: "7c5cfc"),
        YesVoter(initial: "A", fullName: "Arjun", colorHex: "22d3a5"),
        YesVoter(initial: "R", fullName: "Riya", colorHex: "fbbf24")
    ]

    public let item: TripItem
    public let onVoteUp: () -> Void
    public let onVoteDown: () -> Void
    public let onAddAlternative: () -> Void
    public let onAddNote: () -> Void
    public let onAddToList: () -> Void
    public let onRemoveFromList: () -> Void

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(item: TripItem, onVoteUp: @escaping () -> Void, onVoteDown: @escaping () -> Void, onAddAlternative: @escaping () -> Void, onAddNote: @escaping () -> Void, onAddToList: @escaping () -> Void = {}, onRemoveFromList: @escaping () -> Void = {}) {
        self.item = item
        self.onVoteUp = onVoteUp
        self.onVoteDown = onVoteDown
        self.onAddAlternative = onAddAlternative
        self.onAddNote = onAddNote
        self.onAddToList = onAddToList
        self.onRemoveFromList = onRemoveFromList
    }

    private var isAllIn: Bool {
        return item.thumbsUpCount >= 4 && item.thumbsDownCount == 0
    }

    private var borderColor: Color {
        if isAllIn { return Color(hex: "22d3a5").opacity(0.45) }
        if item.hasConflict { return Color.red.opacity(0.28) }
        return Color.white.opacity(0.07)
    }

    private var pollWindow: (startsAt: Date, endsAt: Date)? {
        ItineraryTiming.pollWindow(
            tripDate: item.tripDate,
            timeSlot: item.timeSlot,
            relativeTo: now
        )
    }

    private var isVotingOpen: Bool {
        guard let pollWindow else { return false }
        return now >= pollWindow.startsAt && now < pollWindow.endsAt
    }

    private var canVote: Bool {
        guard let pollWindow else { return true }
        return now < pollWindow.endsAt
    }

    private var pollStatusText: String? {
        guard let pollWindow else {
            if let openingTime = ItineraryTiming.pollOpeningTimeText(for: item.timeSlot) {
                return "Opens \(openingTime) · 15 min poll"
            }
            return "Opens 30 min before · 15 min poll"
        }
        let openingTime = pollWindow.startsAt.formatted(
            date: .omitted,
            time: .shortened
        )
        if now < pollWindow.startsAt {
            return "Opens \(openingTime) · 15 min poll"
        }
        if now < pollWindow.endsAt {
            let remaining = max(0, Int(pollWindow.endsAt.timeIntervalSince(now)))
            let countdown = String(format: "%02d:%02d", remaining / 60, remaining % 60)
            return "Opened \(openingTime) · \(countdown) left"
        }
        return "Opened \(openingTime) · Submitted"
    }

    // ─── Sub-views to assist Swift compiler type-checking ──────────

    @ViewBuilder
    private var topRowView: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbView
                .frame(width: 72, height: 72)
                .cornerRadius(12)
                .clipped()

            VStack(alignment: .leading, spacing: 3) {
                // Title
                HStack {
                    Text(item.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Menu {
                        Button(action: onAddToList) {
                            Label("Add to another list", systemImage: "plus")
                        }
                        Button(role: .destructive, action: onRemoveFromList) {
                            Label("Remove from list", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white.opacity(0.35))
                            .font(.system(size: 14))
                            .padding(4)
                            .contentShape(Rectangle())
                    }
                }

                // Time slot
                if !item.timeSlot.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.35))
                        Text(item.timeSlot)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }

                // Location
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.35))
                    Text(item.location)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                // Poll Timer pill
                if let pollStatusText {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "22d3a5"))
                        Text(pollStatusText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "22d3a5"))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: "22d3a5").opacity(0.1)))
                    .overlay(Capsule().stroke(Color(hex: "22d3a5").opacity(0.25), lineWidth: 1))
                    .padding(.top, 2)
                    .onReceive(timer) { _ in
                        now = Date()
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var conflictBannerView: some View {
        if item.hasConflict, let msg = item.conflictMessage {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                Text(msg)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red.opacity(0.9))
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(8)
            .padding(.horizontal, 14)
            .padding(.top, 10)
        }
    }

    @ViewBuilder
    private var yesVotersRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: -7) {
                ForEach(Self.demoCollaborators) { collaborator in
                    voterAvatar(collaborator)
                }
            }

            if isAllIn {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 12))
                    Text("Everyone's in!")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "22d3a5"))
                }
            } else if item.yesVoters.isEmpty {
                Text("4 collaborators")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            } else {
                Text("✓ " + item.yesVoters.map { $0.fullName }.joined(separator: ", "))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            if isAllIn {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "22d3a5"))
                    Text("Confirmed")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "22d3a5"))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color(hex: "22d3a5").opacity(0.12))
                .cornerRadius(99)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var voteButtonsRow: some View {
        HStack(spacing: 10) {
            Text("by \(item.ownerFullName) · \(item.addedTimeAgo)")
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.35))

            Spacer()

            // Thumbs Up
            Button(action: onVoteUp) {
                HStack(spacing: 4) {
                    Image(systemName: item.userVote == "up" ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 12))
                    if item.thumbsUpCount > 0 {
                        Text("\(item.thumbsUpCount)")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .foregroundColor(item.userVote == "up" ? .white : .white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(item.userVote == "up"
                        ? Color.violet
                        : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule().stroke(
                        item.userVote == "up" ? Color.clear : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
                )
                .disabled(!canVote)
                .opacity(canVote ? 1 : 0.5)
            }

            // Thumbs Down — only show when there are votes or user voted down
            if item.thumbsDownCount > 0 || item.userVote == "down" {
                Button(action: onVoteDown) {
                    HStack(spacing: 4) {
                        Image(systemName: item.userVote == "down" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .font(.system(size: 12))
                        if item.thumbsDownCount > 0 {
                            Text("\(item.thumbsDownCount)")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .foregroundColor(item.userVote == "down" ? Color.red.opacity(0.9) : .white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(item.userVote == "down"
                            ? Color.red.opacity(0.1)
                            : Color.white.opacity(0.06))
                    )
                    .overlay(
                        Capsule().stroke(
                            item.userVote == "down" ? Color.red.opacity(0.4) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                    )
                    .disabled(!canVote)
                    .opacity(canVote ? 1 : 0.5)
                }
            } else {
                // Inactive thumbs-down (just the icon, no background)
                Button(action: onVoteDown) {
                    Image(systemName: "hand.thumbsdown")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .disabled(!canVote)
                .opacity(canVote ? 1 : 0.5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var actionsRow: some View {
        HStack {
            Button(action: onAddNote) {
                Text("Add a note")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                    .underline()
            }

            Spacer()

            if !isAllIn && item.userVote != "up" {
                Button(action: onAddAlternative) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Alternative")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.violet)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.violet.opacity(0.1))
                    .cornerRadius(20)
                    .overlay(
                        Capsule().stroke(Color.violet.opacity(0.4), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var noteDisplayView: some View {
        if let noteText = item.noteText, !noteText.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(String((item.noteAuthor ?? "K").prefix(1)))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.brown))

                    Text(item.noteAuthor ?? "Kashish")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    Button(action: onAddNote) {
                        Text("Edit")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                Text("\(noteText) · \(item.noteTimeAgo ?? "Just now")")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.leading, 24)
            }
            .padding(10)
            .background(Color(white: 0.08))
            .cornerRadius(10)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }

    // ─── Main Body ─────────────────────────────────────────────────────

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRowView
            conflictBannerView
            yesVotersRow

            // Divider
            Divider()
                .background(Color.white.opacity(0.07))
                .padding(.horizontal, 14)
                .padding(.top, 6)

            voteButtonsRow
            actionsRow
            noteDisplayView
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(white: 0.13), Color(white: 0.08)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
    }

    // ─── Helpers ───────────────────────────────────────────────────────

    @ViewBuilder
    private var thumbView: some View {
        ZStack {
            // Always-visible gradient background by category
            let gradient: LinearGradient = {
                switch item.category {
                case "Restaurant":
                    return LinearGradient(
                        colors: [Color(hex: "ff9f43"), Color(hex: "ee5a24")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                case "Event":
                    return LinearGradient(
                        colors: [Color(hex: "a855f7"), Color(hex: "3b82f6")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                default:
                    return LinearGradient(
                        colors: [Color(hex: "7c5cfc"), Color(hex: "6c63ff")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            }()
            Rectangle().fill(gradient)

            // Icon on gradient
            Image(systemName: sfSymbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            // Real image on top (transparent if missing)
            if !item.imageName.isEmpty {
                Image(item.imageName)
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    private var sfSymbol: String {
        switch item.category {
        case "Restaurant": return "fork.knife"
        case "Event":      return "music.mic"
        default:           return "sparkles"
        }
    }

    private func voterAvatar(_ voter: YesVoter) -> some View {
        let bgColor: Color = {
            switch voter.initial {
            case "K": return Color(hex: "ec4899")
            case "S": return Color(hex: "7c5cfc")
            case "A": return Color(hex: "22d3a5")
            case "R": return Color(hex: "fbbf24")
            default:  return .gray
            }
        }()
        return Text(voter.initial)
            .font(.system(size: 9, weight: .black))
            .foregroundColor(.white)
            .frame(width: 22, height: 22)
            .background(Circle().fill(bgColor))
            .overlay(Circle().stroke(Color(white: 0.13), lineWidth: 1.5))
    }
}
