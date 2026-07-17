import SwiftUI

struct DonationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethod: DonationMethod = .alipay

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.pink)
                    Text("support.donate.title")
                        .font(.title2.bold())
                    Text("support.donate.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Picker("support.donate.method", selection: $selectedMethod) {
                    ForEach(DonationMethod.allCases) { method in
                        Text(method.title).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                ScrollView {
                    Image(selectedMethod.assetName)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(.quaternary, lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 18, y: 8)
                        .accessibilityLabel(selectedMethod.title)
                        .accessibilityIdentifier("donation.qr.\(selectedMethod.rawValue)")

                    Label("support.donate.voluntary", systemImage: "hand.raised.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.top, 14)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .navigationTitle("support.donate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private enum DonationMethod: String, CaseIterable, Identifiable {
    case alipay
    case wechat

    var id: String { rawValue }
    var assetName: String { self == .alipay ? "DonationAlipay" : "DonationWeChat" }
    var title: LocalizedStringKey { self == .alipay ? "support.donate.alipay" : "support.donate.wechat" }
}
