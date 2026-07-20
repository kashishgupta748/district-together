import SwiftUI


public struct ProposalCard: View {
    public let proposal: Proposal
    public let currentUser: String // "K" or others
    public let onVote: (VoteType) -> Void
    public let onApprove: () -> Void
    public let onAddComment: (String) -> Void
    
    @State private var commentText: String = ""
    
    public init(proposal: Proposal, currentUser: String, onVote: @escaping (VoteType) -> Void, onApprove: @escaping () -> Void, onAddComment: @escaping (String) -> Void) {
        self.proposal = proposal
        self.currentUser = currentUser
        self.onVote = onVote
        self.onApprove = onApprove
        self.onAddComment = onAddComment
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("PROPOSAL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.violet)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.violet.opacity(0.15))
                            .cornerRadius(4)
                        
                        Text("Suggested by \(proposal.suggestedBy)")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Text(proposal.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                
                // Status icon
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 20))
            }
            
            // Details table OR Timeline preview for entire itinerary
            if let itinerary = proposal.itineraryItems {
                VStack(alignment: .leading, spacing: 8) {
                    Text("5-Day Plan Highlights")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 2)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(itinerary) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    // Day Badge
                                    Text(item.time.contains("Day ") ? String(item.time.prefix(5)) : "Day Activity")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.violet)
                                        .cornerRadius(4)
                                    
                                    Text(item.title)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Text(item.price)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.violet)
                                        .lineLimit(1)
                                    
                                    Text(item.distance)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.5))
                                        .lineLimit(1)
                                }
                                .padding(10)
                                .frame(width: 155, height: 95)
                                .background(Color(white: 0.06))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 2)
                    }
                }
                .padding(10)
                .background(Color(white: 0.08))
                .cornerRadius(14)
            } else {
                // Details table (for a single activity)
                VStack(alignment: .leading, spacing: 6) {
                    detailRow(label: "Proposed time:", value: proposal.proposedTime)
                    detailRow(label: "Price:", value: proposal.price)
                    detailRow(label: "Distance:", value: proposal.distance)
                    detailRow(label: "Reason:", value: proposal.reason)
                    detailRow(label: "Availability:", value: proposal.slots)
                    detailRow(label: "Decision by:", value: proposal.decisionDeadline)
                }
                .padding(10)
                .background(Color(white: 0.08))
                .cornerRadius(10)
            }
            
            // Polling responses & summary
            if currentUser != "K" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Poll")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Active options grid (now simplified to exactly two options: Interested and Not interested)
                    HStack(spacing: 12) {
                        pollButton(type: .interested)
                        pollButton(type: .notInterested)
                    }
                }
            }
            
            // Votes Breakdown
            VStack(alignment: .leading, spacing: 6) {
                votesBreakdownRow(label: "Interested:", members: getMembersForVote(.interested), color: .green)
                votesBreakdownRow(label: "Not interested:", members: getMembersForVote(.notInterested), color: .red)
            }
            .padding(.top, 4)
            
            // Trip Note (replacing old Comments & Discussion clutter)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .foregroundColor(.violet)
                        .font(.system(size: 11, weight: .bold))
                    Text("Note")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.violet)
                }
                
                Text(proposal.itineraryItems != nil 
                    ? "Day 3 includes your music festival concert. Traditional Rajasthani dining and fine dining options are pre-booked. All reservations are secured within the ₹25,000 / person group budget."
                    : "Pottery workshop is pre-booked. Group A will visit local studio, Group B will head to spa. Shared transport departs Marriott hotel lobby at 1:45 PM.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(2)
            }
            .padding(10)
            .background(Color(white: 0.08))
            .cornerRadius(10)
            
            // AI Smart adjustment suggestion
            if let _ = proposal.alternativeSpaOption, proposal.votes.count >= 4 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.violet)
                        Text("District AI Recommendation")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.violet)
                    }
                    
                    Text(proposal.itineraryItems != nil 
                        ? "Since Priya is interested but Aman and Riya are not interested, District AI recommends adopting parallel slots for Spa/Pottery on Day 2, and reuniting for Peshawri Fine Dining."
                        : "3 members are interested in pottery, while 2 members are not interested. Both activities are available within 2 km of each other. District can create parallel plans from 2:00 PM to 4:00 PM and reunite the group for dinner at 6:00 PM.")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .lineSpacing(2)
                }
                .padding(10)
                .background(Color.violet.opacity(0.15))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.violet.opacity(0.4), lineWidth: 1)
                )
            }
            
            // Organizer controls
            if currentUser == "K" {
                Button(action: onApprove) {
                    HStack {
                        Spacer()
                        Image(systemName: proposal.itineraryItems != nil ? "checkmark.seal.fill" : (proposal.votes.count >= 4 ? "arrow.branch" : "checkmark.circle.fill"))
                        Text(proposal.itineraryItems != nil ? "Approve & Add Entire Itinerary to Feed" : (proposal.votes.count >= 4 ? "Approve Split Plan" : "Approve & Add to Itinerary"))
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.black)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(10)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(white: 0.12))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }
    
    private func pollButton(type: VoteType) -> some View {
        let isSelected = proposal.votes["Kashish"] == type
        return Button(action: { onVote(type) }) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 10))
                Text(type.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .black : .white)
            .background(isSelected ? Color.white : Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func votesBreakdownRow(label: String, members: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 110, alignment: .leading)
            
            if members.isEmpty {
                Text("None")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.white.opacity(0.2))
            } else {
                Text(members)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }
            Spacer()
        }
    }
    
    private func getMembersForVote(_ type: VoteType) -> String {
        var names: [String] = []
        for (member, vote) in proposal.votes {
            if vote == type {
                if member == "Kashish" {
                    names.append("You (K)")
                } else {
                    names.append(member)
                }
            }
        }
        return names.joined(separator: ", ")
    }
}
