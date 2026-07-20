import SwiftUI

public struct TripFeedView: View {
    @Binding var tripItems: [TripItem]
    @Binding var activeProposal: Proposal?
    @Binding var currentFilter: String
    @Binding var showAIAssistant: Bool
    @Binding var tripName: String
    let onBack: () -> Void

    @State private var editingNoteItem: TripItem? = nil
    @State private var editingNoteText: String = ""
    @State private var showingAddItemsSheet: Bool = false
    @State private var addSearchQuery: String = ""
    @State private var addItemDay: Int = 1
    @State private var alternativeForItem: TripItem? = nil
    @State private var selectedDay: Int? = 1 // Default to Day 1
    @State private var showingMoreActions: Bool = false
    @State private var isEditingTripName: Bool = false
    @State private var editingTripName: String = ""
    @State private var showDeleteConfirmation: Bool = false
    @State private var showingInviteSheet: Bool = false
    @State private var showingCompleteItinerary: Bool = false
    @State private var currentSort: String = "Date Added: New to Old"
    @State private var selectedItemForDetail: TripItem? = nil
    @State private var collaborators: [Collaborator] = [
        Collaborator(name: "Saurabh", initial: "S", colorHex: "7c5cfc", role: "Member"),
        Collaborator(name: "Arjun", initial: "A", colorHex: "22d3a5", role: "Member"),
        Collaborator(name: "Riya", initial: "R", colorHex: "fbbf24", role: "Member")
    ]
    @State private var searchItems: [AddSearchItem] = [
        AddSearchItem(title: "Screening of Final | Manhattan",  category: "Event",      subtitle: "Event",                imageName: "water_park",     visitTimeSlot: "8:00 PM – 10:30 PM"),
        AddSearchItem(title: "Lore - Radisson Hotel",           category: "Restaurant", subtitle: "Restaurant",           imageName: "tonino",         visitTimeSlot: "8:00 PM – 9:30 PM"),
        AddSearchItem(title: "Dhanda Nyoliwala",                category: "Artist",     subtitle: "Artist",               imageName: "jaipur_collage", visitTimeSlot: "8:30 PM – 11:00 PM"),
        AddSearchItem(title: "New Balance",                     category: "Store",      subtitle: "Store • Ambience Mall", imageName: "jaipur_collage", visitTimeSlot: "4:00 PM – 6:00 PM"),
        AddSearchItem(title: "REPPP-RKT Badminton Arena",       category: "Play",       subtitle: "Play",                 imageName: "water_park",     visitTimeSlot: "10:00 AM – 11:30 AM"),
        AddSearchItem(title: "Fun n Food Water Park",           category: "Activity",   subtitle: "Activity",             imageName: "water_park",     visitTimeSlot: "12:00 PM – 5:00 PM"),
        AddSearchItem(title: "Hunterhood 2026 | Kochi",         category: "Event",      subtitle: "Event",                imageName: "jaipur_collage", visitTimeSlot: "7:30 PM – 10:00 PM"),
        AddSearchItem(title: "Aeronot",                         category: "Restaurant", subtitle: "Restaurant",           imageName: "tonino",         visitTimeSlot: "11:00 AM – 12:00 PM")
    ]

    public init(
        tripItems: Binding<[TripItem]>,
        activeProposal: Binding<Proposal?>,
        currentFilter: Binding<String>,
        showAIAssistant: Binding<Bool>,
        tripName: Binding<String>,
        onBack: @escaping () -> Void = {}
    ) {
        self._tripItems = tripItems
        self._activeProposal = activeProposal
        self._currentFilter = currentFilter
        self._showAIAssistant = showAIAssistant
        self._tripName = tripName
        self.onBack = onBack
    }

    // ── Grouped by day ────────────────────────────────────────────────
    private func itemsForDay(_ day: Int) -> [TripItem] {
        filteredItems().filter { $0.day == day }
    }

    private var allDays: [Int] {
        Array(Set(filteredItems().map { $0.day })).sorted()
    }

    private var tripDays: [Int] {
        Array(Set(tripItems.map { $0.day })).sorted()
    }

    private var availableAddDays: [Int] {
        let days = Array(Set(tripItems.map(\.day))).sorted()
        return days.isEmpty ? [1] : days
    }

    private var filteredSearchItems: [AddSearchItem] {
        let query = addSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return searchItems }
        return searchItems.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.category.localizedCaseInsensitiveContains(query)
                || ($0.subtitle?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func dayLabel(_ day: Int) -> String {
        switch day {
        case 1: return "Day 1"
        case 2: return "Day 2"
        case 3: return "Day 3"
        default: return "Day \(day)"
        }
    }

    private func dayDate(_ day: Int) -> String {
        filteredItems().first(where: { $0.day == day })?.tripDate ?? ""
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────────
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tripName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(tripItems.count) items")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                    }

                    Spacer()

                    Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showingMoreActions = true } }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .padding(8)
                    }
                    Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showingInviteSheet = true } }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black)

                // ── Filter Pills ────────────────────────────────────────
                if !tripItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterPill(title: "All")
                            filterPill(title: "Restaurants")
                            filterPill(title: "Activities")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color.black)
                }

                // ── Main Feed ───────────────────────────────────────────
                ZStack(alignment: .bottom) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Keep the shared trip and collaborators visible before planning.
                            heroCard

                            if tripItems.isEmpty {
                                emptyCollaborativeSpace
                            } else {
                            CompleteItinerarySummaryCard(
                                dayCount: tripDays.count,
                                itemCount: tripItems.count,
                                action: { showingCompleteItinerary = true }
                            )

                            // Calendar Section (New!)
                            calendarSection

                            // Sort row
                            HStack {
                                Menu {
                                    Button("Date Added: New to Old") { withAnimation { currentSort = "Date Added: New to Old" } }
                                    Button("Date Added: Old to New") { withAnimation { currentSort = "Date Added: Old to New" } }
                                    Button("Day & Time") { withAnimation { currentSort = "Day & Time" } }
                                } label: {
                                    HStack(spacing: 8) {
                                        HStack(spacing: 2) {
                                            Image(systemName: "arrow.down")
                                                .font(.system(size: 12, weight: .medium))
                                            Image(systemName: "line.3.horizontal.decrease")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(.white)
                                        
                                        HStack(spacing: 4) {
                                            Text("Sort by:")
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundColor(.white.opacity(0.5))
                                            
                                            Text(currentSort)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 4)

                            // Active proposal card
                            if let proposal = activeProposal {
                                ProposalCard(
                                    proposal: proposal,
                                    currentUser: "K",
                                    onVote: { vote in updateVote(vote) },
                                    onApprove: { approveProposal() },
                                    onAddComment: { text in addComment(text) }
                                )
                                .transition(.slide.combined(with: .opacity))
                            }

                            // ── Day-wise sections ──────────────────────
                            ForEach(allDays, id: \.self) { day in
                                let items = itemsForDay(day)
                                if !items.isEmpty {
                                    daySectionView(day: day, items: items)
                                }
                            }
                            }

                            Color.clear.frame(height: 20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        floatingActionBar
                    }
                }

                // Note editor overlay
                if let item = editingNoteItem {
                    noteEditorOverlay(item: item)
                }
            }

            // More actions sheet
            if showingMoreActions {
                moreActionsSheet
            }

            // Invite sheet
            if showingInviteSheet {
                inviteCollaboratorsSheet
            }

        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .alert("Delete Trip", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation { tripItems.removeAll() }
            }
        } message: {
            Text("Are you sure you want to delete \"\(tripName)\"? This action cannot be undone.")
        }
        .fullScreenCover(item: $selectedItemForDetail) { selectedItem in
            ItemDetailView(item: selectedItem, onDismiss: { selectedItemForDetail = nil })
        }
        .sheet(isPresented: $showingCompleteItinerary) {
            CompleteItineraryView(
                tripName: tripName,
                items: $tripItems
            )
        }
        .sheet(isPresented: $showingAddItemsSheet, onDismiss: {
            alternativeForItem = nil
            addSearchQuery = ""
        }) {
            addItemsSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
                .presentationBackground(Color(white: 0.10))
        }
    }

    private var emptyCollaborativeSpace: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 34)

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 82, height: 82)
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            VStack(spacing: 9) {
                Text("No plans yet")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.white)
                Text("Add something yourself or plan the complete trip with AI. Timed plans will appear here for everyone.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 315)
            }

            HStack(spacing: 18) {
                Label("Add manually", systemImage: "plus.circle.fill")
                Label("Plan with AI", systemImage: "sparkles")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.56))

            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, minHeight: 330)
    }

    private var floatingActionBar: some View {
        ZStack(alignment: .trailing) {
            Button {
                alternativeForItem = nil
                addItemDay = selectedDay ?? availableAddDays.first ?? 1
                showingAddItemsSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 19, weight: .semibold))

                    Text("Add items")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(minWidth: 126)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(.white)
            .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("Add items")

            Button {
                showAIAssistant = true
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
            }
            .modifier(FloatingAIButtonStyle())
            .shadow(color: DistrictTheme.accent.opacity(0.45), radius: 13, y: 4)
            .padding(.trailing, 16)
            .accessibilityLabel(tripItems.isEmpty ? "Plan with AI" : "Ask trip AI")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // ── Day Section View ───────────────────────────────────────────────
    @ViewBuilder
    private func daySectionView(day: Int, items: [TripItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {

            // Section header
            HStack(spacing: 8) {
                Text(dayLabel(day))
                    .font(.system(size: 11, weight: .black))
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.55))
                    .kerning(0.8)
                Spacer()
                // Item count pill
                Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(99)
            }

            // Cards
            ForEach(items) { item in
                TripItemCard(
                    item: item,
                    onVoteUp:         { toggleVote(for: item.id, type: "up") },
                    onVoteDown:       { toggleVote(for: item.id, type: "down") },
                    onAddAlternative: {
                        alternativeForItem = item
                        addItemDay = day
                        showingAddItemsSheet = true
                    },
                    onAddNote:        { editingNoteItem = item },
                    onAddToList:      { print("Add to another list") },
                    onRemoveFromList: { withAnimation { tripItems.removeAll(where: { $0.id == item.id }) } }
                )
                .onTapGesture {
                    selectedItemForDetail = item
                }
            }
        }
    }

    private var featuredActivityImages: [String] {
        let generatedImages = tripItems
            .sorted {
                if $0.day == $1.day { return $0.timeSlot < $1.timeSlot }
                return $0.day < $1.day
            }
            .map(\.imageName)
            .filter { !$0.isEmpty }

        let fallbackImages = ["tonino", "jaipur_collage", "water_park"]
        var uniqueImages: [String] = []
        for imageName in generatedImages + fallbackImages where !uniqueImages.contains(imageName) {
            uniqueImages.append(imageName)
        }
        return Array(uniqueImages.prefix(3))
    }

    @ViewBuilder
    private func featuredImage(
        at index: Int,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let images = featuredActivityImages
        let imageName = images[min(index, images.count - 1)]
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .scaleEffect(
                imageName == "jaipur_collage" ? 1.55 : 1,
                anchor: index == 0 ? .topLeading : .top
            )
            .frame(width: width, height: height)
            .clipped()
    }

    // ── Trip Header ────────────────────────────────────────────────────
    private var heroCard: some View {
        HStack(alignment: .center, spacing: 18) {
            HStack(spacing: 3) {
                featuredImage(at: 0, width: 74, height: 178)

                VStack(spacing: 3) {
                    featuredImage(at: 1, width: 74, height: 87.5)
                    featuredImage(at: 2, width: 74, height: 87.5)
                }
            }
            .frame(width: 151, height: 178)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 9) {
                Text(tripName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("4 collaborators")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.58))

                HStack(spacing: -7) {
                    avatarCircle(name: "K", color: Color(hex: "ec4899"))
                    avatarCircle(name: "S", color: Color(hex: "7c5cfc"))
                    avatarCircle(name: "A", color: Color(hex: "22d3a5"))
                    avatarCircle(name: "R", color: Color(hex: "fbbf24"))
                    Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showingInviteSheet = true } }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
    }

    // ── Note Editor Overlay ────────────────────────────────────────────
    @ViewBuilder
    private func noteEditorOverlay(item: TripItem) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { editingNoteItem = nil }

            VStack(spacing: 16) {
                Text(item.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                TextField("Add note...", text: $editingNoteText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .padding(.horizontal, 16)

                Button(action: { saveNote(for: item) }) {
                    Text("Save")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .padding(20)
            .frame(width: 280)
            .background(Color(white: 0.18))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.5), radius: 20)
            .onAppear { editingNoteText = item.noteText ?? "" }
        }
    }

    // ── Add Items Sheet ────────────────────────────────────────────────
    private var addItemsSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text(alternativeForItem == nil ? "Add items" : "Choose alternative")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    showingAddItemsSheet = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)

            if let original = alternativeForItem {
                HStack(spacing: 9) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(DistrictTheme.accent)
                    Text("Alternative to \(original.title) · same Day \(original.day) time slot")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
            }

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField(
                    "Search for restaurants, events, stores…",
                    text: $addSearchQuery
                )
                .textInputAutocapitalization(.never)
                .submitLabel(.search)

                if !addSearchQuery.isEmpty {
                    Button("Clear search", systemImage: "xmark.circle.fill") {
                        addSearchQuery = ""
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                Color.white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                Text("Add to")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach(availableAddDays, id: \.self) { day in
                        Button {
                            addItemDay = day
                        } label: {
                            if addItemDay == day {
                                Label("Day \(day)", systemImage: "checkmark")
                            } else {
                                Text("Day \(day)")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Day \(addItemDay)")
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DistrictTheme.accent)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(
                        DistrictTheme.accent.opacity(0.13),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(DistrictTheme.accent.opacity(0.40), lineWidth: 0.75)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Divider()
                .overlay(Color.white.opacity(0.08))

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(filteredSearchItems) { searchItem in
                        HStack(spacing: 14) {
                            Image(searchItem.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                            VStack(alignment: .leading, spacing: 5) {
                                Text(searchItem.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(searchItem.subtitle ?? searchItem.category)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 10)

                            Button {
                                selectSearchItem(searchItem)
                            } label: {
                                Image(systemName: alternativeForItem == nil
                                    ? (searchItem.isBookmarked ? "bookmark.fill" : "bookmark")
                                    : "plus.circle.fill")
                                    .font(.system(size: 19))
                                    .foregroundStyle(alternativeForItem != nil
                                        ? DistrictTheme.accent
                                        : (searchItem.isBookmarked ? Color.orange : Color.white.opacity(0.72)))
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(alternativeForItem == nil
                                ? (searchItem.isBookmarked ? "Remove \(searchItem.title)" : "Add \(searchItem.title)")
                                : "Propose \(searchItem.title) as an alternative")
                        }
                        .padding(.leading, 20)
                        .padding(.trailing, 10)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color(white: 0.10).ignoresSafeArea())
    }

    // ── More Actions Sheet ────────────────────────────────────────────
    private var moreActionsSheet: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isEditingTripName = false
                        showingMoreActions = false
                    }
                }

            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Header
                Text("More actions")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)

                // Actions list
                VStack(spacing: 0) {

                    // ── Edit list name ──
                    if isEditingTripName {
                        // Inline rename field
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 24)
                                Text("Rename trip")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                            HStack(spacing: 10) {
                                TextField("Trip name", text: $editingTripName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color(white: 0.2))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.violet.opacity(0.5), lineWidth: 1)
                                    )

                                Button(action: {
                                    if !editingTripName.trimmingCharacters(in: .whitespaces).isEmpty {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            tripName = editingTripName.trimmingCharacters(in: .whitespaces)
                                            isEditingTripName = false
                                            showingMoreActions = false
                                        }
                                    }
                                }) {
                                    Text("Save")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(Color.violet)
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                        }
                    } else {
                        // Normal edit row
                        Button(action: {
                            editingTripName = tripName
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditingTripName = true
                            }
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 24)
                                Text("Edit list name")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .contentShape(Rectangle())
                        }
                    }

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.horizontal, 20)

                    // ── Delete list ──
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingMoreActions = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showDeleteConfirmation = true
                        }
                    }) {
                        HStack(spacing: 14) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("Delete list")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .contentShape(Rectangle())
                    }
                }
            }
            .padding(.bottom, 34) // Safe area bottom
            .background(Color(white: 0.11))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 16
                )
            )
            .transition(.move(edge: .bottom))
        }
        .edgesIgnoringSafeArea(.bottom)
    }

    // ── Invite Collaborators Sheet ────────────────────────────────────
    private var inviteCollaboratorsSheet: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showingInviteSheet = false
                    }
                }

            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Header
                Text("Invite friends to collaborate")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                // ── Sharing as card ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sharing as")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .textCase(.uppercase)
                        .kerning(0.5)

                    HStack(spacing: 12) {
                        Text("K")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color(hex: "ec4899")))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kashish gupta")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Owner")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("Edit")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                }
                .padding(16)
                .background(Color(white: 0.14))
                .cornerRadius(14)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // ── Collaborators section ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("Collaborators")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .textCase(.uppercase)
                        .kerning(0.5)
                        .padding(.horizontal, 4)

                    ForEach(collaborators) { collab in
                        HStack(spacing: 12) {
                            Text(collab.initial)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color(hex: collab.colorHex)))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(collab.name.lowercased())
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(collab.role)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.4))
                            }

                            Spacer()

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    collaborators.removeAll { $0.id == collab.id }
                                }
                            }) {
                                Text("Remove")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.red.opacity(0.9))
                            }
                        }

                        if collab.id != collaborators.last?.id {
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 0.5)
                                .padding(.leading, 56)
                        }
                    }
                }
                .padding(16)
                .background(Color(white: 0.14))
                .cornerRadius(14)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // ── Add collaborator button ──
                Button(action: {}) {
                    Text("Add collaborator")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(white: 0.14))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                // ── Share view-only link ──
                Button(action: {}) {
                    Text("Share a view-only link")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .underline(true, pattern: .dot, color: .white.opacity(0.3))
                }
                .padding(.bottom, 8)
            }
            .padding(.bottom, 34)
            .background(Color(white: 0.11))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 16
                )
            )
            .transition(.move(edge: .bottom))
        }
        .edgesIgnoringSafeArea(.bottom)
    }

    // ── Helpers ────────────────────────────────────────────────────────

    private func filterPill(title: String) -> some View {
        let isSelected = currentFilter == title
        return Button(action: {
            withAnimation { currentFilter = title }
        }) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.white : Color(white: 0.15))
                .cornerRadius(20)
        }
    }

    private func avatarCircle(name: String, color: Color) -> some View {
        Text(name)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(Circle().fill(color))
            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
    }

    private func filteredItems() -> [TripItem] {
        let list: [TripItem]
        switch currentFilter {
        case "Restaurants": list = tripItems.filter { $0.category == "Restaurant" }
        case "Activities":  list = tripItems.filter { $0.category == "Activity" || $0.category == "Event" }
        default:            list = tripItems
        }
        
        if let day = selectedDay {
            return list.filter { $0.day == day }
        } else {
            return list
        }
    }

    private func toggleVote(for id: UUID, type: String) {
        guard let idx = tripItems.firstIndex(where: { $0.id == id }) else { return }
        var item = tripItems[idx]
        let currentMember = YesVoter(
            initial: "K",
            fullName: "Kashish",
            colorHex: "ec4899"
        )

        if item.userVote == type {
            item.userVote = nil
            if type == "up" {
                item.thumbsUpCount = max(0, item.thumbsUpCount - 1)
                item.yesVoters.removeAll { $0.initial == currentMember.initial }
            }
            if type == "down" {
                item.thumbsDownCount = max(0, item.thumbsDownCount - 1)
            }
        } else {
            if let old = item.userVote {
                if old == "up" {
                    item.thumbsUpCount = max(0, item.thumbsUpCount - 1)
                    item.yesVoters.removeAll { $0.initial == currentMember.initial }
                }
                if old == "down" {
                    item.thumbsDownCount = max(0, item.thumbsDownCount - 1)
                }
            }
            item.userVote = type
            if type == "up" {
                item.thumbsUpCount += 1
                if !item.yesVoters.contains(where: { $0.initial == currentMember.initial }) {
                    item.yesVoters.append(currentMember)
                }
            }
            if type == "down" {
                item.thumbsDownCount += 1
                item.yesVoters.removeAll { $0.initial == currentMember.initial }
            }
        }
        item.isConfirmed = item.thumbsUpCount >= 4 && item.thumbsDownCount == 0
        tripItems[idx] = item
    }

    private func saveNote(for item: TripItem) {
        if let idx = tripItems.firstIndex(where: { $0.id == item.id }) {
            var updated = tripItems[idx]
            updated.noteText    = editingNoteText.isEmpty ? nil : editingNoteText
            updated.noteAuthor  = "Kashish"
            updated.noteTimeAgo = "Just now"
            tripItems[idx] = updated
        }
        editingNoteItem = nil
    }

    private func toggleBookmark(for item: AddSearchItem) {
        guard let idx = searchItems.firstIndex(where: { $0.id == item.id }) else { return }
        searchItems[idx].isBookmarked.toggle()
        let bookmarked = searchItems[idx]
        if bookmarked.isBookmarked {
            let targetDate = tripItems.first(where: { $0.day == addItemDay })?.tripDate ?? ""
            let newItem = TripItem(
                title: bookmarked.title,
                category: bookmarked.category,
                location: "Jaipur",
                imageName: bookmarked.imageName,
                ownerName: "K",
                ownerFullName: "Kashish",
                addedTimeAgo: "Just now",
                thumbsUpCount: 0,
                thumbsDownCount: 0,
                userVote: nil,
                duration: "2.0 hours",
                day: addItemDay,
                tripDate: targetDate,
                timeSlot: bookmarked.visitTimeSlot,
                yesVoters: [],
                hasConflict: false,
                isConfirmed: false
            )
            let collaborativeItem = DemoCollaboration.applyingSample(
                to: newItem,
                index: tripItems.count
            )
            tripItems.insert(collaborativeItem, at: 0)
        } else {
            tripItems.removeAll { $0.title == bookmarked.title }
        }
    }

    private func selectSearchItem(_ item: AddSearchItem) {
        guard let original = alternativeForItem else {
            toggleBookmark(for: item)
            return
        }

        guard let originalIndex = tripItems.firstIndex(where: { $0.id == original.id }) else {
            alternativeForItem = nil
            showingAddItemsSheet = false
            return
        }

        var updatedOriginal = tripItems[originalIndex]
        updatedOriginal.hasConflict = true
        updatedOriginal.conflictMessage = "Alternative proposed: \(item.title)"
        tripItems[originalIndex] = updatedOriginal

        let alternative = TripItem(
            title: item.title,
            category: item.category,
            location: original.location,
            imageName: item.imageName,
            ownerName: "K",
            ownerFullName: "Kashish",
            addedTimeAgo: "Alternative · Just now",
            thumbsUpCount: 0,
            thumbsDownCount: 0,
            userVote: nil,
            duration: original.duration,
            day: original.day,
            tripDate: original.tripDate,
            timeSlot: original.timeSlot,
            yesVoters: [],
            hasConflict: true,
            conflictMessage: "Alternative to \(original.title) · group vote required",
            isConfirmed: false
        )

        let collaborativeAlternative = DemoCollaboration.applyingSample(
            to: alternative,
            index: originalIndex + 1
        )

        withAnimation(.snappy) {
            tripItems.insert(
                collaborativeAlternative,
                at: min(originalIndex + 1, tripItems.endIndex)
            )
        }
        alternativeForItem = nil
        showingAddItemsSheet = false
    }

    private func updateVote(_ vote: VoteType) {
        guard var proposal = activeProposal else { return }
        proposal.votes["Kashish"] = vote
        activeProposal = proposal
    }

    private func addComment(_ text: String) {
        guard var proposal = activeProposal else { return }
        proposal.comments.append(Comment(author: "Kashish", text: text))
        activeProposal = proposal
    }

    private func approveProposal() {
        guard let proposal = activeProposal else { return }
        withAnimation {
            if let itinerary = proposal.itineraryItems {
                for rec in itinerary.reversed() {
                    let category = rec.title.contains("Dinner") || rec.title.contains("Dining") ? "Restaurant" : rec.title.contains("Festival") ? "Event" : "Activity"
                    let dayNum = rec.time.contains("Day 1") ? 1 : rec.time.contains("Day 2") ? 2 : rec.time.contains("Day 3") ? 3 : 4
                    let item = TripItem(
                        title: rec.title,
                        category: category,
                        location: "\(rec.distance) | \(rec.title)",
                        imageName: rec.imageName.isEmpty ? "jaipur_collage" : rec.imageName,
                        ownerName: "S",
                        ownerFullName: "Saurabh",
                        addedTimeAgo: "Just now",
                        thumbsUpCount: 1,
                        thumbsDownCount: 0,
                        userVote: nil,
                        duration: rec.title.contains("Dinner") ? "3.0 hours" : rec.title.contains("Festival") ? "5.5 hours" : "2.0 hours",
                        day: dayNum,
                        tripDate: dayNum == 1 ? "Fri, 18 Jul" : dayNum == 2 ? "Sat, 19 Jul" : "Sun, 20 Jul",
                        timeSlot: "",
                        yesVoters: [YesVoter(initial: "S", fullName: "Saurabh", colorHex: "7c5cfc")],
                        hasConflict: false,
                        isConfirmed: false
                    )
                    tripItems.insert(item, at: 0)
                }
            } else if proposal.votes.count >= 4 && proposal.alternativeSpaOption != nil {
                let pottery = TripItem(
                    title: "Pottery Workshop",
                    category: "Activity",
                    location: "3 km | Local Studio",
                    imageName: "jaipur_collage",
                    ownerName: "S",
                    ownerFullName: "Saurabh",
                    addedTimeAgo: "Just now",
                    thumbsUpCount: 3,
                    thumbsDownCount: 0,
                    userVote: "up",
                    duration: "2.0 hours",
                    day: 2,
                    tripDate: "Sat, 19 Jul",
                    timeSlot: "2:00 PM – 4:00 PM",
                    yesVoters: [voterS, voterK, voterA],
                    hasConflict: false,
                    isConfirmed: true
                )
                let spa = TripItem(
                    title: "Traditional Spa Session",
                    category: "Activity",
                    location: "2.8 km | Ayur-Veda Spa",
                    imageName: "tonino",
                    ownerName: "A",
                    ownerFullName: "Arjun",
                    addedTimeAgo: "Just now",
                    thumbsUpCount: 2,
                    thumbsDownCount: 0,
                    userVote: nil,
                    duration: "2.5 hours",
                    day: 2,
                    tripDate: "Sat, 19 Jul",
                    timeSlot: "2:00 PM – 4:30 PM",
                    yesVoters: [voterA, voterR],
                    hasConflict: false,
                    isConfirmed: false
                )
                tripItems.insert(spa, at: 0)
                tripItems.insert(pottery, at: 0)
            } else {
                let dayNum = proposal.proposedTime.contains("Day 1") ? 1 : proposal.proposedTime.contains("Day 2") ? 2 : proposal.proposedTime.contains("Day 3") ? 3 : 1
                let item = TripItem(
                    title: proposal.title,
                    category: "Activity",
                    location: "\(proposal.distance) | \(proposal.title)",
                    imageName: proposal.title.contains("Tonino") ? "tonino" : "jaipur_collage",
                    ownerName: "S",
                    ownerFullName: "Saurabh",
                    addedTimeAgo: "Just now",
                    thumbsUpCount: 1,
                    thumbsDownCount: 0,
                    userVote: nil,
                    duration: "2.0 hours",
                    day: dayNum,
                    tripDate: dayNum == 1 ? "Fri, 18 Jul" : dayNum == 2 ? "Sat, 19 Jul" : "Sun, 20 Jul",
                    timeSlot: "",
                    yesVoters: [YesVoter(initial: "S", fullName: "Saurabh", colorHex: "7c5cfc")],
                    hasConflict: false,
                    isConfirmed: false
                )
                tripItems.insert(item, at: 0)
            }
            activeProposal = nil
        }
    }

    // ── Calendar View ──────────────────────────────────────────────────
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
//            // Header
//            HStack(spacing: 6) {
//                Image(systemName: "calendar")
//                    .foregroundColor(.white)
//                    .font(.system(size: 14, weight: .bold))
//                Text("Calendar")
//                    .font(.system(size: 14, weight: .bold))
//                    .foregroundColor(.white)
//            }
//            .padding(.horizontal, 4)
            
            // Pills Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    calendarPill(dayNum: nil, title: "All", subtitle: "Full trip")
                    calendarPill(dayNum: 1, title: "Day 1", subtitle: "Fri, 18 Jul")
                    calendarPill(dayNum: 2, title: "Day 2", subtitle: "Sat, 19 Jul")
                    calendarPill(dayNum: 3, title: "Day 3", subtitle: "Sun, 20 Jul")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func calendarPill(dayNum: Int?, title: String, subtitle: String) -> some View {
        let isSelected = selectedDay == dayNum
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDay = dayNum
            }
        }) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(isSelected ? .black : .white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .black.opacity(0.7) : .white.opacity(0.4))
            }
            .frame(width: 84, height: 48)
            .background(isSelected ? Color.white : Color(white: 0.12))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: - Complete itinerary

private struct CompleteItinerarySummaryCard: View {
    let dayCount: Int
    let itemCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle.portrait.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.violet, in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Complete itinerary")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(dayCount) days · \(itemCount) timed plans")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.42))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(14)
            .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 17))
            .overlay(
                RoundedRectangle(cornerRadius: 17)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CompleteItineraryView: View {
    let tripName: String
    @Binding var items: [TripItem]
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var itemBeingEdited: TripItem?
    @State private var itemPendingRemoval: TripItem?

    private var days: [Int] {
        Array(Set(items.map(\.day))).sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(tripName)
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(.white)
                        Text("\(days.count) days · \(items.count) plans")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                    }

                    ForEach(days, id: \.self) { day in
                        itineraryDay(day)
                    }
                }
                .padding(18)
                .padding(.bottom, 24)
            }
            .background(Color.black)
            .navigationTitle("Complete itinerary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "Done" : "Edit") {
                        withAnimation(.snappy) {
                            isEditing.toggle()
                        }
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.violet)
        .sheet(item: $itemBeingEdited) { item in
            ItineraryItemEditor(item: item) { updatedItem in
                save(updatedItem)
            }
        }
        .alert(
            "Remove this plan?",
            isPresented: Binding(
                get: { itemPendingRemoval != nil },
                set: { if !$0 { itemPendingRemoval = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                itemPendingRemoval = nil
            }
            Button("Remove", role: .destructive) {
                if let itemPendingRemoval {
                    withAnimation(.snappy) {
                        items.removeAll { $0.id == itemPendingRemoval.id }
                    }
                }
                itemPendingRemoval = nil
            }
        } message: {
            Text(itemPendingRemoval?.title ?? "This plan will be removed from the collaborative itinerary.")
        }
    }

    private func itineraryDay(_ day: Int) -> some View {
        let dayItems = items
            .filter { $0.day == day }
            .sorted { startMinutes($0.timeSlot) < startMinutes($1.timeSlot) }

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("Day \(day)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text(dayItems.first?.tripDate ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("\(dayItems.count) plans")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }

            VStack(spacing: 0) {
                ForEach(Array(dayItems.enumerated()), id: \.element.id) { index, item in
                    ItineraryTimelineRow(
                        item: item,
                        isLast: index == dayItems.count - 1,
                        isEditing: isEditing,
                        onEdit: { itemBeingEdited = item },
                        onRemove: { itemPendingRemoval = item }
                    )
                }
            }
            .padding(14)
            .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func save(_ updatedItem: TripItem) {
        guard let index = items.firstIndex(where: { $0.id == updatedItem.id }) else {
            return
        }

        withAnimation(.snappy) {
            items[index] = updatedItem
        }
    }

    private func startMinutes(_ value: String) -> Int {
        let start = value.components(separatedBy: "–").first ?? value
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        guard let date = formatter.date(from: start.trimmingCharacters(in: .whitespaces)) else {
            return Int.max
        }
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

private struct ItineraryTimelineRow: View {
    let item: TripItem
    let isLast: Bool
    let isEditing: Bool
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text(startTime)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.42))
                .frame(width: 58, alignment: .leading)

            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.violet, in: Circle())

                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 1, height: 60)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                Text(item.timeSlot)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Label(item.location, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.38))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isEditing {
                VStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 31, height: 31)
                            .background(Color.violet, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit \(item.title)")

                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red)
                            .frame(width: 31, height: 31)
                            .background(Color.red.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(item.title)")
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(minHeight: isLast ? 54 : 90, alignment: .top)
    }

    private var startTime: String {
        item.timeSlot.components(separatedBy: "–").first?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }

    private var symbol: String {
        switch item.category {
        case "Restaurant": return "fork.knife"
        case "Event": return "ticket.fill"
        default: return "figure.walk"
        }
    }
}

private struct ItineraryItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: TripItem
    let onSave: (TripItem) -> Void

    private let categories = ["Activity", "Restaurant", "Event"]

    init(item: TripItem, onSave: @escaping (TripItem) -> Void) {
        _item = State(initialValue: item)
        self.onSave = onSave
    }

    private var canSave: Bool {
        !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !item.timeSlot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    TextField("Plan title", text: $item.title, axis: .vertical)
                        .lineLimit(1...3)

                    Picker("Category", selection: $item.category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }

                Section {
                    Stepper(value: $item.day, in: 1...10) {
                        LabeledContent("Trip day", value: "Day \(item.day)")
                    }

                    TextField("Date, for example Sat, 18 Jul", text: $item.tripDate)
                        .textInputAutocapitalization(.words)

                    TextField("Time, for example 4:00 PM – 6:00 PM", text: $item.timeSlot)
                        .textInputAutocapitalization(.characters)
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Changing the day or time automatically places this plan in the correct timeline position.")
                }

                Section("Place") {
                    TextField("Venue or location", text: $item.location, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Duration", text: $item.duration)
                }

                Section {
                    Toggle("Confirmed plan", isOn: $item.isConfirmed)
                } footer: {
                    Text("Turn this off when the group still needs to vote before booking.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.violet)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct FloatingAIButtonStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(DistrictTheme.accent)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(DistrictTheme.accent)
        }
    }
}

private let voterS = YesVoter(initial: "S", fullName: "Saurabh", colorHex: "7c5cfc")
private let voterK = YesVoter(initial: "K", fullName: "Kashish", colorHex: "ec4899")
private let voterA = YesVoter(initial: "A", fullName: "Arjun",   colorHex: "22d3a5")
private let voterR = YesVoter(initial: "R", fullName: "Riya",    colorHex: "fbbf24")
