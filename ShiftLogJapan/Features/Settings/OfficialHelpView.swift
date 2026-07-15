import SwiftUI

struct OfficialHelpView: View {
    @Environment(\.locale) private var locale
    private let links: [(String, String, String)] = [
        ("help.immigration", "https://www.moj.go.jp/isa/applications/procedures/shikakugai_00001.html", "日本語"),
        ("help.foreignLabor", "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/foreign/index.html", "多言語"),
        ("help.foreignConsultation", "https://www.check-roudou.mhlw.go.jp/soudan/foreigner.html", "多言語"),
        ("help.generalConsultation", "https://www.mhlw.go.jp/general/seido/chihou/kaiketu/soudan.html", "日本語"),
        ("help.minimumWage", MinimumWageCatalog.officialSourceURL.absoluteString, "日本語"),
        ("help.tax", "https://www.nta.go.jp/publication/pamph/koho/kurashi/html/02_1.htm", "日本語")
    ]
    private let glossary = ["支給額", "基本給", "深夜手当", "時間外手当", "通勤手当", "控除", "源泉所得税", "住民税", "雇用保険", "健康保険", "厚生年金", "差引支給額"]

    var body: some View {
        List {
            Section("help.official") {
                ForEach(links, id: \.1) { key, address, language in
                    Link(destination: URL(string: address)!) {
                        VStack(alignment: .leading, spacing: 3) {
                            Label(LocalizedStringKey(key), systemImage: "arrow.up.right.square")
                            Text(String(format: String(localized: "help.sourceMeta"), language, "2026-07-14")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Text("help.linksDisclaimer").font(.caption).foregroundStyle(.secondary)
            }
            Section("help.glossary") {
                ForEach(glossary, id: \.self) { term in
                    DisclosureGroup(term) {
                        Text(AppLocalization.string("glossary.\(term)", defaultValue: term, locale: locale))
                    }
                }
            }
        }
        .navigationTitle("help.title")
    }
}
