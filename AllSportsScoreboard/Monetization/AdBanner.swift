import SwiftUI
import GoogleMobileAds

/// A banner ad pinned to the bottom of a menu screen, with a one-tap way to remove ads.
/// Takes no space at all once ads are removed or can't be shown.
struct AdBannerBar: View {
    @Environment(\.theme) private var theme

    var body: some View {
        if AdManager.shared.showsAds {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Text("Advertisement")
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryText)
                    Spacer()
                    RemoveAdsButton(compact: true)
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                FixedBanner()
                    .padding(.bottom, 4)
            }
            .background(theme.background)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// "Remove Ads · $2.99", in the store's local price.
struct RemoveAdsButton: View {
    var compact = false
    @Environment(\.theme) private var theme

    var body: some View {
        let store = PurchaseStore.shared
        Button {
            Task { await store.purchase() }
        } label: {
            if compact {
                Text(store.displayPrice.map { "Remove ads · \($0)" } ?? "Remove ads")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.clock)
            } else {
                HStack {
                    Label("Remove Ads", systemImage: "nosign")
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    if store.status == .working {
                        ProgressView()
                    } else if let price = store.displayPrice {
                        Text(price)
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(theme.clock)
                    }
                }
            }
        }
        .disabled(store.status == .working)
        .accessibilityHint("One-time purchase that removes all ads")
    }
}

/// A fixed-size banner: 320 × 50 on iPhone, 728 × 90 (leaderboard) on iPad. A full-screen
/// iPad is at least 744 points wide in either orientation, so the size doesn't change on
/// rotation; only split-view windows narrower than 728 points fall back to 320 × 50.
private struct FixedBanner: View {
    /// The bar's width, measured before the banner is created so only one ad is requested.
    @State private var width: CGFloat = 0

    var body: some View {
        let size = Self.adSize(forWidth: width)
        ZStack {
            if width > 0 {
                BannerRepresentable(adSize: size)
                    .frame(width: size.size.width, height: size.size.height)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: size.size.height)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newWidth in width = newWidth }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Advertisement")
    }

    @MainActor
    static func adSize(forWidth width: CGFloat) -> AdSize {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        return isPad && width >= AdSizeLeaderboard.size.width ? AdSizeLeaderboard : AdSizeBanner
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.rootViewController = UIApplication.topViewController
        banner.load(GoogleMobileAds.Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        // An iPad split-view window crossed the 728-point line: switch sizes and reload once.
        guard banner.adSize.size != adSize.size else { return }
        banner.adSize = adSize
        banner.load(GoogleMobileAds.Request())
    }
}

/// Shows App Store results (failed, Ask to Buy pending) from wherever a purchase started.
struct PurchaseStatusAlert: ViewModifier {
    func body(content: Content) -> some View {
        let store = PurchaseStore.shared
        content.alert(
            title,
            isPresented: Binding(
                get: {
                    switch store.status {
                    case .failed, .pending: return true
                    case .idle, .working: return false
                    }
                },
                set: { if !$0 { store.status = .idle } }
            )
        ) {
            Button("OK", role: .cancel) { store.status = .idle }
        } message: {
            Text(message)
        }
    }

    private var title: String {
        if case .pending = PurchaseStore.shared.status { return "Waiting for Approval" }
        return "Purchase Not Completed"
    }

    private var message: String {
        switch PurchaseStore.shared.status {
        case .failed(let reason): return reason
        case .pending: return "Ads will disappear as soon as the purchase is approved."
        case .idle, .working: return ""
        }
    }
}
