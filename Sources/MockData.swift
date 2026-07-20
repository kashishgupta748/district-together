import Foundation

// Convenience helpers for yes-voter presets
private let voterK = YesVoter(initial: "K", fullName: "Kashish", colorHex: "ec4899")
private let voterS = YesVoter(initial: "S", fullName: "Saurabh", colorHex: "7c5cfc")
private let voterA = YesVoter(initial: "A", fullName: "Arjun",   colorHex: "22d3a5")
private let voterR = YesVoter(initial: "R", fullName: "Riya",    colorHex: "fbbf24")

public struct MockData {
    
    public static var initialTripItems: [TripItem] = [

        // ── DAY 1 ─────────────────────────────────────────────────────

        TripItem(
            title: "Amber Fort Exploration",
            category: "Activity",
            location: "11 km from Marriott",
            imageName: "jaipur_collage",
            ownerName: "S",
            ownerFullName: "Saurabh",
            addedTimeAgo: "Just now",
            thumbsUpCount: 3,
            thumbsDownCount: 1,
            userVote: "up",
            duration: "2.0 hours",
            day: 1,
            tripDate: "Fri, 18 Jul",
            timeSlot: "11:30 AM – 2:00 PM",
            yesVoters: [voterS, voterK, voterA],
            hasConflict: false,
            isConfirmed: false
        ),

        TripItem(
            title: "Hawa Mahal Palace",
            category: "Activity",
            location: "2.5 km from Marriott",
            imageName: "jaipur_collage",
            ownerName: "K",
            ownerFullName: "Kashish",
            addedTimeAgo: "1h ago",
            thumbsUpCount: 4,
            thumbsDownCount: 0,
            userVote: "up",
            duration: "1.5 hours",
            day: 1,
            tripDate: "Fri, 18 Jul",
            timeSlot: "3:00 PM – 4:30 PM",
            yesVoters: [voterK, voterS, voterA, voterR],
            hasConflict: false,
            isConfirmed: true
        ),

        TripItem(
            title: "Chokhi Dhani Dinner",
            category: "Restaurant",
            location: "4.5 km from Marriott",
            imageName: "tonino",
            ownerName: "S",
            ownerFullName: "Saurabh",
            addedTimeAgo: "28m ago",
            thumbsUpCount: 2,
            thumbsDownCount: 2,
            userVote: "up",
            duration: "3.0 hours",
            day: 1,
            tripDate: "Fri, 18 Jul",
            timeSlot: "7:00 PM – 10:00 PM",
            yesVoters: [voterS, voterK],
            hasConflict: true,
            conflictMessage: "Riya prefers an earlier dinner · See alternatives",
            isConfirmed: false
        ),

        // ── DAY 2 ─────────────────────────────────────────────────────

        TripItem(
            title: "Nahargarh Sunrise Trek",
            category: "Activity",
            location: "6.2 km from Marriott",
            imageName: "jaipur_collage",
            ownerName: "A",
            ownerFullName: "Arjun",
            addedTimeAgo: "3h ago",
            thumbsUpCount: 2,
            thumbsDownCount: 1,
            userVote: nil,
            duration: "2.5 hours",
            day: 2,
            tripDate: "Sat, 19 Jul",
            timeSlot: "5:30 AM – 8:00 AM",
            yesVoters: [voterA, voterS],
            hasConflict: false,
            isConfirmed: false
        ),

        TripItem(
            title: "Blue Pottery Workshop",
            category: "Activity",
            location: "3.1 km from Marriott",
            imageName: "jaipur_collage",
            ownerName: "R",
            ownerFullName: "Riya",
            addedTimeAgo: "5h ago",
            thumbsUpCount: 4,
            thumbsDownCount: 0,
            userVote: "up",
            duration: "2.5 hours",
            day: 2,
            tripDate: "Sat, 19 Jul",
            timeSlot: "10:00 AM – 12:30 PM",
            yesVoters: [voterR, voterK, voterA, voterS],
            hasConflict: false,
            isConfirmed: true
        ),

        TripItem(
            title: "MikeNmix by Prats",
            category: "Event",
            location: "2.5 km | Jaipur Club Lounge",
            imageName: "",
            ownerName: "S",
            ownerFullName: "Saurabh",
            addedTimeAgo: "2h ago",
            thumbsUpCount: 2,
            thumbsDownCount: 0,
            userVote: "up",
            duration: "3.0 hours",
            day: 2,
            tripDate: "Sat, 19 Jul",
            timeSlot: "8:30 PM – 11:00 PM",
            yesVoters: [voterS, voterR],
            hasConflict: false,
            isConfirmed: false
        ),

        // ── DAY 3 ─────────────────────────────────────────────────────

        TripItem(
            title: "City Palace Tour",
            category: "Activity",
            location: "1.8 km from Marriott",
            imageName: "jaipur_collage",
            ownerName: "K",
            ownerFullName: "Kashish",
            addedTimeAgo: "Yesterday",
            thumbsUpCount: 4,
            thumbsDownCount: 0,
            userVote: "up",
            duration: "3.0 hours",
            day: 3,
            tripDate: "Sun, 20 Jul",
            timeSlot: "10:00 AM – 1:00 PM",
            yesVoters: [voterK, voterS, voterA, voterR],
            hasConflict: false,
            isConfirmed: true
        ),

        TripItem(
            title: "Tonino · Farewell Dinner",
            category: "Restaurant",
            location: "4.4 ★  3.7km, MG Road, Jaipur",
            imageName: "tonino",
            ownerName: "K",
            ownerFullName: "Kashish",
            addedTimeAgo: "28m ago",
            thumbsUpCount: 2,
            thumbsDownCount: 0,
            userVote: "up",
            duration: "2.0 hours",
            day: 3,
            tripDate: "Sun, 20 Jul",
            timeSlot: "7:30 PM – 10:00 PM",
            yesVoters: [voterK, voterR],
            hasConflict: false,
            isConfirmed: false
        )
    ]
    
    public static var recommendations: [AIRecommendation] = [
        AIRecommendation(
            title: "Pottery Workshop",
            price: "₹1,200 per person",
            time: "Day 2, 2:00 PM - 4:00 PM",
            distance: "3 km from hotel",
            description: "A hands-on traditional clay crafting session guided by master local artisans. Excellent creative and relaxing experience.",
            matchReason: "Fits itinerary perfectly: Free time is available before dinner.",
            slots: 6,
            imageName: "jaipur_collage"
        ),
        AIRecommendation(
            title: "Traditional Spa Session",
            price: "₹2,200 per person",
            time: "Day 2, 2:00 PM - 4:30 PM",
            distance: "2.8 km from hotel",
            description: "Relaxing ayurvedic full-body massage and steam therapy. Great for winding down after sightseeing.",
            matchReason: "Fits itinerary: In the same area as the proposed pottery workshop.",
            slots: 4,
            imageName: "tonino"
        ),
        AIRecommendation(
            title: "Local Heritage Art Walk",
            price: "₹500 per person",
            time: "Day 2, 3:00 PM - 5:00 PM",
            distance: "1.5 km from hotel",
            description: "Guided street-art and traditional block-printing gallery tour in the old quarters of the city.",
            matchReason: "Fits budget & style: A highly budget-friendly cultural option.",
            slots: 10,
            imageName: "jaipur_collage"
        ),
        AIRecommendation(
            title: "Amber Fort Exploration",
            price: "₹500 entry fee",
            time: "Day 1, 11:30 AM - 2:00 PM",
            distance: "11 km from Marriott",
            description: "Explore the majestic hilltop fort with spectacular Mughal-Rajput architecture and mirroring lakes.",
            matchReason: "Fits Day 1 morning: Easily accessible after your 10:00 AM hotel arrival.",
            slots: 6,
            imageName: "jaipur_collage"
        ),
        AIRecommendation(
            title: "Chokhi Dhani Dinner",
            price: "₹900 per person",
            time: "Day 1, 7:00 PM - 10:00 PM",
            distance: "4.5 km from Marriott",
            description: "Traditional Rajasthani dinner served in organic leaf plates, plus folk dancing and heritage cultural displays.",
            matchReason: "Authentic dining request: Highly rated traditional dining experience.",
            slots: 6,
            imageName: "tonino"
        ),
        AIRecommendation(
            title: "Jaipur Music Festival",
            price: "₹3,500 ticket",
            time: "Day 3, 5:00 PM - 10:30 PM",
            distance: "6 km from Marriott",
            description: "Premium open-air live concert stage featuring popular folk-fusion and indie artists.",
            matchReason: "Fits concert request: Day 3 main event matching your booking.",
            slots: 6,
            imageName: ""
        ),
        AIRecommendation(
            title: "Peshawri Fine Dining",
            price: "₹2,500 per person",
            time: "Day 4, 8:00 PM - 10:30 PM",
            distance: "7.2 km from Marriott",
            description: "Luxury fine dining showcasing world-famous clay-oven tandoori breads, kebabs, and slow-cooked dal bukhara.",
            matchReason: "Fits fine dining request: Premium culinary experience at ITC Rajputana.",
            slots: 6,
            imageName: "tonino"
        )
    ]
}
