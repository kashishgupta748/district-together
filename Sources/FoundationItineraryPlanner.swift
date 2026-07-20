import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif
struct FoundationItineraryRanking {
    enum Source {
        case foundationModel
        case deterministicFallback
    }

    let recommendationIDs: [String]
    let source: Source
}

@MainActor
enum FoundationItineraryPlanner {
    static func answerTripQuestion(
        _ question: String,
        tripName: String,
        items: [TripItem],
        conversation: [ChatMessage]
    ) async -> String {
        let itinerary = itineraryContext(tripName: tripName, items: items)

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            if model.availability == .available {
                do {
                    let session = LanguageModelSession(
                        model: model,
                        instructions: """
                        You are the in-app District trip assistant. Answer using the supplied
                        itinerary and app guide. Be concise, practical, and friendly. Never invent
                        a reservation, opening time, price, distance, booking, or venue. When the
                        itinerary does not contain an answer, say so and explain the exact in-app
                        action the person can take. Refer to plans by their real title and day.
                        """
                    )
                    let recentConversation = conversation
                        .suffix(6)
                        .map { "\($0.sender.uppercased()): \($0.text)" }
                        .joined(separator: "\n")
                    let response = try await session.respond(
                        to: """
                        APP GUIDE:
                        - Add items searches food, movies, games, events, activities, sports,
                          nightlife, wellness, shopping, and attractions, then adds one to a day.
                        - Every new item starts a group poll. The poll opens 30 minutes before the
                          activity, stays open for 15 minutes, then submits automatically.
                        - Interested and Not interested votes are visible to collaborators.
                        - Alternative proposes a competing plan for the same day and time slot.
                        - Complete itinerary shows and edits the full timed trip.
                        - Ask AI answers questions; Edit plan and Rewrite regenerate the itinerary.

                        CURRENT ITINERARY:
                        \(itinerary)

                        RECENT CONVERSATION:
                        \(recentConversation.isEmpty ? "None" : recentConversation)

                        USER QUESTION:
                        \(question)
                        """,
                        options: GenerationOptions(
                            sampling: .greedy,
                            maximumResponseTokens: 500
                        )
                    )
                    let answer = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !answer.isEmpty { return answer }
                } catch {
                    // The deterministic answer below keeps chat useful when the model is busy.
                }
            }
        }
#endif

        return fallbackTripAnswer(
            question,
            tripName: tripName,
            items: items
        )
    }

    static func interpretWrittenTrip(
        _ brief: String,
        fallback: TripPlanDraft
    ) async -> TripPlanDraft {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.availability == .available else { return fallback }

            do {
                return try await interpretWithFoundationModel(
                    model: model,
                    brief: brief,
                    fallback: fallback
                )
            } catch {
                return fallback
            }
        }
#endif

        return fallback
    }

    static func rank(
        draft: TripPlanDraft,
        candidates: [Recommendation]
    ) async -> FoundationItineraryRanking {
        guard !candidates.isEmpty else {
            return FoundationItineraryRanking(
                recommendationIDs: [],
                source: .deterministicFallback
            )
        }

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.availability == .available else {
                return fallback(candidates)
            }

            do {
                return try await rankWithFoundationModel(
                    model: model,
                    draft: draft,
                    candidates: candidates
                )
            } catch {
                return fallback(candidates)
            }
        }
#endif

        return fallback(candidates)
    }

    private static func fallback(
        _ candidates: [Recommendation]
    ) -> FoundationItineraryRanking {
        FoundationItineraryRanking(
            recommendationIDs: candidates
                .sorted { $0.rating > $1.rating }
                .map(\.id),
            source: .deterministicFallback
        )
    }

    private static func itineraryContext(
        tripName: String,
        items: [TripItem]
    ) -> String {
        guard !items.isEmpty else { return "\(tripName): no plans yet." }

        return items
            .sorted {
                if $0.day == $1.day { return $0.timeSlot < $1.timeSlot }
                return $0.day < $1.day
            }
            .map { item in
                let status = item.isConfirmed
                    ? "confirmed"
                    : "\(item.thumbsUpCount) interested, \(item.thumbsDownCount) not interested"
                return "Day \(item.day) | \(item.tripDate) | \(item.timeSlot) | \(item.title) | \(item.location) | \(status)"
            }
            .joined(separator: "\n")
    }

    private static func fallbackTripAnswer(
        _ question: String,
        tripName: String,
        items: [TripItem]
    ) -> String {
        let query = question.lowercased()
        let ordered = items.sorted {
            if $0.day == $1.day { return $0.timeSlot < $1.timeSlot }
            return $0.day < $1.day
        }

        if items.isEmpty,
           query.contains("start") || query.contains("plan") || query.contains("itinerary") {
            return "Start with Guided setup for seven short questions, or choose Write full trip if you already know the destination, dates, people, per-person budget, hotel, and fixed bookings. Ask AI stays available whenever you need help deciding."
        }

        if items.isEmpty, query.contains("theme") || query.contains("idea") {
            return "A useful starting theme is a mix of famous local places, one highly rated dining experience, an activity, and an easy evening plan. Guided setup can personalize that around your destination, dates, group, and budget."
        }

        if query.contains("poll") || query.contains("vote") || query.contains("interested") {
            return "Each plan’s poll opens 30 minutes before its start time and remains open for 15 minutes. Collaborators can choose Interested or Not interested; when the timer ends, the current result submits automatically."
        }

        if query.contains("alternative") || query.contains("replace") || query.contains("instead") {
            if let item = ordered.first(where: { $0.thumbsDownCount > 0 || $0.hasConflict }) {
                return "\(item.title) on Day \(item.day) is the best plan to review first. Tap Alternative on its card to propose another option for the same time slot and start a group vote."
            }
            return "There are no disputed plans right now. To compare another option, tap Alternative on any itinerary card; it will be proposed for the same day and time slot."
        }

        if query.contains("add") || query.contains("search") || query.contains("movie") || query.contains("food") {
            return "Tap Add items, choose the day, and search across dining, movies, events, games, activities, sports, nightlife, wellness, shopping, or attractions. Adding a result places it in the collaborative itinerary and starts its poll."
        }

        if query.contains("free") || query.contains("gap") || query.contains("spare") {
            let schedule = ordered.prefix(6).map {
                "Day \($0.day): \($0.title) at \($0.timeSlot)"
            }.joined(separator: "\n")
            return "These are the fixed plan windows I can see:\n\(schedule)\nUse the gaps between them for another plan; Add items can search for options that fit a specific day."
        }

        if query.contains("today") || query.contains("plan") || query.contains("itinerary") || query.contains("schedule") {
            guard let firstDay = ordered.first?.day else {
                return "There is no itinerary yet. Use Edit plan or Rewrite to create one."
            }
            let dayItems = ordered.filter { $0.day == firstDay }
            let summary = dayItems.map { "• \($0.timeSlot): \($0.title)" }.joined(separator: "\n")
            return "Day \(firstDay) of your \(tripName) trip:\n\(summary)"
        }

        if let matchingItem = ordered.first(where: {
            let words = $0.title.lowercased().split(separator: " ").filter { $0.count > 3 }
            return words.contains { query.contains($0) }
        }) {
            return "\(matchingItem.title) is on Day \(matchingItem.day), \(matchingItem.tripDate), from \(matchingItem.timeSlot) at \(matchingItem.location). It currently has \(matchingItem.thumbsUpCount) interested and \(matchingItem.thumbsDownCount) not interested."
        }

        return "I can help with your day-by-day itinerary, plan timings, venues, free gaps, group polls, alternatives, and how to add or edit plans. Ask about a specific day or activity and I’ll use the current \(tripName) itinerary."
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private struct FoundationTripBrief {
    let destination: String
    let arrivalDate: String
    let departureDate: String
    let dayCount: Int
    let travellers: String
    let budgetPerPerson: String
    let theme: String
    let interests: String
    let dining: String
    let plansPerDay: Int
    let accommodation: String
    let fixedBookings: String
    let arrivalPlan: String
    let departurePlan: String
}

@available(iOS 26.0, *)
private extension FoundationItineraryPlanner {
    static func interpretWithFoundationModel(
        model: SystemLanguageModel,
        brief: String,
        fallback: TripPlanDraft
    ) async throws -> TripPlanDraft {
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You interpret a person's complete trip request for a collaborative itinerary app.
            Extract only facts present in the request. Do not invent a hotel, booking, date,
            budget, destination, dietary restriction, or group member. Convert relative dates
            using the current date supplied in the prompt. Keep the person's preferences concise.
            This step structures the request; it does not recommend venues.
            """
        )

        let today = isoDateFormatter.string(from: Date())
        let response = try await session.respond(
            to: """
            Current date: \(today)

            Complete trip request:
            \(brief)

            Return exactly these lines and no other text:
            DESTINATION=<city, area, or empty>
            ARRIVAL_DATE=<yyyy-MM-dd or empty>
            DEPARTURE_DATE=<yyyy-MM-dd or empty>
            DAY_COUNT=<1 through 10, or 0 when absent>
            TRAVELLERS=<group summary or empty>
            BUDGET_PER_PERSON=<amount and currency or empty>
            THEME=<short trip style>
            INTERESTS=<comma-separated requested experiences>
            DINING=<food and dietary preferences or empty>
            PLANS_PER_DAY=<1 through 4; use 2 relaxed, 3 balanced, 4 packed>
            ACCOMMODATION=<booked hotel or area, Not booked yet, or empty>
            FIXED_BOOKINGS=<confirmed bookings with day and time, or Nothing yet>
            ARRIVAL_PLAN=<transport and time or empty>
            DEPARTURE_PLAN=<transport and time or empty>

            Extract only supplied facts. Do not recommend or invent venues.
            """,
            options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 900)
        )

        guard let interpretation = parseInterpretation(response.content) else {
            return fallback
        }
        return merge(interpretation, into: fallback)
    }

    static func parseInterpretation(_ content: String) -> FoundationTripBrief? {
        var fields: [String: String] = [:]

        for rawLine in content.split(whereSeparator: \.isNewline) {
            let line = rawLine
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "`-*• "))
            let separatorIndex = line.firstIndex(of: "=") ?? line.firstIndex(of: ":")
            guard let separatorIndex else { continue }

            let key = String(line[..<separatorIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            let valueStart = line.index(after: separatorIndex)
            let value = String(line[valueStart...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            fields[key] = value
        }

        guard !fields.isEmpty else { return nil }
        return FoundationTripBrief(
            destination: fields["DESTINATION", default: ""],
            arrivalDate: fields["ARRIVAL_DATE", default: ""],
            departureDate: fields["DEPARTURE_DATE", default: ""],
            dayCount: Int(fields["DAY_COUNT", default: "0"]) ?? 0,
            travellers: fields["TRAVELLERS", default: ""],
            budgetPerPerson: fields["BUDGET_PER_PERSON", default: ""],
            theme: fields["THEME", default: ""],
            interests: fields["INTERESTS", default: ""],
            dining: fields["DINING", default: ""],
            plansPerDay: Int(fields["PLANS_PER_DAY", default: "3"]) ?? 3,
            accommodation: fields["ACCOMMODATION", default: ""],
            fixedBookings: fields["FIXED_BOOKINGS", default: ""],
            arrivalPlan: fields["ARRIVAL_PLAN", default: ""],
            departurePlan: fields["DEPARTURE_PLAN", default: ""]
        )
    }

    static func merge(
        _ interpretation: FoundationTripBrief,
        into fallback: TripPlanDraft
    ) -> TripPlanDraft {
        var draft = fallback

        func meaningful(_ value: String) -> String? {
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty,
                  !cleaned.localizedCaseInsensitiveContains("not specified"),
                  !cleaned.localizedCaseInsensitiveContains("unknown")
            else { return nil }
            return cleaned
        }

        if let destination = meaningful(interpretation.destination) {
            draft.destination = destination
        }
        if let travellers = meaningful(interpretation.travellers) {
            draft.travellers = travellers
            draft.travellerMix = travellers
        }
        if let budget = meaningful(interpretation.budgetPerPerson) {
            draft.budget = budget.localizedCaseInsensitiveContains("person")
                ? budget
                : "\(budget) per person"
        }
        if let theme = meaningful(interpretation.theme) {
            draft.theme = theme
        }
        if let interests = meaningful(interpretation.interests) {
            draft.interests = interests
        }
        if let dining = meaningful(interpretation.dining) {
            draft.food = dining
        }
        if let accommodation = meaningful(interpretation.accommodation) {
            draft.accommodation = accommodation
        }
        if let bookings = meaningful(interpretation.fixedBookings) {
            draft.existingBooking = bookings
        }
        if let arrival = meaningful(interpretation.arrivalPlan) {
            draft.arrivalPlan = arrival
        }
        if let departure = meaningful(interpretation.departurePlan) {
            draft.departurePlan = departure
        }

        let planCount = min(4, max(1, interpretation.plansPerDay))
        draft.plansPerDay = planCount
        draft.pace = TripPlanDraft.paceLabel(for: planCount)

        let interpretedDayCount = min(10, max(1, interpretation.dayCount))
        let arrivalDate = date(from: interpretation.arrivalDate)
        let departureDate = date(from: interpretation.departureDate)

        if let arrivalDate, let departureDate, departureDate >= arrivalDate {
            draft.startDate = Calendar.current.startOfDay(for: arrivalDate)
            draft.endDate = Calendar.current.startOfDay(for: departureDate)
        } else if let arrivalDate {
            draft.startDate = Calendar.current.startOfDay(for: arrivalDate)
            draft.endDate = Calendar.current.date(
                byAdding: .day,
                value: interpretedDayCount - 1,
                to: draft.startDate
            ) ?? draft.startDate
        } else if interpretation.dayCount > 0 {
            draft.endDate = Calendar.current.date(
                byAdding: .day,
                value: interpretedDayCount - 1,
                to: draft.startDate
            ) ?? draft.startDate
        }

        draft.dates = TripDateFormatting.range(from: draft.startDate, to: draft.endDate)
        return draft
    }

    static var isoDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func date(from value: String) -> Date? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return isoDateFormatter.date(from: cleaned)
    }

    static func rankWithFoundationModel(
        model: SystemLanguageModel,
        draft: TripPlanDraft,
        candidates: [Recommendation]
    ) async throws -> FoundationItineraryRanking {
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You are the private on-device ranking engine for a collaborative trip planner.
            Rank only the District catalogue entries supplied by the app. Never invent an ID,
            venue, rating, price, schedule, or availability. Prefer highly rated nearby places
            that fit the group's stated interests, daily pace, meal needs, and fixed bookings.
            Balance food, activities, culture, entertainment, and rest across the whole trip.
            """
        )

        let candidateText = candidates.enumerated().map { index, candidate in
            """
            \(index + 1). id=\(candidate.id); title=\(candidate.title); category=\(candidate.category); \
            venue=\(candidate.venue); area=\(candidate.area); rating=\(candidate.rating); \
            distance=\(candidate.distance); availableTime=\(candidate.time); fit=\(candidate.scheduleFit)
            """
        }
        .joined(separator: "\n")

        let prompt = """
        Rank the supplied District places for this complete itinerary.

        Destination: \(draft.destination)
        Dates: \(draft.dates)
        Travellers: \(draft.travellers) — \(draft.travellerMix)
        Per-person budget: \(draft.budget)
        Trip idea: \(draft.theme)
        Interests: \(draft.interests)
        Dining: \(draft.food)
        Plans per day: \(draft.plansPerDay)
        Stay: \(draft.accommodation)
        Fixed plans: \(draft.existingBooking)
        Member preferences: \(draft.memberSummary)
        Written request: \(draft.organizerBrief.isEmpty ? "None" : draft.organizerBrief)

        District catalogue:
        \(candidateText)

        Return only the candidate IDs in best-first order, separated by commas.
        Include every valid candidate exactly once. Do not include prose, labels, bullets, or JSON.
        """

        session.prewarm()
        let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(
                sampling: .greedy,
                maximumResponseTokens: 600
            )
        )

        let validIDs = Set(candidates.map(\.id))
        var seen: Set<String> = []
        let responseTokens = response.content
            .lowercased()
            .split { character in
                !character.isLetter && !character.isNumber && character != "-"
            }
            .map(String.init)
        var orderedIDs = responseTokens.filter { id in
            validIDs.contains(id) && seen.insert(id).inserted
        }

        let missingIDs = candidates
            .filter { !seen.contains($0.id) }
            .sorted { $0.rating > $1.rating }
            .map(\.id)
        orderedIDs.append(contentsOf: missingIDs)

        guard !orderedIDs.isEmpty else {
            return fallback(candidates)
        }

        return FoundationItineraryRanking(
            recommendationIDs: orderedIDs,
            source: .foundationModel
        )
    }
}
#endif
