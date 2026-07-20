import SwiftUI

public struct ContentView: View {
    @State private var hotlists: [HotlistCollection] = HotlistCollection.samples
    @State private var workspaceItems: [UUID: [TripItem]] = [:]
    @State private var selectedHotlistID: UUID?
    @State private var tripItems: [TripItem] = []
    @State private var currentFilter: String = "All"
    @State private var showAIAssistant: Bool = false
    @State private var tripName: String = "Jaipur"
    @State private var activeProposal: Proposal? = nil

    public init() {}

    public var body: some View {
        Group {
            if selectedHotlistID == nil {
                HotlistsHomeView(
                    hotlists: hotlists,
                    itemCounts: hotlistItemCounts,
                    onSelect: openHotlist,
                    onCreate: createHotlist
                )
            } else {
                TripFeedView(
                    tripItems: $tripItems,
                    activeProposal: $activeProposal,
                    currentFilter: $currentFilter,
                    showAIAssistant: $showAIAssistant,
                    tripName: $tripName,
                    onBack: closeWorkspace
                )
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAIAssistant) {
            AIAssistantView(
                tripName: tripName,
                tripItems: tripItems
            ) { destination, generatedItems in
                withAnimation(.easeInOut) {
                    tripName = destination
                    tripItems = generatedItems
                }
                showAIAssistant = false
            }
        }
        .onChange(of: activeProposal != nil) { _, isProposed in
            if isProposed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    simulateFriendVotes()
                }
            }
        }
    }

    private var hotlistItemCounts: [UUID: Int] {
        var counts = workspaceItems.mapValues(\.count)
        if let selectedHotlistID {
            counts[selectedHotlistID] = tripItems.count
        }
        return counts
    }

    private func openHotlist(_ hotlist: HotlistCollection) {
        activeProposal = nil
        currentFilter = "All"
        showAIAssistant = false
        tripName = hotlist.name
        tripItems = workspaceItems[hotlist.id] ?? []
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedHotlistID = hotlist.id
        }
    }

    private func createHotlist(
        name: String,
        artwork: HotlistCollection.Artwork
    ) {
        let hotlist = HotlistCollection(name: name, artwork: artwork)
        hotlists.insert(hotlist, at: 0)
        workspaceItems[hotlist.id] = []
        openHotlist(hotlist)
    }

    private func closeWorkspace() {
        guard let selectedHotlistID else { return }
        workspaceItems[selectedHotlistID] = tripItems
        showAIAssistant = false
        activeProposal = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            self.selectedHotlistID = nil
        }
    }

    private func simulateFriendVotes() {
        guard var proposal = activeProposal else { return }

        withAnimation {
            proposal.votes["Priya"] = .interested
            proposal.votes["Aman"] = .notInterested
            proposal.votes["Riya"] = .notInterested
            proposal.comments.append(Comment(author: "Priya", text: "I would prefer a spa during this time."))
            proposal.comments.append(Comment(author: "Aman", text: "Me too, spa sounds much better!"))
            activeProposal = proposal
        }
    }
}
