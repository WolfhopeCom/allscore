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

/// A standard 320 × 50 banner: the same small size in portrait and landscape, so it never
/// changes height on rotation or crowds the screen.
private struct FixedBanner: View {
    var body: some View {
        BannerRepresentable()
            .frame(width: 320, height: 50)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Advertisement")
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.rootViewController = UIApplication.topViewController
        banner.load(GoogleMobileAds.Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {}
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
