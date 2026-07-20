import SwiftUI

struct HotlistCollection: Identifiable, Hashable {
    enum Artwork: String, Hashable {
        case dateNight
        case nextPlan
        case weekend
        case bucketList
        case repeatSpots
        case jaipur
    }

    let id: UUID
    var name: String
    let artwork: Artwork

    init(id: UUID = UUID(), name: String, artwork: Artwork) {
        self.id = id
        self.name = name
        self.artwork = artwork
    }

    static let samples: [HotlistCollection] = [
        HotlistCollection(name: "💞 Date night", artwork: .dateNight),
        HotlistCollection(name: "🚗 Next plan", artwork: .nextPlan),
        HotlistCollection(name: "🌟 Weekend picks", artwork: .weekend),
        HotlistCollection(name: "📌 Bucket list", artwork: .bucketList),
        HotlistCollection(name: "💖 Repeat spots", artwork: .repeatSpots),
        HotlistCollection(name: "🥂 Special day", artwork: .jaipur),
        HotlistCollection(name: "🎬 Movie nights", artwork: .weekend),
        HotlistCollection(name: "🧡 Jaipur", artwork: .jaipur)
    ]
}

struct HotlistsHomeView: View {
    let hotlists: [HotlistCollection]
    let itemCounts: [UUID: Int]
    let onSelect: (HotlistCollection) -> Void
    let onCreate: (String, HotlistCollection.Artwork) -> Void

    @State private var isPresentingCreateSheet = false
    @State private var isHeroVisible = true
    @State private var isHeroPaused = false
    @State private var isHeroMuted = true
    @State private var showsEveryHotlist = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var visibleHotlists: [HotlistCollection] {
        showsEveryHotlist ? hotlists : Array(hotlists.prefix(6))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                hotlistsHeader

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        if isHeroVisible {
                            HotlistsHeroCard(
                                isPaused: $isHeroPaused,
                                isMuted: $isHeroMuted,
                                closeAction: {
                                    withAnimation(.snappy) { isHeroVisible = false }
                                }
                            )
                        }

                        HStack(alignment: .center) {
                            Text("All you’ve got")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)

                            Spacer()

                            Button {
                                withAnimation(.snappy) {
                                    showsEveryHotlist.toggle()
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    Text(showsEveryHotlist ? "Show less" : "See all (\(hotlists.count))")
                                    Image(systemName: showsEveryHotlist ? "chevron.up" : "chevron.right")
                                        .font(.caption.bold())
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.84))
                            }
                            .buttonStyle(.plain)
                        }

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 25) {
                            ForEach(visibleHotlists) { hotlist in
                                Button {
                                    onSelect(hotlist)
                                } label: {
                                    HotlistCollectionCard(
                                        hotlist: hotlist,
                                        itemCount: itemCounts[hotlist.id, default: 0]
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens the collaborative workspace")
                            }
                        }
                    }
                    .padding(.horizontal, 17)
                    .padding(.top, 6)
                    .padding(.bottom, 110)
                }
            }

            createHotlistButton
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isPresentingCreateSheet) {
            CreateHotlistSheet { name, artwork in
                isPresentingCreateSheet = false
                onCreate(name, artwork)
            }
            .presentationDetents([.height(322)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(26)
            .presentationBackground(Color(red: 0.105, green: 0.105, blue: 0.115))
        }
    }

    private var hotlistsHeader: some View {
        HStack(spacing: 12) {
            Button {
                // This is the first prototype screen; the control matches District's parent navigation.
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Text("Hotlists")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Button {
                isPresentingCreateSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                    Text("Create new")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Color.black.opacity(0.19), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 68)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.27, blue: 0.12),
                    Color(red: 0.56, green: 0.01, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    private var createHotlistButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 18)

            Button {
                isPresentingCreateSheet = true
            } label: {
                Text("Create Hotlist")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .buttonStyle(.plain)
            .background(.white, in: Capsule())
            .padding(.horizontal, 17)
            .padding(.bottom, 10)
            .background(Color.black.opacity(0.94))
        }
    }
}

private struct HotlistsHeroCard: View {
    @Binding var isPaused: Bool
    @Binding var isMuted: Bool
    let closeAction: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.03, blue: 0.35),
                    Color(red: 0.27, green: 0.05, blue: 0.86),
                    Color(red: 0.22, green: 0.02, blue: 0.64)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HotlistsHeroPattern()
                .opacity(isPaused ? 0.20 : 0.40)

            VStack(spacing: 0) {
                Text("district")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .italic()
                    .tracking(-3)
                Text("TOGETHER")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(6)
                    .padding(.leading, 6)
            }
            .foregroundStyle(.white)

            VStack {
                HStack {
                    Spacer()
                    Button("Hide", systemImage: "xmark", action: closeAction)
                        .labelStyle(.iconOnly)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                        .accessibilityLabel("Hide introduction")
                }

                Spacer()

                HStack(spacing: 10) {
                    Spacer()

                    HeroControlButton(
                        title: isMuted ? "Unmute" : "Mute",
                        symbol: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
                    ) {
                        isMuted.toggle()
                    }

                    HeroControlButton(
                        title: isPaused ? "Play" : "Pause",
                        symbol: isPaused ? "play.fill" : "pause.fill"
                    ) {
                        isPaused.toggle()
                    }
                }
            }
            .padding(12)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HotlistsHeroPattern: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: proxy.size.width * 0.21, height: proxy.size.height * 1.25)
                    .rotationEffect(.degrees(17))
                    .offset(x: -proxy.size.width * 0.36)

                Capsule()
                    .fill(Color.black.opacity(0.23))
                    .frame(width: proxy.size.width * 0.17, height: proxy.size.height * 1.2)
                    .rotationEffect(.degrees(16))
                    .offset(x: proxy.size.width * 0.37)

                Circle()
                    .fill(Color.purple.opacity(0.32))
                    .frame(width: proxy.size.width * 0.72)
                    .offset(x: proxy.size.width * 0.38, y: -proxy.size.height * 0.35)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct HeroControlButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: symbol, action: action)
            .labelStyle(.iconOnly)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Color.black.opacity(0.28), in: Circle())
            .buttonStyle(.plain)
            .accessibilityLabel(title)
    }
}

private struct HotlistCollectionCard: View {
    let hotlist: HotlistCollection
    let itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HotlistArtworkView(artwork: hotlist.artwork)
                .aspectRatio(1.34, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                }

            Text(hotlist.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct HotlistArtworkView: View {
    let artwork: HotlistCollection.Artwork

    var body: some View {
        switch artwork {
        case .dateNight:
            ToastPatternArtwork()
        case .nextPlan:
            PaddlePatternArtwork()
        case .weekend:
            Image("water_park")
                .resizable()
                .scaledToFill()
        case .bucketList:
            ZStack {
                LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.90))
            }
        case .repeatSpots:
            Image("tonino")
                .resizable()
                .scaledToFill()
        case .jaipur:
            Image("jaipur_collage")
                .resizable()
                .scaledToFill()
        }
    }
}

private struct ToastPatternArtwork: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.98, green: 0.71, blue: 0.10)
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(index.isMultiple(of: 2) ? Color.orange : Color.yellow)
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.white.opacity(0.38), lineWidth: 2)
                        }
                        .frame(width: proxy.size.width * 0.22, height: proxy.size.height * 0.20)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? 8 : -7))
                        .position(
                            x: proxy.size.width * (0.17 + (CGFloat(index % 3) * 0.33)),
                            y: proxy.size.height * (0.18 + (CGFloat(index / 3) * 0.32))
                        )
                }
            }
        }
    }
}

private struct PaddlePatternArtwork: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.88, green: 0.08, blue: 0.04)
                ForEach(0..<7, id: \.self) { index in
                    Capsule()
                        .fill(Color.black.opacity(0.78))
                        .frame(width: proxy.size.width * 0.13, height: proxy.size.height * 0.52)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? 52 : -48))
                        .position(
                            x: proxy.size.width * (0.10 + (CGFloat(index % 4) * 0.28)),
                            y: proxy.size.height * (0.20 + (CGFloat(index / 4) * 0.60))
                        )
                }
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(Color.yellow.opacity(0.78))
                        .frame(width: 12, height: 12)
                        .position(
                            x: proxy.size.width * (0.16 + (CGFloat(index % 3) * 0.34)),
                            y: proxy.size.height * (0.30 + (CGFloat(index / 3) * 0.45))
                        )
                }
            }
        }
    }
}

private struct CreateHotlistSheet: View {
    let createAction: (String, HotlistCollection.Artwork) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedArtwork = HotlistCollection.Artwork.bucketList
    @FocusState private var isNameFocused: Bool

    private let suggestions: [(String, HotlistCollection.Artwork)] = [
        ("📌 Bucket list", .bucketList),
        ("💖 Repeat spots", .repeatSpots),
        ("🚗 Next plan", .nextPlan),
        ("🥂 Special day", .jaipur),
        ("💞 Date night", .dateNight),
        ("🌟 Weekend picks", .weekend)
    ]

    private var cleanedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create new")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 17)
            .frame(height: 65)

            Divider()
                .overlay(Color.white.opacity(0.10))

            VStack(spacing: 16) {
                TextField("Write Hotlist name here", text: $name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .font(.system(size: 16))
                    .padding(.horizontal, 15)
                    .frame(height: 53)
                    .background(Color.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    }
                    .onSubmit(createIfPossible)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(suggestions, id: \.0) { suggestion, artwork in
                            Button(suggestion) {
                                name = suggestion
                                selectedArtwork = artwork
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 31)
                            .background(Color.white.opacity(0.075), in: Capsule())
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button(action: createIfPossible) {
                    Text("Create")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(cleanedName.isEmpty ? .white.opacity(0.28) : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.plain)
                .background(
                    cleanedName.isEmpty ? Color.white.opacity(0.16) : Color.white,
                    in: Capsule()
                )
                .disabled(cleanedName.isEmpty)
            }
            .padding(.horizontal, 17)
            .padding(.top, 16)

            Spacer(minLength: 0)
        }
        .background(Color(red: 0.105, green: 0.105, blue: 0.115))
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            isNameFocused = true
        }
    }

    private func createIfPossible() {
        guard !cleanedName.isEmpty else { return }
        createAction(cleanedName, selectedArtwork)
    }
}
