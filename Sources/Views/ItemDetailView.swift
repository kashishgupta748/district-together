import SwiftUI

public struct ItemDetailView: View {
    public let item: TripItem
    public let onDismiss: () -> Void
    @State private var isBookmarked = true
    
    public var body: some View {
        ZStack(alignment: .top) {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Hero Image Background
            GeometryReader { geo in
                Image(item.imageName.isEmpty ? "water_park" : item.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height * 0.45)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [.black.opacity(0.8), .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120),
                        alignment: .top
                    )
            }
            .edgesIgnoringSafeArea(.top)
            
            // Content Sheet
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Spacer to push content down
                    Color.clear.frame(height: UIScreen.main.bounds.height * 0.35 - 50) // Adjust height as needed
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Drag handle
                        HStack {
                            Spacer()
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 40, height: 4)
                            Spacer()
                        }
                        .padding(.top, 12)
                        
                        // Glowing sub-banner
                        Text("SPLASHES OF FUN MAKE YOUR SUMMER...")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.violet)
                            .padding(.top, 8)
                            .kerning(1.2)
                        
                        // Title
                        Text("\(item.title) , Delhi")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Location & Distance
                        VStack(alignment: .center, spacing: 8) {
                            HStack {
                                Spacer()
                                Text("Kapas Hera, Delhi | 16.8 km away")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.7))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                            }
                            
                            HStack {
                                Spacer()
                                Text("18 Jul – 2 Aug • 11:00 AM – 6:00 PM")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: "22d3a5"))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "22d3a5"))
                                Spacer()
                            }
                            
                            // Stats Row
                            HStack(spacing: 8) {
                                Spacer()
                                Image(systemName: "person.2")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("7.7k+ attended")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                
                                Text("|")
                                    .foregroundColor(.white.opacity(0.3))
                                    .padding(.horizontal, 4)
                                
                                Text("⭐ 4.2 • Google")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                Text("16.4k ratings")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                                    .underline()
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                        
                        // Gallery Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Discover the park")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.top, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    Image("water_park") // Placeholder main image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 220, height: 280)
                                        .cornerRadius(16)
                                        .clipped()
                                    
                                    VStack(spacing: 12) {
                                        Image("jaipur_collage") // Placeholder secondary image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 140, height: 134)
                                            .cornerRadius(16)
                                            .clipped()
                                        
                                        Image("tonino") // Placeholder tertiary image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 140, height: 134)
                                            .cornerRadius(16)
                                            .clipped()
                                    }
                                }
                            }
                        }
                        
                        // Bottom padding for sticky bar
                        Color.clear.frame(height: 180)
                    }
                    .padding(.horizontal, 20)
                    .background(Color(white: 0.1).edgesIgnoringSafeArea(.bottom))
                    .cornerRadius(24, corners: [.topLeft, .topRight])
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            
            // Fixed Top Bar
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .modifier(NativeHeroButtonStyle())
                .accessibilityLabel("Back")

                Spacer()
                
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.snappy) {
                            isBookmarked.toggle()
                        }
                    } label: {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .modifier(NativeHeroButtonStyle())
                    .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark")

                    ShareLink(item: "\(item.title) • \(item.location)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .modifier(NativeHeroButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Sticky Bottom Action Bar
            VStack {
                Spacer()
                VStack(spacing: 0) {
                    // Violet Offer Banner
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-45))
                        Text("Flat ₹150 OFF")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("3 offers")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.violet)
                    .cornerRadius(24, corners: [.topLeft, .topRight])
                    
                    // Main Action Row
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("Price match guarantee")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(hex: "22d3a5"))
                                Image(systemName: "info.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Text("From ₹1,000")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Text("Inc of taxes")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        
                        Button(action: {}) {
                            Text("Book tickets")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 24)
                                .background(Color.white)
                                .cornerRadius(24)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(Color(white: 0.12))
                }
                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: -10)
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .navigationBarHidden(true)
    }
}

private struct NativeHeroButtonStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            content
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(.white)
        }
    }
}

// Extension to help round specific corners (if not already defined)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
