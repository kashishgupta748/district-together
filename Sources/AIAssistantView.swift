import CoreLocation
import MapKit
import SwiftUI

public struct AIAssistantView: View {
    @StateObject private var store: TripStore

    public init(
        tripName: String,
        tripItems: [TripItem] = [],
        onComplete: @escaping (String, [TripItem]) -> Void
    ) {
        _store = StateObject(
            wrappedValue: TripStore(
                hotlistName: tripName,
                existingTripItems: tripItems,
                onComplete: onComplete
            )
        )
    }

    public var body: some View {
        AITripPlannerView(store: store)
    }
}
struct AITripPlannerView: View {
    @ObservedObject var store: TripStore
    @StateObject private var locationProvider = CurrentLocationProvider()
    @Environment(\.dismiss) private var dismiss
    @State private var draft = TripPlanDraft()
    @State private var currentQuestionIndex = 0
    @State private var answers: [String] = []
    @State private var inputMode: TripPlannerEntryMode
    @State private var autoSelectCurrentLocation: Bool

    private let questions = PlannerQuestion.all

    private var availableInputModes: [TripPlannerEntryMode] {
        [.chat, .guided, .written]
    }

    init(store: TripStore) {
        self.store = store
        _draft = State(initialValue: store.currentDraft ?? store.initialDraftForHotlist())
        _inputMode = State(initialValue: store.plannerEntryMode)
        _autoSelectCurrentLocation = State(initialValue: store.plannerShouldUseCurrentLocation)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Trip input", selection: $inputMode) {
                    ForEach(availableInputModes) { mode in
                        Text(mode.pickerTitle(hasItinerary: store.hasGeneratedItinerary))
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DistrictTheme.horizontalPadding)
                .padding(.vertical, 12)
                .disabled(inputMode == .guided && currentQuestionIndex > 0)

                Divider()
                if inputMode == .chat {
                    TripInteractiveAIView(
                        tripName: store.hotlistName,
                        tripItems: store.existingTripItems
                    )
                } else if inputMode == .guided {
                    progressHeader
                    Divider()
                    conversation
                } else {
                    WholeTripBriefInput(
                        hotlistName: store.hotlistName,
                        isGenerating: store.isGeneratingItinerary
                    ) { brief in
                        Task {
                            await store.generateTripFromWrittenBrief(brief)
                            dismiss()
                        }
                    }
                }
            }
            .background(DistrictTheme.canvas)
            .navigationTitle(
                inputMode == .chat
                    ? "Trip assistant"
                    : (store.hasGeneratedItinerary ? "Update itinerary" : "Plan with AI")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .tint(.gray)
                }
            }
        }
        .tint(DistrictTheme.accent)
        .presentationDragIndicator(.visible)
        .task {
            if autoSelectCurrentLocation {
                store.consumeCurrentLocationPlannerRequest()
                locationProvider.requestCurrentPlace()
            }
        }
        .onChange(of: locationProvider.placeName) {
            guard
                autoSelectCurrentLocation,
                inputMode == .guided,
                currentQuestionIndex == 0,
                let place = locationProvider.placeName
            else { return }
            autoSelectCurrentLocation = false
            submit(place, for: questions[0])
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(currentQuestionIndex < questions.count ? "Building your trip" : "Ready to generate")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(min(currentQuestionIndex, questions.count))/\(questions.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(
                value: Double(min(currentQuestionIndex, questions.count)),
                total: Double(questions.count)
            )
            .tint(DistrictTheme.accent)
        }
        .padding(.horizontal, DistrictTheme.horizontalPadding)
        .padding(.vertical, 12)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    AIIntroductionBubble(hotlistName: store.hotlistName)

                    ForEach(Array(questions.prefix(currentQuestionIndex).enumerated()), id: \.offset) { index, question in
                        AIQuestionBubble(question: question)
                        UserAnswerBubble(answer: answers[index])
                    }

                    if currentQuestionIndex < questions.count {
                        let question = questions[currentQuestionIndex]
                        AIQuestionBubble(question: question)
                        Group {
                            if question.kind == .destination {
                                LocationAnswerOptions(provider: locationProvider) { answer in
                                    submit(answer, for: question)
                                }
                            } else if question.kind == .dates {
                                DateRangeAnswerOptions(
                                    initialStart: draft.startDate,
                                    initialEnd: draft.endDate
                                ) { answer, startDate, endDate in
                                    draft.dates = answer
                                    draft.startDate = startDate
                                    draft.endDate = endDate
                                    advance(with: answer)
                                }
                            } else if question.kind == .logistics {
                                TravelLogisticsAnswer { logistics in
                                    draft.arrivalPlan = logistics.arrival
                                    draft.departurePlan = logistics.departure
                                    draft.accommodation = logistics.accommodation
                                    advance(with: logistics.summary)
                                }
                            } else if question.kind == .travellers {
                                TravellerCountAnswer(initialCount: draft.travellerCount) { count, mix in
                                    let answer = "\(count) \(count == 1 ? "person" : "people")"
                                    draft.travellers = answer
                                    draft.travellerMix = mix
                                    advance(with: "\(answer) • \(mix)")
                                }
                            } else if question.kind == .budget {
                                BudgetAnswerOptions { answer, rules in
                                    draft.budget = answer
                                    draft.budgetRules = rules
                                    advance(with: "\(answer) • \(rules)")
                                }
                            } else if question.kind == .members {
                                MemberPreferencesAnswer(
                                    count: draft.travellerCount
                                ) { preferences in
                                    draft.memberPreferences = preferences
                                    advance(with: preferences.map { "\($0.name): \($0.preference)" }.joined(separator: ", "))
                                }
                            } else if question.kind == .pace {
                                PlansPerDayAnswer(initialCount: draft.plansPerDay) { count in
                                    draft.plansPerDay = count
                                    draft.pace = TripPlanDraft.paceLabel(for: count)
                                    advance(with: draft.pace)
                                }
                            } else if question.kind == .booking {
                                ExistingBookingAnswer { result in
                                    draft.accommodation = result.accommodation
                                    draft.existingBooking = result.bookings
                                    advance(with: result.summary)
                                }
                            } else if question.kind == .food {
                                DiningPreferencesAnswer { preference in
                                    draft.food = preference
                                    advance(with: preference)
                                }
                            } else {
                                AnswerOptions(question: question) { answer in
                                    submit(answer, for: question)
                                }
                            }
                        }
                        .id("current-question")
                    } else {
                        PlannerReview(
                            draft: draft,
                            intelligenceStatus: store.appleIntelligenceStatus,
                            isGenerating: store.isGeneratingItinerary
                        ) {
                            Task {
                                await store.generateTripWithAppleIntelligence(draft)
                                dismiss()
                            }
                        }
                        .id("review")
                    }
                }
                .padding(DistrictTheme.horizontalPadding)
                .padding(.vertical, 18)
            }
            .onChange(of: currentQuestionIndex) {
                withAnimation(.easeOut) {
                    proxy.scrollTo(
                        currentQuestionIndex < questions.count ? "current-question" : "review",
                        anchor: .bottom
                    )
                }
            }
        }
    }

    private func submit(_ answer: String, for question: PlannerQuestion) {
        updateDraft(answer, for: question.kind)
        advance(with: answer)
    }

    private func advance(with answer: String) {
        answers.append(answer)
        withAnimation(.snappy) {
            currentQuestionIndex += 1
        }
    }

    private func updateDraft(_ answer: String, for kind: PlannerQuestion.Kind) {
        switch kind {
        case .destination: draft.destination = answer
        case .dates: break
        case .logistics: break
        case .travellers: draft.travellers = answer
        case .budget: draft.budget = answer
        case .theme:
            let existingInterests = draft.interests
            draft.theme = answer
            draft.interests = store.hotlistName.isEmpty
                ? answer
                : "\(existingInterests) • \(answer)"
        case .interests: draft.interests = answer
        case .members: break
        case .pace:
            draft.pace = answer
            draft.plansPerDay = TripPlanDraft.planCount(from: answer)
        case .rhythm: draft.dailyRhythm = answer
        case .transport: draft.transportPreference = answer
        case .split: draft.splitPreference = answer
        case .accessibility: draft.accessibility = answer
        case .booking: break
        case .food: draft.food = answer
        }
    }
}

private struct WholeTripBriefInput: View {
    @State private var brief = ""
    let hotlistName: String
    let isGenerating: Bool
    let action: (String) -> Void

    private var trimmedBrief: String {
        brief.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool {
        trimmedBrief.count >= 20 && !isGenerating
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(hotlistName.isEmpty ? "Describe your trip" : "Plan \(hotlistName)")
                        .font(.title2.bold())
                    Text(
                        hotlistName.isEmpty
                            ? "Write naturally. Add the destination, dates and budget if you know them—District will work out the rest."
                            : "Write naturally. Your \(hotlistName) Hotlist already guides the recommendations; add destination, dates and budget."
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TextEditor(text: $brief)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 270)
                    .background(DistrictTheme.card, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(DistrictTheme.border))
                    .overlay(alignment: .topLeading) {
                        if brief.isEmpty {
                            Text("Example: Four days in Goa for five people, ₹18,000 each. Beaches, local food, a movie and nightlife. Concert on Day 3 at 8 PM.")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .padding(17)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding(DistrictTheme.horizontalPadding)
            .padding(.vertical, 22)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                action(trimmedBrief)
            } label: {
                HStack(spacing: 12) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.headline)
                    }
                    Text(isGenerating ? "Creating your itinerary…" : "Create my itinerary")
                        .font(.headline)
                    Spacer()
                    if !isGenerating {
                        Image(systemName: "arrow.right")
                            .font(.headline)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(DistrictTheme.accent, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: DistrictTheme.accent.opacity(canCreate ? 0.30 : 0), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(!canCreate)
            .opacity(canCreate || isGenerating ? 1 : 0.42)
            .padding(.horizontal, DistrictTheme.horizontalPadding)
            .padding(.vertical, 14)
        }
    }
}

private struct PlannerQuestion {
    enum Kind: Equatable {
        case destination
        case dates
        case logistics
        case travellers
        case budget
        case theme
        case interests
        case members
        case pace
        case rhythm
        case transport
        case split
        case accessibility
        case booking
        case food
    }

    let kind: Kind
    let title: String
    let detail: String
    let options: [String]

    static let all = [
        PlannerQuestion(
            kind: .destination,
            title: "Where should I build the trip?",
            detail: "Use Apple Location or enter the destination. I’ll find highly rated places nearby.",
            options: []
        ),
        PlannerQuestion(
            kind: .dates,
            title: "What are the exact trip dates?",
            detail: "Choose arrival and departure dates. I’ll build every day separately.",
            options: []
        ),
        PlannerQuestion(
            kind: .travellers,
            title: "How many people are travelling?",
            detail: "Increase or decrease the exact group size for tables, tickets and transport.",
            options: []
        ),
        PlannerQuestion(
            kind: .budget,
            title: "What budget should I plan around?",
            detail: "Enter the trip budget for one person. I’ll calculate the group total automatically.",
            options: []
        ),
        PlannerQuestion(
            kind: .theme,
            title: "What kind of trip do you want?",
            detail: "Choose one overall direction. I’ll balance the detailed recommendations automatically.",
            options: [
                "Food, culture & landmarks",
                "Beach, cafés & nightlife",
                "Adventure & nature",
                "Shopping, movies & entertainment",
                "Wellness & relaxed experiences",
                "A mix of everything"
            ]
        ),
        PlannerQuestion(
            kind: .pace,
            title: "How many plans should I add each day?",
            detail: "Choose the exact daily count. I’ll still leave realistic time for travel, meals and rest.",
            options: []
        ),
        PlannerQuestion(
            kind: .booking,
            title: "Is your hotel booked, and do you have fixed plans?",
            detail: "Add the hotel or stay location if it is booked, plus any confirmed flights, tickets or reservations. I’ll plan around them.",
            options: []
        )
    ]
}

private struct DateRangeAnswerOptions: View {
    @State private var startDate: Date
    @State private var endDate: Date
    let action: (String, Date, Date) -> Void

    private let calendar = Calendar.current

    init(
        initialStart: Date,
        initialEnd: Date,
        action: @escaping (String, Date, Date) -> Void
    ) {
        _startDate = State(initialValue: initialStart)
        _endDate = State(initialValue: initialEnd)
        self.action = action
    }

    private var dayCount: Int {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return max(1, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
    }

    private var dateAnswer: String {
        TripDateFormatting.range(from: startDate, to: endDate)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                TripDatePickerRow(
                    title: "Arrival",
                    selection: $startDate,
                    minimumDate: calendar.startOfDay(for: Date())
                )
                Divider().padding(.leading, 14)
                TripDatePickerRow(
                    title: "Departure",
                    selection: $endDate,
                    minimumDate: startDate
                )
            }
            .districtCard(radius: 17)

            HStack {
                Label("\(dayCount)-day itinerary", systemImage: "calendar.badge.clock")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Continue") {
                    action(dateAnswer, startDate, endDate)
                }
                .fontWeight(.semibold)
                .buttonStyle(.borderedProminent)
                .tint(DistrictTheme.accent)
                .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .onChange(of: startDate) {
            if endDate < startDate { endDate = startDate }
            if dayCount > 10 {
                endDate = calendar.date(byAdding: .day, value: 9, to: startDate) ?? startDate
            }
        }
        .onChange(of: endDate) {
            if dayCount > 10 {
                endDate = calendar.date(byAdding: .day, value: 9, to: startDate) ?? startDate
            }
        }
    }
}

private struct TripDatePickerRow: View {
    let title: String
    @Binding var selection: Date
    let minimumDate: Date
    @State private var isPresentingCalendar = false

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)
                .frame(width: 86, alignment: .leading)
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            Button {
                isPresentingCalendar = true
            } label: {
                HStack(spacing: 7) {
                    Text(TripDateFormatting.fullDate(selection))
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(DistrictTheme.raised, in: Capsule())
                .overlay(Capsule().stroke(DistrictTheme.border))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 62)
        .sheet(isPresented: $isPresentingCalendar) {
            NavigationStack {
                DatePicker(
                    title,
                    selection: $selection,
                    in: minimumDate...,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { isPresentingCalendar = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .tint(DistrictTheme.accent)
            .preferredColorScheme(.dark)
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct MemberPreferencesAnswer: View {
    private static let preferenceOptions = [
        "Culture & local food",
        "Adventure & nature",
        "Nightlife & music",
        "Wellness & relaxed",
        "Creative & cafés",
        "Movies & entertainment",
        "Flexible"
    ]

    @State private var members: [TravellerPreference]
    let action: ([TravellerPreference]) -> Void

    init(count: Int, action: @escaping ([TravellerPreference]) -> Void) {
        _members = State(
            initialValue: (0..<max(1, min(count, 12))).map { index in
                TravellerPreference(
                    name: index == 0 ? "You" : "Member \(index + 1)",
                    preference: Self.preferenceOptions[index % Self.preferenceOptions.count]
                )
            }
        )
        self.action = action
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach($members) { $member in
                VStack(alignment: .leading, spacing: 9) {
                    TextField("Name", text: $member.name)
                        .font(.subheadline.weight(.semibold))
                    Picker("Main preference", selection: $member.preference) {
                        ForEach(Self.preferenceOptions, id: \.self) { preference in
                            Text(preference).tag(preference)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                }
                .padding(14)
                .districtCard(radius: 16)
            }

            Button {
                action(members)
            } label: {
                Label("Use these member preferences", systemImage: "person.3.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DistrictTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(members.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        }
        .padding(.horizontal, 20)
    }
}

private struct TravelLogistics {
    let arrival: String
    let departure: String
    let accommodation: String

    var summary: String { "\(arrival) • \(departure) • Stay: \(accommodation)" }
}

private struct TravelLogisticsAnswer: View {
    @StateObject private var completer = LocationSearchCompleter()
    @State private var arrivalTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var departureTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var arrivalType = "Airport"
    @State private var departureType = "Airport"
    @State private var accommodation = ""
    @State private var stayNotBooked = false
    let action: (TravelLogistics) -> Void

    private let locationTypes = ["Airport", "Railway station", "Bus terminal", "Hotel", "Other location"]

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                logisticsRow(title: "Arrive", selection: $arrivalTime, place: $arrivalType)
                Divider().padding(.leading, 14)
                logisticsRow(title: "Leave", selection: $departureTime, place: $departureType)
            }
            .districtCard(radius: 17)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "bed.double.fill").foregroundStyle(.secondary)
                    TextField("Hotel or accommodation area", text: $accommodation)
                        .disabled(stayNotBooked)
                    Button {
                        stayNotBooked.toggle()
                        if stayNotBooked { accommodation = "Not booked yet" }
                        else { accommodation = "" }
                    } label: {
                        Image(systemName: stayNotBooked ? "checkmark.circle.fill" : "circle")
                    }
                    .foregroundStyle(stayNotBooked ? DistrictTheme.mint : .secondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 50)

                if !stayNotBooked && !completer.suggestions.isEmpty {
                    Divider().padding(.leading, 44)
                    ForEach(completer.suggestions.prefix(3)) { suggestion in
                        Button {
                            accommodation = suggestion.fullName
                        } label: {
                            HStack {
                                Image(systemName: "mappin").foregroundStyle(.secondary)
                                Text(suggestion.fullName).font(.caption).lineLimit(2)
                                Spacer()
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(DistrictTheme.card, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(DistrictTheme.border))
            .onChange(of: accommodation) {
                if !stayNotBooked { completer.update(query: accommodation) }
            }

            Button {
                let arrival = "Arrive \(arrivalType.lowercased()) at \(arrivalTime.formatted(date: .omitted, time: .shortened))"
                let departure = "Leave \(departureType.lowercased()) at \(departureTime.formatted(date: .omitted, time: .shortened))"
                action(TravelLogistics(arrival: arrival, departure: departure, accommodation: accommodation))
            } label: {
                Label("Use these logistics", systemImage: "airplane.arrival")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DistrictTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(accommodation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 20)
    }

    private func logisticsRow(
        title: String,
        selection: Binding<Date>,
        place: Binding<String>
    ) -> some View {
        VStack(spacing: 9) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            Picker("Location", selection: place) {
                ForEach(locationTypes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }
}

private struct TravellerCountAnswer: View {
    @State private var adults: Int
    @State private var children = 0
    @State private var seniors = 0
    let action: (Int, String) -> Void

    init(initialCount: Int, action: @escaping (Int, String) -> Void) {
        _adults = State(initialValue: max(1, min(initialCount, 12)))
        self.action = action
    }

    private var total: Int { adults + children + seniors }

    private var mix: String {
        var parts = ["\(adults) adult\(adults == 1 ? "" : "s")"]
        if children > 0 { parts.append("\(children) child\(children == 1 ? "" : "ren")") }
        if seniors > 0 { parts.append("\(seniors) senior\(seniors == 1 ? "" : "s")") }
        return parts.joined(separator: " • ")
    }

    var body: some View {
        VStack(spacing: 10) {
            CounterRow(title: "Adults", count: $adults, minimum: 1, canIncrease: total < 12)
            CounterRow(title: "Children", count: $children, minimum: 0, canIncrease: total < 12)
            CounterRow(title: "Senior citizens", count: $seniors, minimum: 0, canIncrease: total < 12)

            Button {
                action(total, mix)
            } label: {
                Text("Continue with \(total)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DistrictTheme.accent, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(16)
        .districtCard(radius: 18)
        .padding(.horizontal, 20)
    }
}

private struct CounterRow: View {
    let title: String
    @Binding var count: Int
    let minimum: Int
    let canIncrease: Bool

    var body: some View {
        HStack {
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            counterButton(symbol: "minus", disabled: count == minimum) {
                count = max(minimum, count - 1)
            }
            Text("\(count)")
                .font(.title3.bold().monospacedDigit())
                .contentTransition(.numericText())
                .frame(width: 34)
            counterButton(symbol: "plus", disabled: !canIncrease) {
                count += 1
            }
        }
        .padding(.vertical, 4)
    }

    private func counterButton(
        symbol: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            Image(systemName: symbol)
                .font(.caption.bold())
                .frame(width: 38, height: 38)
                .background(DistrictTheme.raised, in: Circle())
                .overlay(Circle().stroke(DistrictTheme.border))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }
}

private struct PlansPerDayAnswer: View {
    @State private var count: Int
    let action: (Int) -> Void

    init(initialCount: Int, action: @escaping (Int) -> Void) {
        _count = State(initialValue: min(4, max(1, initialCount)))
        self.action = action
    }

    private var guidance: String {
        switch count {
        case 1: "A light day with plenty of free time"
        case 2: "A relaxed day with comfortable breaks"
        case 3: "A balanced day with the main highlights"
        default: "A full day with shorter gaps between plans"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CounterRow(
                title: "Plans per day",
                count: $count,
                minimum: 1,
                canIncrease: count < 4
            )

            Text(guidance)
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            Button {
                action(count)
            } label: {
                Text("Continue with \(count) \(count == 1 ? "plan" : "plans") per day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DistrictTheme.accent, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .districtCard(radius: 18)
        .padding(.horizontal, 20)
    }
}

private struct BudgetAnswerOptions: View {
    @State private var amount = ""
    let action: (String, String) -> Void

    private var numericAmount: Int {
        Int(amount.filter(\.isNumber)) ?? 0
    }

    private var answer: String {
        let formatted = numericAmount.formatted(.number.grouping(.automatic))
        return "₹\(formatted) per person"
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Text("₹")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Enter budget", text: $amount)
                        .font(.title3.weight(.semibold))
                        .keyboardType(.numberPad)
                        .onChange(of: amount) {
                            amount = String(amount.filter(\.isNumber).prefix(9))
                        }
                    Text("per person for the complete trip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 15)
            .frame(height: 66)
            .background(DistrictTheme.raised, in: RoundedRectangle(cornerRadius: 15))

            Button {
                action(
                    answer,
                    "AI balances food, activities and local transport with a small reserve"
                )
            } label: {
                HStack {
                    Text(numericAmount > 0 ? "Continue with \(answer)" : "Continue")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(DistrictTheme.accent, in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
            .disabled(numericAmount < 1_000)
            .opacity(numericAmount < 1_000 ? 0.45 : 1)
        }
        .padding(16)
        .districtCard(radius: 18)
        .padding(.horizontal, 20)
    }
}

private struct MenuSettingRow: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 10)
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { selection = option }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(selection).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.bold())
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 54)
    }
}

private struct ExistingBookingResult {
    let accommodation: String
    let bookings: String

    var summary: String {
        let fixedPlanSummary = bookings == "Nothing yet"
            ? "No other fixed plans"
            : bookings
        return "Stay: \(accommodation) • \(fixedPlanSummary)"
    }
}

private struct ExistingBookingAnswer: View {
    private enum HotelStatus {
        case booked
        case notBooked
    }

    @StateObject private var completer = LocationSearchCompleter()
    @State private var hotelStatus: HotelStatus? = .notBooked
    @State private var hotelLocation = ""
    @State private var bookingTitle = ""
    @State private var bookingDate = Date()
    @State private var bookingTime = Date()
    @State private var isAddingBooking = false
    @State private var bookings: [String] = []
    let action: (ExistingBookingResult) -> Void

    private var trimmedHotelLocation: String {
        hotelLocation.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBookingTitle: String {
        bookingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var finalBookings: [String] {
        bookings
    }

    private var canContinue: Bool {
        guard let hotelStatus else { return false }
        return hotelStatus == .notBooked || !trimmedHotelLocation.isEmpty
    }

    private var accommodationSummary: String {
        switch hotelStatus {
        case .booked:
            return "Booked • \(trimmedHotelLocation)"
        case .notBooked:
            return "Not booked yet"
        case nil:
            return "Stay not selected"
        }
    }

    private var bookingsSummary: String {
        finalBookings.isEmpty
            ? "Nothing yet"
            : finalBookings.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Your stay", systemImage: "bed.double.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DistrictTheme.accent)
                    Text("Is the hotel or accommodation already booked?")
                        .font(.headline)
                    Text("A booked location helps District choose nearby places and reduce unnecessary travel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    hotelStatusButton(
                        .booked,
                        title: "Yes, booked",
                        symbol: "checkmark.circle.fill"
                    )
                    hotelStatusButton(
                        .notBooked,
                        title: "Not booked",
                        symbol: "calendar.badge.plus"
                    )
                }
            }
            .padding(15)
            .districtCard(radius: 17)

            if hotelStatus == .booked {
                VStack(spacing: 0) {
                    HStack(spacing: 11) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(DistrictTheme.accent)
                        TextField(
                            "Hotel name, address or area",
                            text: $hotelLocation
                        )
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)

                        if !hotelLocation.isEmpty {
                            Button("Clear", systemImage: "xmark.circle.fill") {
                                hotelLocation = ""
                            }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)

                    if !completer.suggestions.isEmpty {
                        Divider().padding(.leading, 45)

                        ForEach(completer.suggestions.prefix(4)) { suggestion in
                            Button {
                                hotelLocation = suggestion.fullName
                            } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: "bed.double")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(.subheadline.weight(.semibold))
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.tertiary)
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 50)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .districtCard(radius: 17)

                Label(
                    "The itinerary will begin and end around this stay.",
                    systemImage: "location.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if hotelStatus == .notBooked {
                Label(
                    "No problem. District will keep the itinerary flexible until a stay is added.",
                    systemImage: "info.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
            }

            VStack(alignment: .leading, spacing: 13) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Anything already booked?", systemImage: "ticket.fill")
                        .font(.headline)
                    Text("Add only confirmed plans such as flights, tickets or reservations. District will keep these times free in your itinerary.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if bookings.isEmpty && !isAddingBooking {
                    Button {
                        action(
                            ExistingBookingResult(
                                accommodation: accommodationSummary,
                                bookings: "Nothing yet"
                            )
                        )
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle")
                            Text("Nothing else booked")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(DistrictTheme.raised, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canContinue)

                    Button {
                        withAnimation(.snappy) {
                            isAddingBooking = true
                        }
                    } label: {
                        Label("Add a confirmed booking", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(DistrictTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                if !bookings.isEmpty {
                    Text("Saved bookings")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    VStack(spacing: 0) {
                        ForEach(Array(bookings.enumerated()), id: \.offset) { index, savedBooking in
                            HStack(alignment: .top, spacing: 11) {
                                Image(systemName: bookingSymbol(for: savedBooking))
                                    .foregroundStyle(DistrictTheme.accent)
                                    .frame(width: 22, height: 22)

                                Text(savedBooking)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    bookings.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.tertiary)
                                }
                                .accessibilityLabel("Remove \(savedBooking)")
                            }
                            .padding(13)

                            if index < bookings.count - 1 {
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                    .background(DistrictTheme.raised, in: RoundedRectangle(cornerRadius: 14))

                    if !isAddingBooking {
                        Button {
                            withAnimation(.snappy) {
                                isAddingBooking = true
                            }
                        } label: {
                            Label("Add another booking", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(DistrictTheme.accent)
                    }
                }

                if isAddingBooking {
                    VStack(spacing: 0) {
                        TextField("What is booked? e.g. Flight to Jaipur", text: $bookingTitle)
                            .textInputAutocapitalization(.sentences)
                            .padding(.horizontal, 14)
                            .frame(height: 50)

                        Divider().padding(.leading, 14)

                        DatePicker(
                            "Date",
                            selection: $bookingDate,
                            displayedComponents: .date
                        )
                        .padding(.horizontal, 14)
                        .frame(height: 50)

                        Divider().padding(.leading, 14)

                        DatePicker(
                            "Time",
                            selection: $bookingTime,
                            displayedComponents: .hourAndMinute
                        )
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                    }
                    .background(DistrictTheme.raised, in: RoundedRectangle(cornerRadius: 14))

                    Button {
                        addCurrentBooking()
                    } label: {
                        Label("Save booking", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(DistrictTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmedBookingTitle.isEmpty)
                    .opacity(trimmedBookingTitle.isEmpty ? 0.45 : 1)

                    Button("Cancel") {
                        withAnimation(.snappy) {
                            bookingTitle = ""
                            isAddingBooking = false
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(15)
            .districtCard(radius: 17)

            if !bookings.isEmpty {
                VStack(spacing: 0) {
                    Button {
                        action(
                            ExistingBookingResult(
                                accommodation: accommodationSummary,
                                bookings: bookingsSummary
                            )
                        )
                    } label: {
                        HStack {
                            Text("Continue with \(bookings.count) \(bookings.count == 1 ? "booking" : "bookings")")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DistrictTheme.accent, in: RoundedRectangle(cornerRadius: 15))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.42)
                }
            }
        }
        .padding(.horizontal, 20)
        .onChange(of: hotelLocation) {
            if hotelStatus == .booked {
                completer.update(query: hotelLocation)
            }
        }
    }

    private func hotelStatusButton(
        _ status: HotelStatus,
        title: String,
        symbol: String
    ) -> some View {
        let isSelected = hotelStatus == status

        return Button {
            withAnimation(.snappy) {
                hotelStatus = status
                if status == .notBooked {
                    hotelLocation = ""
                }
            }
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    isSelected ? DistrictTheme.accent : DistrictTheme.raised,
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSelected ? DistrictTheme.accent : DistrictTheme.border
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private func addCurrentBooking() {
        guard !trimmedBookingTitle.isEmpty else { return }
        let dateText = bookingDate.formatted(
            .dateTime.day().month(.abbreviated)
        )
        let timeText = bookingTime.formatted(
            .dateTime.hour().minute()
        )
        withAnimation(.snappy) {
            bookings.append("\(trimmedBookingTitle) • \(dateText) at \(timeText)")
            bookingTitle = ""
            isAddingBooking = false
        }
    }

    private func bookingSymbol(for value: String) -> String {
        let lowercaseValue = value.lowercased()
        if lowercaseValue.contains("flight") || lowercaseValue.contains("airport") {
            return "airplane"
        }
        if lowercaseValue.contains("hotel") || lowercaseValue.contains("stay") {
            return "bed.double.fill"
        }
        if lowercaseValue.contains("restaurant") || lowercaseValue.contains("dinner") {
            return "fork.knife"
        }
        if lowercaseValue.contains("cab") || lowercaseValue.contains("train") || lowercaseValue.contains("bus") {
            return "car.fill"
        }
        return "ticket.fill"
    }
}

private struct DiningPreferencesAnswer: View {
    @State private var diet = "No preference"
    @State private var selectedStyles: Set<String> = ["Local food", "Cafés"]
    @State private var selectedAllergies: Set<String> = []
    @State private var mealPlanning = "Dinners & special meals"
    @State private var mealBudget = "800"
    let action: (String) -> Void

    private let diets = ["No preference", "Vegetarian", "Vegan", "Jain", "Non-vegetarian", "Halal", "Seafood"]
    private let diningStyles = ["Local food", "Street food", "Cafés", "Fine dining", "Rooftop", "Live music", "Healthy food", "Hidden places"]
    private let allergies = ["Nuts", "Dairy", "Gluten", "Seafood", "Eggs"]
    private let planningOptions = [
        "Every meal",
        "Dinners & special meals",
        "Special restaurants only",
        "Mostly flexible"
    ]

    private var numericBudget: Int {
        Int(mealBudget.filter(\.isNumber)) ?? 0
    }

    private var summary: String {
        let styles = selectedStyles.sorted().joined(separator: ", ")
        let allergyText = selectedAllergies.isEmpty
            ? "No allergies"
            : "Avoid \(selectedAllergies.sorted().joined(separator: ", "))"
        return "\(diet) • \(styles) • \(allergyText) • \(mealPlanning) • ₹\(numericBudget.formatted(.number.grouping(.automatic)))/person per meal"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            preferenceSection(title: "Diet") {
                FlowLayout(spacing: 8) {
                    ForEach(diets, id: \.self) { option in
                        DiningChoiceChip(title: option, isSelected: diet == option) {
                            diet = option
                        }
                    }
                }
            }

            preferenceSection(title: "Dining experiences") {
                FlowLayout(spacing: 8) {
                    ForEach(diningStyles, id: \.self) { option in
                        DiningChoiceChip(title: option, isSelected: selectedStyles.contains(option)) {
                            withAnimation(.snappy) {
                                if selectedStyles.contains(option) { selectedStyles.remove(option) }
                                else { selectedStyles.insert(option) }
                            }
                        }
                    }
                }
            }

            preferenceSection(title: "Allergies") {
                FlowLayout(spacing: 8) {
                    ForEach(allergies, id: \.self) { option in
                        DiningChoiceChip(title: option, isSelected: selectedAllergies.contains(option)) {
                            withAnimation(.snappy) {
                                if selectedAllergies.contains(option) { selectedAllergies.remove(option) }
                                else { selectedAllergies.insert(option) }
                            }
                        }
                    }
                }
            }

            VStack(spacing: 0) {
                MenuSettingRow(
                    title: "Meal planning",
                    selection: $mealPlanning,
                    options: planningOptions
                )
                Divider().padding(.leading, 15)
                HStack {
                    Text("Per-person meal budget")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("₹").foregroundStyle(.secondary)
                    TextField("800", text: $mealBudget)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .onChange(of: mealBudget) {
                            mealBudget = String(mealBudget.filter(\.isNumber).prefix(6))
                        }
                }
                .padding(.horizontal, 15)
                .frame(minHeight: 54)
            }
            .districtCard(radius: 17)

            Button {
                action(summary)
            } label: {
                Text("Save dining preferences")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DistrictTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selectedStyles.isEmpty || numericBudget < 100)
        }
        .padding(16)
        .districtCard(radius: 20)
        .padding(.horizontal, 20)
    }

    private func preferenceSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
    }

}

private struct DiningChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected { Image(systemName: "checkmark").font(.caption2.bold()) }
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? DistrictTheme.ink : .primary)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(isSelected ? Color.white : DistrictTheme.raised, in: Capsule())
            .overlay(Capsule().stroke(DistrictTheme.border))
        }
        .buttonStyle(.plain)
    }
}

private struct LocationAnswerOptions: View {
    @ObservedObject var provider: CurrentLocationProvider
    @StateObject private var completer = LocationSearchCompleter()
    @State private var manualPlace = ""

    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let place = provider.placeName {
                locationButton(
                    title: "Current location",
                    detail: place,
                    symbol: "location.fill",
                    isLoading: false
                ) {
                    action(place)
                }
            } else {
                locationButton(
                    title: provider.isLocating ? "Finding your location…" : "Use my current location",
                    detail: nil,
                    symbol: "location.fill",
                    isLoading: provider.isLocating
                ) {
                    provider.requestCurrentPlace()
                }
                .disabled(provider.isLocating)
            }

            Text("Search destination")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search any city, area or landmark", text: $manualPlace)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.go)
                        .onSubmit {
                            let place = manualPlace.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !place.isEmpty { action(place) }
                        }
                    if !manualPlace.isEmpty {
                        Button("Clear", systemImage: "xmark.circle.fill") {
                            manualPlace = ""
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 52)

                let trimmedPlace = manualPlace.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedPlace.count >= 2, completer.isSearching, completer.suggestions.isEmpty {
                    Divider().padding(.leading, 44)
                    HStack(spacing: 11) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(DistrictTheme.accent)
                            .frame(width: 22)
                        Text("Searching Apple Maps…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                }

                if !completer.suggestions.isEmpty {
                    Divider().padding(.leading, 44)
                    ForEach(completer.suggestions) { suggestion in
                        Button {
                            manualPlace = suggestion.fullName
                            action(suggestion.fullName)
                        } label: {
                            HStack(spacing: 11) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(DistrictTheme.accent)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.subheadline.weight(.semibold))
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.tertiary)
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 52)
                        }
                        .buttonStyle(.plain)
                    }
                } else if trimmedPlace.count >= 3, !completer.isSearching {
                    Divider().padding(.leading, 44)
                    Button {
                        action(trimmedPlace)
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .foregroundStyle(DistrictTheme.accent)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use “\(trimmedPlace)”")
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("No Apple Maps match — use the entered destination")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(DistrictTheme.card, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(DistrictTheme.border))
            .onChange(of: manualPlace) {
                completer.update(query: manualPlace)
            }

            if let error = provider.errorMessage {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }

    private func locationButton(
        title: String,
        detail: String?,
        symbol: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.blue, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold))
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if isLoading { ProgressView().controlSize(.small) }
                else { Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary) }
            }
            .foregroundStyle(.white)
            .padding(12)
            .districtCard(radius: 18)
        }
        .buttonStyle(.plain)
    }
}

private struct AIIntroductionBubble: View {
    let hotlistName: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(
                hotlistName.isEmpty
                    ? "Seven quick answers are enough. I’ll decide the detailed dining, travel order and daily timing automatically, and you can edit the result afterward."
                    : "I’ll use your \(hotlistName) Hotlist to shape every recommendation. Seven quick answers will set the location, timing and budget."
            )
                .font(.subheadline)
                .padding(.leading, 36)
                .padding(.trailing, 14)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DistrictTheme.card, in: RoundedRectangle(cornerRadius: 17))
                .padding(.horizontal, 20)

            AIBadge()
        }
    }
}

private struct AIQuestionBubble: View {
    let question: PlannerQuestion

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 5) {
                Text(question.title).font(.subheadline.bold())
                Text(question.detail).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.leading, 36)
            .padding(.trailing, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DistrictTheme.card, in: RoundedRectangle(cornerRadius: 17))
            .padding(.horizontal, 20)

            AIBadge()
        }
    }
}

private struct AIBadge: View {
    var body: some View {
        Image(systemName: "sparkles")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(DistrictTheme.accent, in: Circle())
            .shadow(color: DistrictTheme.accent.opacity(0.28), radius: 8, y: 3)
            .accessibilityHidden(true)
    }
}

private struct UserAnswerBubble: View {
    let answer: String

    var body: some View {
        HStack {
            Spacer(minLength: 60)
            Text(answer)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(DistrictTheme.accent, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct AnswerOptions: View {
    let question: PlannerQuestion
    let action: (String) -> Void

    var body: some View {
        VStack(spacing: 9) {
            ForEach(question.options, id: \.self) { option in
                Button { action(option) } label: {
                    HStack {
                        Text(option).font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 15)
                    .frame(height: 48)
                    .background(DistrictTheme.card, in: RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(DistrictTheme.border))
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct PlannerReview: View {
    let draft: TripPlanDraft
    let intelligenceStatus: String
    let isGenerating: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                AIBadge()
                VStack(alignment: .leading, spacing: 5) {
                    Text("I have everything I need").font(.headline)
                    Text("Here’s the brief I’ll use to build the itinerary.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(13)
                .background(DistrictTheme.card, in: RoundedRectangle(cornerRadius: 17))
            }

            VStack(spacing: 0) {
                ReviewRow(symbol: "mappin.and.ellipse", title: "Destination", value: draft.destination)
                ReviewRow(symbol: "calendar", title: "Dates", value: draft.dates)
                ReviewRow(symbol: "person.3.fill", title: "Group", value: draft.travellers)
                ReviewRow(symbol: "indianrupeesign", title: "Budget", value: draft.budget)
                ReviewRow(symbol: "paintpalette.fill", title: "Trip style", value: draft.theme)
                ReviewRow(
                    symbol: "list.number",
                    title: "Daily plans",
                    value: "\(draft.plansPerDay) \(draft.plansPerDay == 1 ? "plan" : "plans") per day"
                )
                ReviewRow(symbol: "bed.double.fill", title: "Stay", value: draft.accommodation)
                ReviewRow(symbol: "ticket.fill", title: "Existing", value: draft.existingBooking, showsDivider: false)
            }
            .districtCard(radius: 20)

            Label(intelligenceStatus, systemImage: "apple.intelligence")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button(action: action) {
                HStack {
                    if isGenerating { ProgressView().tint(.white) }
                    Label(
                        isGenerating ? "Building your itinerary…" : "Generate complete itinerary",
                        systemImage: "sparkles"
                    )
                }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(DistrictTheme.accent, in: RoundedRectangle(cornerRadius: 17))
            }
            .disabled(isGenerating)
        }
    }
}

private struct ReviewRow: View {
    let symbol: String
    let title: String
    let value: String
    var showsDivider = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.white).frame(width: 22)
            Text(title).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 50)
        .overlay(alignment: .bottom) {
            if showsDivider { Divider().padding(.leading, 49) }
        }
    }
}

// MARK: - Interactive trip assistant

private struct TripInteractiveAIView: View {
    let tripName: String
    let tripItems: [TripItem]

    @State private var messages: [ChatMessage]
    @State private var question = ""
    @State private var isResponding = false
    @FocusState private var isComposerFocused: Bool

    init(tripName: String, tripItems: [TripItem]) {
        self.tripName = tripName
        self.tripItems = tripItems
        let dayCount = Set(tripItems.map(\.day)).count
        let introduction: String
        if tripItems.isEmpty {
            introduction = "Your \(tripName) Hotlist is ready. Ask me about destinations, trip ideas, budgets, group polls, Add Items, or anything else in the app. When you’re ready, I can help you create the itinerary."
        } else {
            introduction = "Your \(tripName) itinerary is ready with \(tripItems.count) plans across \(dayCount) day\(dayCount == 1 ? "" : "s"). Ask me about timings, places, travel order, group polls, alternatives, or how anything in the app works."
        }
        _messages = State(
            initialValue: [
                ChatMessage(
                    sender: "assistant",
                    text: introduction
                )
            ]
        )
    }

    private var suggestedQuestions: [String] {
        if tripItems.isEmpty {
            return [
                "How should I start planning?",
                "Suggest a trip theme",
                "Explain the group polls",
                "How does Add Items work?"
            ]
        }
        return [
            "What is our plan today?",
            "Where do we have free time?",
            "Explain the group polls",
            "Suggest an alternative"
        ]
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(messages) { message in
                        TripAIMessageRow(message: message)
                            .id(message.id)
                    }

                    if messages.count == 1 {
                        suggestionPicker
                    }

                    if isResponding {
                        ProgressView()
                            .controlSize(.regular)
                            .accessibilityLabel("Loading")
                        .padding(.leading, 44)
                        .id("thinking")
                    }
                }
                .padding(.horizontal, DistrictTheme.horizontalPadding)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                guard let lastID = messages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .onChange(of: isResponding) { _, responding in
                guard responding else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("thinking", anchor: .bottom)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .background(DistrictTheme.canvas)
    }

    private var suggestionPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Try asking")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestedQuestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            send(suggestion)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(.white.opacity(0.16))
                    }
                }
            }
        }
        .padding(.leading, 44)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about your trip or the app", text: $question, axis: .vertical)
                .lineLimit(1...4)
                .focused($isComposerFocused)
                .submitLabel(.send)
                .onSubmit { sendQuestion() }

            Button("Send", systemImage: "arrow.up") {
                sendQuestion()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(DistrictTheme.accent)
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isResponding)
            .accessibilityLabel("Send question")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func sendQuestion() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        question = ""
        isComposerFocused = false
        send(trimmed)
    }

    private func send(_ text: String) {
        guard !isResponding else { return }

        let history = messages
        messages.append(ChatMessage(sender: "user", text: text))
        isResponding = true

        Task {
            let answer = await FoundationItineraryPlanner.answerTripQuestion(
                text,
                tripName: tripName,
                items: tripItems,
                conversation: history
            )
            messages.append(ChatMessage(sender: "assistant", text: answer))
            isResponding = false
        }
    }
}

private struct TripAIMessageRow: View {
    let message: ChatMessage

    private var isUser: Bool { message.sender == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 48) }

            if !isUser {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(DistrictTheme.accent, in: Circle())
                    .accessibilityHidden(true)
            }

            Text(message.text)
                .font(.body)
                .foregroundStyle(.white)
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(
                    isUser ? DistrictTheme.accent : DistrictTheme.raised,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

            if !isUser { Spacer(minLength: 24) }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hackathon Add Items

struct AIConciergeView: View {
    @ObservedObject var store: TripStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SmartCatalogSearchView(store: store) { recommendation, day in
                store.addRecommendationAsProposal(
                    recommendation,
                    preferredDay: day
                )
                dismiss()
            }
            .navigationTitle("Add items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .tint(.gray)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct SmartCatalogSearchView: View {
    @ObservedObject var store: TripStore
    let selectAction: (Recommendation, String) -> Void
    @State private var query = ""
    @State private var selectedDay = "Day 1"
    @State private var selectedCategory = CatalogCategory.all
    @State private var results: [Recommendation] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var days: [String] {
        let count = store.currentDraft?.tripDayCount ?? 5
        return (1...count).map { "Day \($0)" }
    }

    private var visibleResults: [Recommendation] {
        guard selectedCategory != .all else { return results }
        return results.filter { selectedCategory.includes($0) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 12) {
                    CatalogSearchField(
                        text: $query,
                        prompt: "Search food, movies, games, events…"
                    )

                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text("Add to")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Add to day", selection: $selectedDay) {
                            ForEach(days, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(DistrictTheme.accent)
                    }

                    CatalogCategoryPicker(selection: $selectedCategory)
                }
                .padding(.horizontal, DistrictTheme.horizontalPadding)

                HStack {
                    Text(sectionTitle)
                        .font(.title3.bold())
                    Spacer()
                    if isSearching { ProgressView().controlSize(.small) }
                    else { Text("Rating • distance • fit").font(.caption).foregroundStyle(.secondary) }
                }
                .padding(.horizontal, DistrictTheme.horizontalPadding)

                if visibleResults.isEmpty && !isSearching {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 44)
                } else {
                    ForEach(visibleResults) { recommendation in
                        RecommendationSearchCard(
                            recommendation: recommendation,
                            selectedDay: selectedDay
                        ) {
                            selectAction(recommendation, selectedDay)
                        }
                        .padding(.horizontal, DistrictTheme.horizontalPadding)
                    }
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(DistrictTheme.canvas)
        .scrollDismissesKeyboard(.interactively)
        .task {
            results = store.recommendations.sorted { $0.rating > $1.rating }
        }
        .onChange(of: query) { scheduleSearch() }
        .onDisappear { searchTask?.cancel() }
    }

    private var sectionTitle: String {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return selectedCategory == .all ? "Best matches" : selectedCategory.rawValue
        }
        return selectedCategory == .all ? "Explore everything nearby" : selectedCategory.rawValue
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if search.isEmpty {
            isSearching = false
            results = store.recommendations.sorted { $0.rating > $1.rating }
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let ranked = await store.recommendationsForIdea(search)
            guard !Task.isCancelled else { return }
            results = Array(ranked.prefix(6))
            isSearching = false
        }
    }
}

private enum CatalogCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case food = "Food"
    case movies = "Movies"
    case events = "Events"
    case games = "Games"
    case activities = "Activities"
    case sports = "Sports"
    case nightlife = "Nightlife"
    case wellness = "Wellness"
    case shopping = "Shopping"
    case attractions = "Attractions"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2.fill"
        case .food: "fork.knife"
        case .movies: "film.fill"
        case .events: "ticket.fill"
        case .games: "gamecontroller.fill"
        case .activities: "figure.hiking"
        case .sports: "sportscourt.fill"
        case .nightlife: "music.note"
        case .wellness: "leaf.fill"
        case .shopping: "bag.fill"
        case .attractions: "building.columns.fill"
        }
    }

    func includes(_ recommendation: Recommendation) -> Bool {
        let category = recommendation.category.uppercased()
        return switch self {
        case .all: true
        case .food: ["RESTAURANT", "CAFÉ", "CAFE", "FOOD"].contains(category)
        case .movies: category == "MOVIE"
        case .events: ["EVENT", "COMEDY", "CONCERT"].contains(category)
        case .games: ["GAME", "GAMES", "PLAY"].contains(category)
        case .activities: ["ACTIVITY", "ADVENTURE", "CREATIVE"].contains(category)
        case .sports: category == "SPORTS"
        case .nightlife: category == "NIGHTLIFE"
        case .wellness: category == "WELLNESS"
        case .shopping: category == "SHOPPING"
        case .attractions: ["ATTRACTION", "CULTURE"].contains(category)
        }
    }
}

private struct CatalogCategoryPicker: View {
    @Binding var selection: CatalogCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CatalogCategory.allCases) { category in
                    Button {
                        withAnimation(.snappy) { selection = category }
                    } label: {
                        Label(category.rawValue, systemImage: category.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selection == category ? DistrictTheme.ink : .white)
                            .padding(.horizontal, 13)
                            .frame(height: 38)
                            .background(
                                selection == category ? Color.white : DistrictTheme.raised,
                                in: Capsule()
                            )
                            .overlay(Capsule().stroke(DistrictTheme.border))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CatalogSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !text.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 52)
        .background(DistrictTheme.raised, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DistrictTheme.border))
    }
}

private struct RecommendationSearchCard: View {
    let recommendation: Recommendation
    let selectedDay: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 13) {
                RecommendationArtwork(recommendation: recommendation)
                VStack(alignment: .leading, spacing: 5) {
                    Text(recommendation.title)
                        .font(.headline)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(recommendation.category.capitalized)
                        Text("•")
                        Text(recommendation.scheduleFit)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    HStack(spacing: 10) {
                        Label(
                            recommendation.rating.formatted(.number.precision(.fractionLength(1))),
                            systemImage: "star.fill"
                        )
                        .foregroundStyle(.green)
                        Label(recommendation.distance, systemImage: "location.fill")
                    }
                    .font(.caption.weight(.semibold))
                    Text(recommendation.price).font(.subheadline.bold())
                }
                Spacer(minLength: 0)
            }

            Divider()
            PlanInformationRow(symbol: "calendar", text: "\(selectedDay) • \(recommendation.time)")
            PlanInformationRow(symbol: "mappin.and.ellipse", text: recommendation.venue)
            PlanInformationRow(
                symbol: "timer",
                text: "Poll deadline adjusts to this fixed slot so the group has time to book"
            )

            Button(action: action) {
                Label("Add and start group poll", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DistrictTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .districtCard(radius: 20)
    }
}

private struct RecommendationArtwork: View {
    let recommendation: Recommendation

    var body: some View {
        Image(systemName: recommendation.symbol)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 92, height: 92)
            .background(
                LinearGradient(
                    colors: recommendation.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 17)
            )
    }
}

private struct PlanInformationRow: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }
}

struct Recommendation: Identifiable {
    let id: String
    let title: String
    let category: String
    let price: String
    let scheduleFit: String
    let day: String
    let time: String
    let venue: String
    let area: String
    let distance: String
    let rating: Double
    let symbol: String
    let colors: [Color]
}

struct DistrictAddItemsView: View {
    @StateObject private var store: TripStore

    init(
        tripName: String,
        tripItems: [TripItem],
        onAdd: @escaping (TripItem) -> Void
    ) {
        var labelsByDay: [Int: String] = [:]
        for item in tripItems where labelsByDay[item.day] == nil && !item.tripDate.isEmpty {
            labelsByDay[item.day] = item.tripDate
        }

        _store = StateObject(
            wrappedValue: TripStore(
                addItemsFor: tripName,
                dayCount: max(1, tripItems.map(\.day).max() ?? 1),
                dateLabelForDay: { labelsByDay[$0] ?? "" },
                onAdd: onAdd
            )
        )
    }

    var body: some View {
        AIConciergeView(store: store)
    }
}

// MARK: - DistrictTogether adapter

enum DistrictTheme {
    static let ink = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let accent = Color(red: 0.58, green: 0.28, blue: 0.96)
    static let coral = Color(red: 1.00, green: 0.28, blue: 0.33)
    static let plum = Color(red: 0.45, green: 0.16, blue: 0.58)
    static let canvas = Color(red: 0.055, green: 0.055, blue: 0.065)
    static let card = Color(red: 0.105, green: 0.105, blue: 0.12)
    static let raised = Color(red: 0.15, green: 0.15, blue: 0.17)
    static let border = Color.white.opacity(0.09)
    static let mint = Color(red: 0.24, green: 0.70, blue: 0.55)
    static let cardRadius: CGFloat = 24
    static let horizontalPadding: CGFloat = 16
}

extension Color {
    static let violet = DistrictTheme.accent
}

extension View {
    func districtCard(radius: CGFloat = DistrictTheme.cardRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(DistrictTheme.card, in: shape)
            .overlay { shape.stroke(DistrictTheme.border) }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = proposal.width ?? 0
        var position = CGPoint.zero
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if position.x + size.width > availableWidth, position.x > 0 {
                position.x = 0
                position.y += rowHeight + spacing
                rowHeight = 0
            }
            position.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: availableWidth, height: position.y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var position = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if position.x + size.width > bounds.maxX, position.x > bounds.minX {
                position.x = bounds.minX
                position.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: position, proposal: ProposedViewSize(size))
            position.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct TravellerPreference: Identifiable, Hashable {
    let id: UUID
    var name: String
    var preference: String

    init(id: UUID = UUID(), name: String, preference: String) {
        self.id = id
        self.name = name
        self.preference = preference
    }
}

enum TripPlannerEntryMode: String, CaseIterable, Identifiable {
    case chat = "Ask AI"
    case guided = "Guided setup"
    case written = "Write full trip"

    var id: String { rawValue }

    func pickerTitle(hasItinerary: Bool) -> String {
        switch self {
        case .chat:
            return "Ask AI"
        case .guided:
            return hasItinerary ? "Edit plan" : "Guided setup"
        case .written:
            return hasItinerary ? "Rewrite" : "Write full trip"
        }
    }
}

enum TripDateFormatting {
    static func fullDate(_ date: Date) -> String {
        format(date, pattern: "d MMM yyyy")
    }

    static func day(_ date: Date) -> String {
        format(date, pattern: "EEE, d MMM")
    }

    static func range(from startDate: Date, to endDate: Date) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: max(startDate, endDate))
        let dayCount = max(
            1,
            (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        )

        let rangeText: String
        if calendar.isDate(start, inSameDayAs: end) {
            rangeText = format(start, pattern: "d MMM yyyy")
        } else if calendar.isDate(start, equalTo: end, toGranularity: .month) {
            rangeText = "\(format(start, pattern: "d"))–\(format(end, pattern: "d MMM yyyy"))"
        } else if calendar.isDate(start, equalTo: end, toGranularity: .year) {
            rangeText = "\(format(start, pattern: "d MMM"))–\(format(end, pattern: "d MMM yyyy"))"
        } else {
            rangeText = "\(format(start, pattern: "d MMM yyyy"))–\(format(end, pattern: "d MMM yyyy"))"
        }

        return "\(rangeText) • \(dayCount) \(dayCount == 1 ? "day" : "days")"
    }

    private static func format(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_IN")
        formatter.timeZone = .current
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

struct TripPlanDraft {
    var destination = "Jaipur"
    var dates = TripDateFormatting.range(
        from: Calendar.current.startOfDay(for: Date()),
        to: Calendar.current.date(
            byAdding: .day,
            value: 4,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()
    )
    var startDate = Calendar.current.startOfDay(for: Date())
    var endDate = Calendar.current.date(
        byAdding: .day,
        value: 4,
        to: Calendar.current.startOfDay(for: Date())
    ) ?? Date()
    var travellers = "1 person"
    var travellerMix = "1 adult"
    var theme = "Mixed highlights"
    var budget = "₹18,000 per person"
    var budgetRules = "Mostly fixed • Food, activities and local transport • 10% reserve"
    var pace = "Balanced • 3 plans each day"
    var plansPerDay = 3
    var dailyRhythm = "Flexible mornings and evenings"
    var interests = "Food, culture and local highlights"
    var food = "AI balances group-friendly dining"
    var existingBooking = "Nothing yet"
    var arrivalPlan = "Arrival time not set"
    var departurePlan = "Departure time not set"
    var accommodation = "Not booked yet"
    var transportPreference = "Let District decide • Under 30 minutes"
    var splitPreference = "Only when interests are very different"
    var accessibility = "No special requirements"
    var organizerBrief = ""
    var memberPreferences: [TravellerPreference] = []

    var travellerCount: Int {
        Int(travellers.split(separator: " ").first ?? "1") ?? 1
    }

    static func paceLabel(for planCount: Int) -> String {
        switch min(4, max(1, planCount)) {
        case 1: "Light • 1 plan each day"
        case 2: "Relaxed • 2 plans each day"
        case 3: "Balanced • 3 plans each day"
        default: "Full • 4 plans each day"
        }
    }

    static func planCount(from pace: String) -> Int {
        for count in 1...4 where pace.contains("\(count) plan") {
            return count
        }
        return 3
    }

    var tripDayCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return max(
            1,
            min(10, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        )
    }

    func dateLabel(for dayNumber: Int) -> String {
        let date = Calendar.current.date(
            byAdding: .day,
            value: max(0, dayNumber - 1),
            to: startDate
        ) ?? startDate
        return TripDateFormatting.day(date)
    }

    var memberSummary: String {
        guard !memberPreferences.isEmpty else { return "AI will balance the whole group" }
        return memberPreferences
            .map { "\($0.name): \($0.preference)" }
            .joined(separator: " • ")
    }
}

@MainActor
final class TripStore: ObservableObject {
    @Published private(set) var currentDraft: TripPlanDraft?
    @Published private(set) var isGeneratingItinerary = false
    @Published private(set) var hasGeneratedItinerary = false

    let hotlistName: String
    let existingTripItems: [TripItem]
    let plannerEntryMode: TripPlannerEntryMode
    private(set) var plannerShouldUseCurrentLocation = false

    private let onComplete: (String, [TripItem]) -> Void
    private let onAddItem: ((TripItem) -> Void)?
    private let addItemDateLabel: ((Int) -> String)?

    init(
        hotlistName: String,
        existingTripItems: [TripItem] = [],
        onComplete: @escaping (String, [TripItem]) -> Void
    ) {
        let trimmedName = hotlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hotlistName = trimmedName.isEmpty ? "New trip" : trimmedName
        self.existingTripItems = existingTripItems
        self.plannerEntryMode = existingTripItems.isEmpty ? .guided : .chat
        self.hasGeneratedItinerary = !existingTripItems.isEmpty
        self.onComplete = onComplete
        self.onAddItem = nil
        self.addItemDateLabel = nil
    }

    init(
        addItemsFor tripName: String,
        dayCount: Int,
        dateLabelForDay: @escaping (Int) -> String,
        onAdd: @escaping (TripItem) -> Void
    ) {
        let trimmedName = tripName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hotlistName = trimmedName.isEmpty ? "New trip" : trimmedName
        self.existingTripItems = []
        self.plannerEntryMode = .guided
        self.onComplete = { _, _ in }
        self.onAddItem = onAdd
        self.addItemDateLabel = dateLabelForDay

        var draft = TripPlanDraft()
        draft.destination = self.hotlistName
        draft.endDate = Calendar.current.date(
            byAdding: .day,
            value: max(0, dayCount - 1),
            to: draft.startDate
        ) ?? draft.startDate
        draft.dates = TripDateFormatting.range(from: draft.startDate, to: draft.endDate)
        self.currentDraft = draft
    }

    var recommendations: [Recommendation] {
        let destination = currentDraft?.destination ?? "your stay"
        let nearbyArea = recommendationAnchor(fallback: destination)
        return [
            Recommendation(
                id: "screening",
                title: "India night match screening",
                category: "EVENT",
                price: "₹450",
                scheduleFit: "Starts after dinner • 18 seats",
                day: "Day 2",
                time: "8:00–10:30 PM",
                venue: "The Courtyard Arena",
                area: nearbyArea,
                distance: "2.1 km",
                rating: 4.6,
                symbol: "sportscourt.fill",
                colors: [.red, .indigo]
            ),
            Recommendation(
                id: "lore",
                title: "Top-rated local dinner",
                category: "RESTAURANT",
                price: "₹1,400",
                scheduleFit: "Top-rated dinner • Table available",
                day: "Day 1",
                time: "8:00–9:30 PM",
                venue: "Local Table",
                area: nearbyArea,
                distance: "3.4 km",
                rating: 4.8,
                symbol: "fork.knife",
                colors: [.orange, .brown]
            ),
            Recommendation(
                id: "acoustic",
                title: "Live acoustic night",
                category: "EVENT",
                price: "₹800",
                scheduleFit: "Easy add-on after dinner",
                day: "Day 3",
                time: "9:00–11:00 PM",
                venue: "Cohiba",
                area: nearbyArea,
                distance: "2.6 km",
                rating: 4.7,
                symbol: "music.microphone",
                colors: [.purple, .pink]
            ),
            Recommendation(
                id: "badminton",
                title: "Badminton social",
                category: "PLAY",
                price: "₹350",
                scheduleFit: "Open morning slot • Equipment included",
                day: "Day 4",
                time: "10:00–11:30 AM",
                venue: "District Sports Club",
                area: nearbyArea,
                distance: "4.1 km",
                rating: 4.5,
                symbol: "figure.badminton",
                colors: [.blue, .mint]
            ),
            Recommendation(
                id: "kayaking",
                title: "Sunset kayaking",
                category: "ADVENTURE",
                price: "₹1,100",
                scheduleFit: "Best fit before dinner • 6 slots",
                day: "Day 2",
                time: "4:00–5:30 PM",
                venue: "Chapora River Collective",
                area: nearbyArea,
                distance: "3.2 km",
                rating: 4.8,
                symbol: "water.waves",
                colors: [.blue, .cyan]
            ),
            Recommendation(
                id: "movie",
                title: "Open-air movie night",
                category: "MOVIE",
                price: "₹650",
                scheduleFit: "Free evening • 12 seats",
                day: "Day 4",
                time: "7:30–10:00 PM",
                venue: "Sunset Cinema Club",
                area: nearbyArea,
                distance: "2.8 km",
                rating: 4.7,
                symbol: "film.fill",
                colors: [.indigo, .purple]
            ),
            Recommendation(
                id: "pottery",
                title: "Clay & chai workshop",
                category: "CREATIVE",
                price: "₹1,200",
                scheduleFit: "Ideal split-plan window",
                day: "Day 3",
                time: "2:00–4:00 PM",
                venue: "The Local Studio",
                area: nearbyArea,
                distance: "1.9 km",
                rating: 4.9,
                symbol: "paintpalette.fill",
                colors: [DistrictTheme.plum, .pink]
            ),
            Recommendation(
                id: "waterpark",
                title: "Splash water park",
                category: "ACTIVITY",
                price: "₹1,250",
                scheduleFit: "Best for a free afternoon",
                day: "Day 4",
                time: "12:00–5:00 PM",
                venue: "Splash Adventure Park",
                area: nearbyArea,
                distance: "6.8 km",
                rating: 4.4,
                symbol: "water.waves.and.arrow.trianglehead.up",
                colors: [.cyan, .blue]
            ),
            Recommendation(
                id: "aeronot",
                title: "Aeronot coffee tasting",
                category: "CAFÉ",
                price: "₹550",
                scheduleFit: "Quiet break near your route",
                day: "Day 3",
                time: "11:00 AM–12:00 PM",
                venue: "Aeronot Coffee Lab",
                area: nearbyArea,
                distance: "1.4 km",
                rating: 4.8,
                symbol: "cup.and.saucer.fill",
                colors: [.brown, .orange]
            ),
            Recommendation(
                id: "cinema",
                title: "Top-rated cinema show",
                category: "MOVIE",
                price: "₹420",
                scheduleFit: "Best seats available • Evening show",
                day: "Day 2",
                time: "7:15–10:00 PM",
                venue: "District PVR Select",
                area: nearbyArea,
                distance: "3.1 km",
                rating: 4.6,
                symbol: "popcorn.fill",
                colors: [.purple, .indigo]
            ),
            Recommendation(
                id: "bowling",
                title: "Bowling and arcade night",
                category: "GAMES",
                price: "₹750",
                scheduleFit: "Group lane available • Games included",
                day: "Day 3",
                time: "6:30–8:00 PM",
                venue: "District Play Arena",
                area: nearbyArea,
                distance: "2.5 km",
                rating: 4.7,
                symbol: "figure.bowling",
                colors: [.blue, .purple]
            ),
            Recommendation(
                id: "escape-room",
                title: "Mystery escape room",
                category: "GAMES",
                price: "₹900",
                scheduleFit: "Private room for the whole group",
                day: "Day 2",
                time: "3:00–4:30 PM",
                venue: "The Hidden District",
                area: nearbyArea,
                distance: "1.8 km",
                rating: 4.8,
                symbol: "puzzlepiece.extension.fill",
                colors: [.orange, .red]
            ),
            Recommendation(
                id: "comedy",
                title: "Live stand-up comedy",
                category: "COMEDY",
                price: "₹699",
                scheduleFit: "Popular show • Limited group seats",
                day: "Day 4",
                time: "8:00–9:30 PM",
                venue: "The Laugh Store",
                area: nearbyArea,
                distance: "3.6 km",
                rating: 4.6,
                symbol: "theatermasks.fill",
                colors: [.pink, .purple]
            ),
            Recommendation(
                id: "cricket-turf",
                title: "Box cricket session",
                category: "SPORTS",
                price: "₹500",
                scheduleFit: "Turf and equipment available",
                day: "Day 2",
                time: "5:00–6:30 PM",
                venue: "District Sports Hub",
                area: nearbyArea,
                distance: "4.2 km",
                rating: 4.5,
                symbol: "figure.cricket",
                colors: [.green, .blue]
            ),
            Recommendation(
                id: "nightclub",
                title: "Late-night DJ experience",
                category: "NIGHTLIFE",
                price: "₹1,200",
                scheduleFit: "Best-rated nightlife near the route",
                day: "Day 4",
                time: "10:00 PM–1:00 AM",
                venue: "The Electric Room",
                area: nearbyArea,
                distance: "2.9 km",
                rating: 4.7,
                symbol: "music.note",
                colors: [.indigo, .pink]
            ),
            Recommendation(
                id: "spa",
                title: "Restorative spa experience",
                category: "WELLNESS",
                price: "₹1,800",
                scheduleFit: "Quiet afternoon slot • Group offer",
                day: "Day 3",
                time: "3:00–4:30 PM",
                venue: "Serein Wellness House",
                area: nearbyArea,
                distance: "2.2 km",
                rating: 4.9,
                symbol: "leaf.fill",
                colors: [.mint, .teal]
            ),
            Recommendation(
                id: "shopping",
                title: "Local designers and market trail",
                category: "SHOPPING",
                price: "Free entry",
                scheduleFit: "Open now • Easy stop along the route",
                day: "Day 1",
                time: "4:00–6:00 PM",
                venue: "District Market Collective",
                area: nearbyArea,
                distance: "1.6 km",
                rating: 4.5,
                symbol: "bag.fill",
                colors: [.orange, .pink]
            ),
            Recommendation(
                id: "landmark",
                title: "Famous \(destination) landmark and heritage tour",
                category: "ATTRACTION",
                price: "₹300",
                scheduleFit: "Top-rated morning attraction",
                day: "Day 1",
                time: "10:00 AM–12:00 PM",
                venue: "Historic City Centre",
                area: nearbyArea,
                distance: "3.0 km",
                rating: 4.8,
                symbol: "building.columns.fill",
                colors: [.brown, .orange]
            )
        ]
    }

    private func recommendationAnchor(fallback: String) -> String {
        guard let accommodation = currentDraft?.accommodation
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !accommodation.isEmpty,
            !accommodation.localizedCaseInsensitiveContains("not booked"),
            !accommodation.localizedCaseInsensitiveContains("not selected")
        else {
            return fallback
        }

        let cleaned = accommodation
            .replacingOccurrences(of: "Booked •", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }

    var appleIntelligenceStatus: String {
        "Personalized on device • Review before sharing"
    }

    func initialDraftForHotlist() -> TripPlanDraft {
        var draft = TripPlanDraft()
        draft.destination = hotlistName
        draft.theme = "A mix of everything"
        draft.interests = "Recommendations that fit the \(hotlistName) collaborative trip"
        return draft
    }

    func consumeCurrentLocationPlannerRequest() {
        plannerShouldUseCurrentLocation = false
    }

    func generateTripWithAppleIntelligence(_ draft: TripPlanDraft) async {
        isGeneratingItinerary = true
        defer { isGeneratingItinerary = false }
        currentDraft = draft
        let ranking = await FoundationItineraryPlanner.rank(
            draft: draft,
            candidates: recommendations
        )
        finish(with: draft, preferredOrder: ranking.recommendationIDs)
    }

    func generateTripFromWrittenBrief(_ brief: String) async {
        isGeneratingItinerary = true
        defer { isGeneratingItinerary = false }
        let fallbackDraft = DistrictTripGenerator.draft(
            from: brief,
            fallback: initialDraftForHotlist()
        )
        var draft = await FoundationItineraryPlanner.interpretWrittenTrip(
            brief,
            fallback: fallbackDraft
        )
        draft.organizerBrief = brief
        currentDraft = draft
        let ranking = await FoundationItineraryPlanner.rank(
            draft: draft,
            candidates: recommendations
        )
        finish(with: draft, preferredOrder: ranking.recommendationIDs)
    }

    func recommendationsForIdea(_ idea: String) async -> [Recommendation] {
        let query = idea.lowercased()

        if query.contains("movie") || query.contains("cinema") {
            return recommendations.filter { $0.category == "MOVIE" }
        }
        if query.contains("restaurant") || query.contains("dinner") || query.contains("food") {
            return recommendations.filter { ["RESTAURANT", "CAFÉ"].contains($0.category) }
        }
        if query.contains("coffee") || query.contains("cafe") || query.contains("café") {
            return recommendations.filter { $0.id == "aeronot" }
        }
        if query.contains("music") || query.contains("concert") || query.contains("event") {
            return recommendations.filter {
                ["EVENT", "COMEDY", "CONCERT", "NIGHTLIFE"].contains($0.category)
            }
        }
        if query.contains("comedy") || query.contains("stand-up") || query.contains("show") {
            return recommendations.filter { $0.category == "COMEDY" }
        }
        if query.contains("game") || query.contains("bowling") || query.contains("arcade") || query.contains("escape") {
            return recommendations.filter { ["GAMES", "PLAY"].contains($0.category) }
        }
        if query.contains("sport") || query.contains("badminton") || query.contains("play") {
            return recommendations.filter { ["SPORTS", "PLAY"].contains($0.category) }
        }
        if query.contains("creative") || query.contains("pottery") || query.contains("art") {
            return recommendations.filter { $0.id == "pottery" }
        }
        if query.contains("water park") {
            return recommendations.filter { $0.id == "waterpark" }
        }
        if query.contains("adventure") || query.contains("water") || query.contains("kayak") {
            return recommendations.filter { ["kayaking", "waterpark"].contains($0.id) }
        }
        if query.contains("night") || query.contains("club") || query.contains("party") || query.contains("dj") {
            return recommendations.filter { $0.category == "NIGHTLIFE" }
        }
        if query.contains("spa") || query.contains("wellness") || query.contains("relax") {
            return recommendations.filter { $0.category == "WELLNESS" }
        }
        if query.contains("shop") || query.contains("market") || query.contains("mall") {
            return recommendations.filter { $0.category == "SHOPPING" }
        }
        if query.contains("attraction") || query.contains("heritage") || query.contains("landmark") || query.contains("museum") {
            return recommendations.filter { ["ATTRACTION", "CULTURE"].contains($0.category) }
        }

        return recommendations.sorted { $0.rating > $1.rating }
    }

    func addRecommendationAsProposal(
        _ recommendation: Recommendation,
        preferredDay: String? = nil
    ) {
        let selectedDay = preferredDay ?? recommendation.day
        let dayNumber = max(
            1,
            Int(selectedDay.split(separator: " ").last ?? "1") ?? 1
        )
        let existingDate = addItemDateLabel?(dayNumber) ?? ""
        let tripDate = existingDate.isEmpty
            ? (currentDraft?.dateLabel(for: dayNumber) ?? "")
            : existingDate

        let normalizedCategory = recommendation.category.uppercased()
        let category: String
        if ["RESTAURANT", "CAFÉ", "CAFE", "FOOD"].contains(normalizedCategory) {
            category = "Restaurant"
        } else if ["EVENT", "COMEDY", "CONCERT", "MOVIE", "NIGHTLIFE"].contains(normalizedCategory) {
            category = "Event"
        } else {
            category = "Activity"
        }

        let imageName: String
        if recommendation.id == "waterpark" {
            imageName = "water_park"
        } else if category == "Restaurant" {
            imageName = "tonino"
        } else {
            imageName = "jaipur_collage"
        }

        let duration: String
        if normalizedCategory == "MOVIE" {
            duration = "2.5 hours"
        } else if category == "Restaurant" {
            duration = "1.5 hours"
        } else {
            duration = "2.0 hours"
        }

        onAddItem?(
            TripItem(
                title: recommendation.title,
                category: category,
                location: recommendation.venue,
                imageName: imageName,
                ownerName: "K",
                ownerFullName: "You",
                addedTimeAgo: "just now",
                thumbsUpCount: 1,
                thumbsDownCount: 0,
                userVote: "up",
                duration: duration,
                day: dayNumber,
                tripDate: tripDate,
                timeSlot: recommendation.time,
                yesVoters: [
                    YesVoter(
                        initial: "K",
                        fullName: "You",
                        colorHex: "ec4899"
                    )
                ],
                hasConflict: false,
                isConfirmed: false
            )
        )
    }

    private func finish(
        with draft: TripPlanDraft,
        preferredOrder: [String]
    ) {
        currentDraft = draft
        hasGeneratedItinerary = true
        onComplete(
            draft.destination,
            DistrictTripGenerator.items(
                from: draft,
                recommendations: recommendations,
                preferredOrder: preferredOrder
            )
        )
    }
}

@MainActor
final class CurrentLocationProvider: NSObject, ObservableObject {
    @Published private(set) var placeName: String?
    @Published private(set) var isLocating = false
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestCurrentPlace() {
        errorMessage = nil
        isLocating = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            isLocating = false
            errorMessage = "Location access is off. Enter the destination instead."
        @unknown default:
            isLocating = false
            errorMessage = "Enter the destination manually."
        }
    }

    private func resolve(_ location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor in
                guard let self else { return }
                guard let place = placemarks?.first else {
                    self.isLocating = false
                    self.errorMessage = "Couldn’t identify this place. Enter it manually."
                    return
                }
                self.placeName = [place.locality, place.administrativeArea]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                self.isLocating = false
            }
        }
    }
}

extension CurrentLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in resolve(location) }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            isLocating = false
            errorMessage = "Couldn’t get your location. Enter the destination manually."
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.requestLocation()
            } else if status == .denied || status == .restricted {
                isLocating = false
                errorMessage = "Location access is off. Enter the destination instead."
            }
        }
    }
}

struct LocationSuggestion: Identifiable, Hashable, Sendable {
    let title: String
    let subtitle: String

    var id: String { "\(title)|\(subtitle)" }
    var fullName: String { subtitle.isEmpty ? title : "\(title), \(subtitle)" }
}

@MainActor
final class LocationSearchCompleter: NSObject, ObservableObject {
    private static let knownDestinations: [LocationSuggestion] = [
        LocationSuggestion(title: "Jaipur", subtitle: "Rajasthan, India"),
        LocationSuggestion(title: "Hawa Mahal", subtitle: "Pink City, Jaipur, Rajasthan"),
        LocationSuggestion(title: "Amer Fort", subtitle: "Amer, Jaipur, Rajasthan"),
        LocationSuggestion(title: "Jaipur Marriott Hotel", subtitle: "Ashram Marg, Jaipur, Rajasthan"),
        LocationSuggestion(title: "New Delhi", subtitle: "Delhi, India"),
        LocationSuggestion(title: "Gurugram", subtitle: "Haryana, India"),
        LocationSuggestion(title: "Mumbai", subtitle: "Maharashtra, India"),
        LocationSuggestion(title: "Bengaluru", subtitle: "Karnataka, India"),
        LocationSuggestion(title: "Goa", subtitle: "India"),
        LocationSuggestion(title: "Anjuna", subtitle: "North Goa, Goa"),
        LocationSuggestion(title: "Kochi", subtitle: "Kerala, India"),
        LocationSuggestion(title: "Udaipur", subtitle: "Rajasthan, India"),
        LocationSuggestion(title: "Mussoorie", subtitle: "Uttarakhand, India"),
        LocationSuggestion(title: "Dehradun", subtitle: "Uttarakhand, India"),
        LocationSuggestion(title: "Manali", subtitle: "Himachal Pradesh, India"),
        LocationSuggestion(title: "Hyderabad", subtitle: "Telangana, India"),
        LocationSuggestion(title: "Pune", subtitle: "Maharashtra, India")
    ]

    @Published private(set) var suggestions: [LocationSuggestion] = []
    @Published private(set) var isSearching = false
    private let completer = MKLocalSearchCompleter()
    private var currentQuery = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        currentQuery = trimmed
        guard trimmed.count >= 2 else {
            suggestions = []
            isSearching = false
            completer.queryFragment = ""
            return
        }

        suggestions = Self.localSuggestions(for: trimmed)
        isSearching = true
        completer.queryFragment = trimmed
    }

    private static func localSuggestions(for query: String) -> [LocationSuggestion] {
        let normalizedQuery = query
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        return knownDestinations.filter { destination in
            let searchableValue = destination.fullName
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
            return searchableValue.contains(normalizedQuery)
        }
    }

    private func updateSuggestions(
        remoteSuggestions: [LocationSuggestion],
        for query: String
    ) {
        guard query == currentQuery else { return }

        var merged: [LocationSuggestion] = []
        for suggestion in Self.localSuggestions(for: query) + remoteSuggestions
        where !merged.contains(where: { $0.id == suggestion.id }) {
            merged.append(suggestion)
        }
        suggestions = Array(merged.prefix(6))
        isSearching = false
    }
}

extension LocationSearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let query = completer.queryFragment
        let results = completer.results.prefix(6).map {
            LocationSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
        Task { @MainActor in
            updateSuggestions(remoteSuggestions: results, for: query)
        }
    }

    nonisolated func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: Error
    ) {
        let query = completer.queryFragment
        Task { @MainActor in
            updateSuggestions(remoteSuggestions: [], for: query)
        }
    }
}

private enum DistrictTripGenerator {
    private enum DayPart {
        case morning
        case midday
        case afternoon
        case evening
    }

    private struct ScheduleSlot {
        let part: DayPart
        let time: String
    }

    static func items(
        from draft: TripPlanDraft,
        recommendations: [Recommendation],
        preferredOrder: [String]
    ) -> [TripItem] {
        let plansPerDay = min(4, max(1, draft.plansPerDay))
        let preferredRankBonus = Dictionary(
            uniqueKeysWithValues: preferredOrder.enumerated().map { index, id in
                (id, Double(preferredOrder.count - index) * 6)
            }
        )
        let planningContext = [
            draft.destination,
            draft.accommodation,
            draft.transportPreference,
            draft.theme,
            draft.interests,
            draft.food,
            draft.organizerBrief,
            draft.memberSummary
        ]
            .joined(separator: " ")
            .lowercased()
        let rankedRecommendations = recommendations.sorted {
            baseScore(for: $0, context: planningContext)
                + preferredRankBonus[$0.id, default: 0]
                > baseScore(for: $1, context: planningContext)
                + preferredRankBonus[$1.id, default: 0]
        }
        let bookingsByDay = fixedBookingsByDay(from: draft)
        var generated: [TripItem] = []
        var availableRecommendations = rankedRecommendations

        for day in 1...draft.tripDayCount {
            let date = Calendar.current.date(
                byAdding: .day,
                value: day - 1,
                to: draft.startDate
            ) ?? draft.startDate
            let fixedBookings = bookingsByDay[day] ?? []
            let generatedPlanCount = max(0, plansPerDay - fixedBookings.count)
            let slots = scheduleSlots(
                count: generatedPlanCount,
                reservingEvening: !fixedBookings.isEmpty
            )
            var usedIDsForDay: Set<String> = []
            var usedCategoriesForDay: Set<String> = []

            for slot in slots {
                if availableRecommendations.isEmpty {
                    availableRecommendations = rankedRecommendations.filter {
                        !usedIDsForDay.contains($0.id)
                    }
                }

                guard let selectedIndex = availableRecommendations.indices.max(by: { left, right in
                    relevanceScore(
                        for: availableRecommendations[left],
                        context: planningContext,
                        slot: slot.part,
                        usedCategories: usedCategoriesForDay,
                        preferredRankBonus: preferredRankBonus
                    ) < relevanceScore(
                        for: availableRecommendations[right],
                        context: planningContext,
                        slot: slot.part,
                        usedCategories: usedCategoriesForDay,
                        preferredRankBonus: preferredRankBonus
                    )
                }) else { continue }

                let recommendation = availableRecommendations.remove(at: selectedIndex)
                usedIDsForDay.insert(recommendation.id)
                usedCategoriesForDay.insert(recommendation.category.uppercased())
                generated.append(
                    itineraryItem(
                        from: recommendation,
                        draft: draft,
                        day: day,
                        date: date,
                        time: slot.time
                    )
                )
            }

            for booking in fixedBookings {
                generated.append(
                    fixedBookingItem(booking, draft: draft, day: day, date: date)
                )
            }
        }

        return generated.enumerated().map { index, item in
            DemoCollaboration.applyingSample(to: item, index: index)
        }
    }

    private static func scheduleSlots(
        count: Int,
        reservingEvening: Bool
    ) -> [ScheduleSlot] {
        guard count > 0 else { return [] }

        if reservingEvening {
            switch count {
            case 1:
                return [ScheduleSlot(part: .midday, time: "11:30 AM – 1:30 PM")]
            case 2:
                return [
                    ScheduleSlot(part: .morning, time: "9:30 AM – 11:00 AM"),
                    ScheduleSlot(part: .afternoon, time: "3:30 PM – 5:30 PM")
                ]
            default:
                return [
                    ScheduleSlot(part: .morning, time: "9:00 AM – 10:30 AM"),
                    ScheduleSlot(part: .midday, time: "12:00 PM – 1:30 PM"),
                    ScheduleSlot(part: .afternoon, time: "3:30 PM – 5:30 PM")
                ]
            }
        }

        switch count {
        case 1:
            return [ScheduleSlot(part: .midday, time: "11:30 AM – 1:30 PM")]
        case 2:
            return [
                ScheduleSlot(part: .morning, time: "10:00 AM – 12:00 PM"),
                ScheduleSlot(part: .evening, time: "7:30 PM – 9:30 PM")
            ]
        case 3:
            return [
                ScheduleSlot(part: .morning, time: "9:30 AM – 11:00 AM"),
                ScheduleSlot(part: .afternoon, time: "3:00 PM – 5:00 PM"),
                ScheduleSlot(part: .evening, time: "7:30 PM – 9:30 PM")
            ]
        default:
            return [
                ScheduleSlot(part: .morning, time: "9:00 AM – 10:30 AM"),
                ScheduleSlot(part: .midday, time: "12:00 PM – 1:30 PM"),
                ScheduleSlot(part: .afternoon, time: "3:30 PM – 5:30 PM"),
                ScheduleSlot(part: .evening, time: "8:00 PM – 10:00 PM")
            ]
        }
    }

    private static func baseScore(
        for recommendation: Recommendation,
        context: String
    ) -> Double {
        var score = recommendation.rating * 12
        score += intentBonus(for: recommendation.category, context: context)

        let searchableText = [
            recommendation.title,
            recommendation.category,
            recommendation.venue,
            recommendation.area,
            recommendation.scheduleFit
        ]
            .joined(separator: " ")
            .lowercased()
        let meaningfulTokens = Set(
            context
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 4 }
        )
        let overlapCount = meaningfulTokens.filter { searchableText.contains($0) }.count
        score += Double(min(overlapCount, 6)) * 4

        if let distance = Double(recommendation.distance.split(separator: " ").first ?? "") {
            score += max(0, 7 - distance)
        }
        return score
    }

    private static func relevanceScore(
        for recommendation: Recommendation,
        context: String,
        slot: DayPart,
        usedCategories: Set<String>,
        preferredRankBonus: [String: Double]
    ) -> Double {
        let category = recommendation.category.uppercased()
        var score = baseScore(for: recommendation, context: context)
        score += preferredRankBonus[recommendation.id, default: 0]
        score += slotBonus(for: category, slot: slot)
        if usedCategories.contains(category) { score -= 14 }
        return score
    }

    private static func intentBonus(for category: String, context: String) -> Double {
        let normalized = category.uppercased()
        let keywords: [String]
        switch normalized {
        case "RESTAURANT", "CAFÉ", "CAFE", "FOOD":
            keywords = ["food", "café", "cafe", "restaurant", "dining", "taste", "culinary"]
        case "MOVIE", "CINEMA":
            keywords = ["movie", "cinema", "film", "entertainment"]
        case "EVENT", "COMEDY", "CONCERT":
            keywords = ["event", "music", "concert", "comedy", "show", "entertainment"]
        case "NIGHTLIFE":
            keywords = ["nightlife", "party", "club", "music", "night"]
        case "ADVENTURE", "SPORTS", "PLAY":
            keywords = ["adventure", "nature", "sport", "outdoor", "water", "play"]
        case "GAMES":
            keywords = ["game", "bowling", "arcade", "escape", "entertainment"]
        case "CREATIVE":
            keywords = ["creative", "art", "workshop", "culture"]
        case "WELLNESS":
            keywords = ["wellness", "relax", "spa", "slow"]
        case "SHOPPING":
            keywords = ["shopping", "market", "local", "design"]
        case "ATTRACTION", "CULTURE":
            keywords = ["culture", "heritage", "landmark", "history", "sightseeing"]
        default:
            keywords = []
        }
        return keywords.contains(where: context.contains) ? 34 : 0
    }

    private static func slotBonus(for category: String, slot: DayPart) -> Double {
        let preferredCategories: Set<String>
        switch slot {
        case .morning:
            preferredCategories = ["CAFÉ", "CAFE", "ATTRACTION", "SPORTS", "ADVENTURE", "PLAY"]
        case .midday:
            preferredCategories = ["RESTAURANT", "CAFÉ", "CAFE", "ATTRACTION", "SHOPPING"]
        case .afternoon:
            preferredCategories = ["CREATIVE", "WELLNESS", "GAMES", "ADVENTURE", "ACTIVITY", "SHOPPING"]
        case .evening:
            preferredCategories = ["RESTAURANT", "EVENT", "MOVIE", "COMEDY", "CONCERT", "NIGHTLIFE", "GAMES"]
        }
        return preferredCategories.contains(category) ? 24 : 0
    }

    private static func itineraryItem(
        from recommendation: Recommendation,
        draft: TripPlanDraft,
        day: Int,
        date: Date,
        time: String
    ) -> TripItem {
        let normalizedCategory = recommendation.category.uppercased()
        let category: String
        if ["RESTAURANT", "CAFÉ", "CAFE", "FOOD"].contains(normalizedCategory) {
            category = "Restaurant"
        } else if ["EVENT", "COMEDY", "CONCERT", "MOVIE", "NIGHTLIFE"].contains(normalizedCategory) {
            category = "Event"
        } else {
            category = "Activity"
        }

        let imageName: String
        if recommendation.id == "waterpark" {
            imageName = "water_park"
        } else if category == "Restaurant" {
            imageName = "tonino"
        } else {
            imageName = "jaipur_collage"
        }

        let duration: String
        if normalizedCategory == "MOVIE" {
            duration = "2.5 hours"
        } else if recommendation.id == "waterpark" {
            duration = "5.0 hours"
        } else if category == "Restaurant" {
            duration = "1.5 hours"
        } else {
            duration = "2.0 hours"
        }

        let location = recommendation.area.isEmpty || recommendation.area == draft.destination
            ? recommendation.venue
            : "\(recommendation.venue), \(recommendation.area)"

        return TripItem(
            title: recommendation.title,
            category: category,
            location: location,
            imageName: imageName,
            ownerName: "K",
            ownerFullName: "You",
            addedTimeAgo: "Added with itinerary",
            thumbsUpCount: 0,
            thumbsDownCount: 0,
            duration: duration,
            day: day,
            tripDate: TripDateFormatting.day(date),
            timeSlot: time,
            yesVoters: [],
            hasConflict: false,
            isConfirmed: true
        )
    }

    private static func fixedBookingsByDay(from draft: TripPlanDraft) -> [Int: [String]] {
        let bookingText = draft.existingBooking.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bookingText.isEmpty, bookingText != "Nothing yet" else { return [:] }

        var result: [Int: [String]] = [:]
        for (index, booking) in bookingText.components(separatedBy: " • ").enumerated() {
            let day = min(index + 1, draft.tripDayCount)
            result[day, default: []].append(booking)
        }
        return result
    }

    private static func fixedBookingItem(
        _ booking: String,
        draft: TripPlanDraft,
        day: Int,
        date: Date
    ) -> TripItem {
        TripItem(
            title: booking,
            category: "Event",
            location: draft.destination,
            imageName: "jaipur_collage",
            ownerName: "K",
            ownerFullName: "You",
            addedTimeAgo: "Fixed booking",
            thumbsUpCount: 0,
            thumbsDownCount: 0,
            duration: "Fixed time",
            day: day,
            tripDate: TripDateFormatting.day(date),
            timeSlot: "7:00 PM – 8:30 PM",
            yesVoters: [],
            hasConflict: false,
            isConfirmed: true
        )
    }

    static func draft(from brief: String, fallback: TripPlanDraft) -> TripPlanDraft {
        var draft = fallback
        let lowercasedBrief = brief.lowercased()
        let destinations = [
            "Goa", "Jaipur", "Delhi", "Mumbai", "Bengaluru", "Kochi",
            "Manali", "Mussoorie", "Udaipur", "Hyderabad", "Pune"
        ]

        if let destination = destinations.first(where: {
            lowercasedBrief.contains($0.lowercased())
        }) {
            draft.destination = destination
        }

        for count in 1...10 where lowercasedBrief.contains("\(count)-day") || lowercasedBrief.contains("\(count) day") {
            draft.endDate = Calendar.current.date(
                byAdding: .day,
                value: count - 1,
                to: draft.startDate
            ) ?? draft.startDate
            draft.dates = TripDateFormatting.range(from: draft.startDate, to: draft.endDate)
            break
        }

        if let requestedCount = (1...4).first(where: { count in
            lowercasedBrief.contains("\(count) plan per day")
                || lowercasedBrief.contains("\(count) plans per day")
                || lowercasedBrief.contains("\(count) plan each day")
                || lowercasedBrief.contains("\(count) plans each day")
        }) {
            draft.plansPerDay = requestedCount
            draft.pace = TripPlanDraft.paceLabel(for: requestedCount)
        } else if lowercasedBrief.contains("relaxed") {
            draft.plansPerDay = 2
            draft.pace = TripPlanDraft.paceLabel(for: 2)
        } else if lowercasedBrief.contains("full") || lowercasedBrief.contains("packed") {
            draft.plansPerDay = 4
            draft.pace = TripPlanDraft.paceLabel(for: 4)
        }

        if lowercasedBrief.contains("beach") || lowercasedBrief.contains("nightlife") {
            draft.theme = "Beach, cafés & nightlife"
        } else if lowercasedBrief.contains("adventure") || lowercasedBrief.contains("nature") {
            draft.theme = "Adventure & nature"
        } else if lowercasedBrief.contains("movie") || lowercasedBrief.contains("shopping") {
            draft.theme = "Shopping, movies & entertainment"
        } else if lowercasedBrief.contains("wellness") || lowercasedBrief.contains("spa") {
            draft.theme = "Wellness & relaxed experiences"
        }

        return draft
    }
}
