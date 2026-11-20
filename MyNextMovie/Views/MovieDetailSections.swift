import SwiftUI

private let maxCastCount = 15
private let castPhotoSize: CGFloat = 80
private let castMemberWidth: CGFloat = 96
private let castTextMaxLines = 2
private let providerLogoSize: CGFloat = 56
private let providerWidth: CGFloat = 72
private let providerLogoCornerRadius: CGFloat = 12
private let providerNameMaxLines = 2
private let recommendedCardWidth: CGFloat = 140

private let symbolNameTrailer = "play.fill"
private let symbolNameNoPhoto = "person.fill"

/// Sections under the overview. Each one shows up only when it has data.
struct MovieDetailSections: View {
    let details: MovieDetails

    var body: some View {
        VStack(alignment: .leading, spacing: spacingExtraLarge) {
            if hasTrailer(details) {
                TrailerButton(details: details)
            }
            if !details.credits.cast.isEmpty {
                CastSection(cast: leadingCast(details))
            }
            if hasWatchProviders(regionProviders) {
                WatchProvidersSection(providers: regionProviders)
            }
            if !details.recommendations.results.isEmpty {
                RecommendationsSection(movies: details.recommendations.results)
            }
        }
    }

    private var regionProviders: CountryWatchProviders {
        return watchProviders(details, regionCode: watchRegionCode)
    }
}

/// First `maxCastCount` actors. TMDB lists an actor once for every role, each is shown once.
private func leadingCast(_ details: MovieDetails) -> [CastMember] {
    var cast: [CastMember] = []
    var castIds: [Int] = []
    for castMember in details.credits.cast {
        if cast.count == maxCastCount {
            break
        }
        if castIds.contains(castMember.id) {
            continue
        }
        cast.append(castMember)
        castIds.append(castMember.id)
    }
    return cast
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title).font(.headline)
    }
}

/// Opens the trailer on YouTube.
private struct TrailerButton: View {
    let details: MovieDetails

    @ViewBuilder
    var body: some View {
        if let trailerAddress = trailerURL(details) {
            Link(destination: trailerAddress) {
                Label("Watch Trailer", systemImage: symbolNameTrailer).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

// MARK: - Cast

private struct CastSection: View {
    let cast: [CastMember]

    var body: some View {
        VStack(alignment: .leading, spacing: spacingMedium) {
            SectionHeader(title: "Cast")
            ScrollView(.horizontal, showsIndicators: false) {
                castRow
            }
            .scrollClipDisabled()
        }
    }

    private var castRow: some View {
        HStack(alignment: .top, spacing: spacingMedium) {
            ForEach(cast) { castMember in
                CastMemberView(castMember: castMember)
            }
        }
    }
}

/// A round photo, the name and the character under it.
private struct CastMemberView: View {
    let castMember: CastMember

    var body: some View {
        VStack(spacing: spacingExtraSmall) {
            photo
            Text(castMember.name)
                .font(.caption.weight(.semibold))
                .lineLimit(castTextMaxLines)
            Text(castMember.character)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(castTextMaxLines)
        }
        .multilineTextAlignment(.center)
        .frame(width: castMemberWidth)
    }

    private var photo: some View {
        AsyncImage(url: profileURL(castMember)) { loadedImage in
            loadedImage.resizable().scaledToFill()
        } placeholder: {
            noPhoto
        }
        .frame(width: castPhotoSize, height: castPhotoSize)
        .clipShape(Circle())
    }

    private var noPhoto: some View {
        Image(systemName: symbolNameNoPhoto)
            .font(.title)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
    }
}

// MARK: - Where to Watch

private struct WatchProvidersSection: View {
    let providers: CountryWatchProviders

    var body: some View {
        VStack(alignment: .leading, spacing: spacingMedium) {
            SectionHeader(title: "Where to Watch")
            WatchProviderGroup(title: "Stream", providers: providers.flatrate ?? [])
            WatchProviderGroup(title: "Rent", providers: providers.rent ?? [])
            WatchProviderGroup(title: "Buy", providers: providers.buy ?? [])
            // Required by the TMDB terms of use.
            Text("Streaming data from JustWatch")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// One kind of offer, e.g. "Stream", as a row that scrolls sideways.
private struct WatchProviderGroup: View {
    let title: String
    let providers: [WatchProvider]

    @ViewBuilder
    var body: some View {
        if !providers.isEmpty {
            providerGroup
        }
    }

    private var providerGroup: some View {
        VStack(alignment: .leading, spacing: spacingSmall) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                providerRow
            }
            .scrollClipDisabled()
        }
    }

    private var providerRow: some View {
        HStack(alignment: .top, spacing: spacingMedium) {
            ForEach(providers) { provider in
                WatchProviderView(provider: provider)
            }
        }
    }
}

private struct WatchProviderView: View {
    let provider: WatchProvider

    var body: some View {
        VStack(spacing: spacingExtraSmall) {
            logo
            Text(provider.providerName)
                .font(.caption2)
                .lineLimit(providerNameMaxLines)
                .multilineTextAlignment(.center)
        }
        .frame(width: providerWidth)
    }

    private var logo: some View {
        AsyncImage(url: logoURL(provider)) { loadedImage in
            loadedImage.resizable().scaledToFit()
        } placeholder: {
            Rectangle().fill(.quaternary)
        }
        .frame(width: providerLogoSize, height: providerLogoSize)
        .clipShape(RoundedRectangle(cornerRadius: providerLogoCornerRadius, style: .continuous))
    }
}

// MARK: - More Like This

/// Recommended movies. Tapping one opens its details, like a cell of the grid.
private struct RecommendationsSection: View {
    let movies: [Movie]

    var body: some View {
        VStack(alignment: .leading, spacing: spacingMedium) {
            SectionHeader(title: "More Like This")
            ScrollView(.horizontal, showsIndicators: false) {
                movieRow
            }
            .scrollClipDisabled()
        }
    }

    private var movieRow: some View {
        HStack(alignment: .top, spacing: spacingLarge) {
            ForEach(movies) { movie in
                recommendedMovie(movie)
            }
        }
    }

    private func recommendedMovie(_ movie: Movie) -> some View {
        NavigationLink(value: movie) {
            MovieCardView(movie: movie).frame(width: recommendedCardWidth)
        }
        .buttonStyle(.plain)
    }
}
