import SwiftUI

struct ComposerBlockValue {
    var kind: ComposerBlockKind
    var heading = ""
    var body = ""
    var options = ["", ""]
    var multiple = false
    var minimum = 1
    var maximum = 2
    var cells = [["", ""], ["", ""]]
    var language = ""
    var date = Date()
    var timezone = TimeZone.current.identifier
    var quoteHeader = ""
    var pollName = "poll" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    static func literal(_ text: String) -> String { text.replacingOccurrences(of: "[", with: "&#91;").replacingOccurrences(of: "]", with: "&#93;") }
    static func unescape(_ text: String) -> String { text.replacingOccurrences(of: "&#91;", with: "[").replacingOccurrences(of: "&#93;", with: "]").replacingOccurrences(of: "&quot;", with: "\"") }
    func markup(maximumOptions: Int) throws -> String {
        switch kind {
        case .poll:
            let values = options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard !heading.isEmpty, values.count >= 2, values.count <= maximumOptions, values.allSatisfy({ !$0.isEmpty && !$0.contains("\n") }), Set(values).count == values.count, minimum >= 1, maximum >= minimum, maximum <= values.count else { throw RepositoryError.invalid("Enter a question and unique options within the permitted selection limits.") }
            let attrs = multiple ? " type=multiple min=\(minimum) max=\(maximum)" : ""
            return "[poll name=\(pollName)\(attrs)]\n# \(Self.literal(heading.replacingOccurrences(of: "\n", with: " ")))\n" + values.map { "* " + Self.literal($0) }.joined(separator: "\n") + "\n[/poll]"
        case .table:
            guard cells.count >= 2, let width = cells.first?.count, width >= 1, cells.allSatisfy({ $0.count == width }) else { throw RepositoryError.invalid("A table needs headers and at least one row.") }
            func row(_ values: [String]) -> String { "| " + values.map { $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: "<br>") }.joined(separator: " | ") + " |" }
            return ([row(cells[0]), row(Array(repeating: "---", count: width))] + cells.dropFirst().map(row)).joined(separator: "\n")
        case .details:
            guard !heading.trimmingCharacters(in: .whitespaces).isEmpty, !body.isEmpty else { throw RepositoryError.invalid("Enter a summary and body.") }
            return "[details=\"\(Self.literal(heading).replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "\n", with: " "))\"]\n\(body.replacingOccurrences(of: "[/details]", with: "&#91;/details&#93;"))\n[/details]"
        case .spoiler:
            guard !body.isEmpty else { throw RepositoryError.invalid("Enter concealed text.") }
            return "[spoiler]\(Self.literal(body))[/spoiler]"
        case .code:
            guard !body.isEmpty, language.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "+" }) else { throw RepositoryError.invalid("Enter code and a valid language name.") }
            let fence = String(repeating: "`", count: max(3, body.components(separatedBy: "\n").map { $0.prefix { $0 == "`" }.count + 1 }.max() ?? 3))
            return fence + language + "\n" + body + "\n" + fence
        case .date:
            guard let zone = TimeZone(identifier: timezone) else { throw RepositoryError.invalid("Choose a valid timezone.") }
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = zone; formatter.dateFormat = "yyyy-MM-dd"
            let day = formatter.string(from: date); formatter.dateFormat = "HH:mm:ss"
            return "[date=\(day) time=\"\(formatter.string(from: date))\" timezone=\"\(timezone)\"]"
        case .quote:
            guard quoteHeader.hasPrefix("[quote"), !body.isEmpty else { throw RepositoryError.invalid("Enter quotation text.") }
            return quoteHeader + "\n" + body.replacingOccurrences(of: "[/quote]", with: "&#91;/quote&#93;") + "\n[/quote]"
        default: throw RepositoryError.unsupported
        }
    }
    static func editing(_ node: MarkupNode) -> Self? {
        guard let kind = node.kind else { return nil }
        var value = Self(kind: kind); value.body = unescape(node.text)
        if [.quote, .details, .spoiler].contains(kind), let start = node.raw.firstIndex(of: "]"), let end = node.raw.range(of: "[/", options: .backwards) {
            var body = String(node.raw[node.raw.index(after: start)..<end.lowerBound])
            if kind != .spoiler { if body.hasPrefix("\n") { body.removeFirst() }; if body.hasSuffix("\n") { body.removeLast() } }
            value.body = unescape(body)
        }
        switch kind {
        case .quote: value.quoteHeader = String(node.raw.prefix { $0 != "]" }) + "]"
        case .code:
            var lines = node.raw.components(separatedBy: "\n"); if lines.last == "" { lines.removeLast() }; guard lines.count >= 3 else { return nil }
            value.language = String(lines[0].drop { $0 == "`" }); value.body = lines.dropFirst().dropLast().joined(separator: "\n")
        case .spoiler: guard node.raw.hasPrefix("[spoiler]") else { return nil }
        case .details:
            guard node.raw.hasPrefix("[details=\""), let end = node.raw.range(of: "\"]") else { return nil }
            value.heading = unescape(String(node.raw[node.raw.index(node.raw.startIndex, offsetBy: 10)..<end.lowerBound]))
        case .table:
            func cells(_ line: String) -> [String] {
                var values = [String](), cell = "", escaped = false
                for character in line {
                    if escaped { cell.append(character); escaped = false }
                    else if character == "\\" { escaped = true }
                    else if character == "|" { values.append(cell); cell = "" }
                    else { cell.append(character) }
                }
                if escaped { cell.append("\\") }
                values.append(cell)
                return values.dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "<br>", with: "\n") }
            }
            value.cells = node.raw.components(separatedBy: "\n").enumerated().filter { $0.offset != 1 }.map { cells($0.element) }
            guard let width = value.cells.first?.count, width > 0, value.cells.allSatisfy({ $0.count == width }) else { return nil }
        case .poll:
            let lines = node.raw.components(separatedBy: "\n")
            guard lines.count >= 5, lines[1].hasPrefix("# "), lines.dropFirst(2).dropLast().allSatisfy({ $0.hasPrefix("* ") }), let attributes = lines.first else { return nil }
            guard let regex = try? NSRegularExpression(pattern: #"^\[poll name=([A-Za-z0-9]+)(?: type=multiple min=([0-9]+) max=([0-9]+))?\]$"#), let match = regex.firstMatch(in: attributes, range: NSRange(attributes.startIndex..., in: attributes)) else { return nil }
            func group(_ index: Int) -> String? { Range(match.range(at: index), in: attributes).map { String(attributes[$0]) } }
            value.pollName = group(1) ?? value.pollName; value.heading = unescape(String(lines[1].dropFirst(2))); value.options = lines.dropFirst(2).dropLast().map { unescape(String($0.dropFirst(2))) }
            value.multiple = group(2) != nil; value.minimum = group(2).flatMap(Int.init) ?? 1; value.maximum = group(3).flatMap(Int.init) ?? value.options.count
        case .date:
            guard let regex = try? NSRegularExpression(pattern: #"^\[date=([0-9-]+) time="([0-9:]+)" timezone="([^"]+)"\]$"#), let match = regex.firstMatch(in: node.raw, range: NSRange(node.raw.startIndex..., in: node.raw)) else { return nil }
            func group(_ index: Int) -> String { Range(match.range(at: index), in: node.raw).map { String(node.raw[$0]) } ?? "" }
            value.timezone = group(3)
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: value.timezone); formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            guard let date = formatter.date(from: group(1) + " " + group(2)) else { return nil }; value.date = date
        default: return nil
        }
        return value
    }
}

struct ComposerBlockForm: View {
    @Environment(\.dismiss) private var dismiss
    @State var value: ComposerBlockValue
    let maximumOptions: Int
    let onSave: (String) -> Void
    @State private var error: String?
    @State private var revealed = false
    var body: some View {
        Form {
            if let error { Text(LocalizedStringKey(error)).foregroundStyle(Color.fomioDanger).accessibilityIdentifier("block-error") }
            switch value.kind {
            case .poll:
                TextField("Question", text: $value.heading, axis: .vertical)
                Section("Options") {
                    ForEach(value.options.indices, id: \.self) { index in
                        HStack { TextField("Option", text: $value.options[index]); if value.options.count > 2 { Button("Remove", systemImage: "minus.circle") { value.options.remove(at: index) }.labelStyle(.iconOnly).frame(minHeight: 44) } }
                    }
                    Button("Add option") { value.options.append("") }.disabled(value.options.count >= maximumOptions)
                }
                Toggle("Multiple choice", isOn: $value.multiple)
                if value.multiple { Stepper("Minimum selections: \(value.minimum)", value: $value.minimum, in: 1...max(1, value.options.count)); Stepper("Maximum selections: \(value.maximum)", value: $value.maximum, in: 1...max(1, value.options.count)) }
            case .table:
                ForEach(value.cells.indices, id: \.self) { row in
                    Section(row == 0 ? String(localized: "Headers") : String(localized: "Row \(row)")) { ForEach(value.cells[row].indices, id: \.self) { column in TextField("Cell \(column + 1)", text: $value.cells[row][column], axis: .vertical) } }
                }
                Button("Add row") { value.cells.append(Array(repeating: "", count: value.cells[0].count)) }
                Button("Add column") { for row in value.cells.indices { value.cells[row].append("") } }
                Button("Remove last row") { value.cells.removeLast() }.disabled(value.cells.count <= 2)
                Button("Remove last column") { for row in value.cells.indices { value.cells[row].removeLast() } }.disabled(value.cells[0].count <= 1)
            case .details: TextField("Summary", text: $value.heading, axis: .vertical); textBody
            case .spoiler:
                textBody
                Button(revealed ? "Conceal preview" : "Reveal preview") { revealed.toggle() }
                if revealed { Text(value.body).accessibilityLabel("Spoiler preview: " + value.body) }
            case .date:
                DatePicker("Date and time", selection: $value.date).environment(\.timeZone, TimeZone(identifier: value.timezone) ?? .current)
                Picker("Timezone", selection: $value.timezone) { ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0).tag($0) } }
            case .code: TextField("Language (optional)", text: $value.language).textInputAutocapitalization(.never).autocorrectionDisabled(); textBody
            case .quote: textBody
            default: EmptyView()
            }
        }.navigationTitle(Text(LocalizedStringKey(value.kind.title))).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") {
            do { onSave(try value.markup(maximumOptions: maximumOptions)); dismiss() } catch { self.error = error.localizedDescription }
        }.accessibilityIdentifier("block-save") } }
    }
    private var textBody: some View { TextEditor(text: $value.body).frame(minHeight: 200).accessibilityLabel(Text(LocalizedStringKey(value.kind == .code ? "Code" : "Body"))).accessibilityIdentifier("block-body") }
}

struct ComposerSuggestionView: View {
    let topic: TopicID
    let service: any CommunityService
    @State private var page: DiscussionPage?
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let page { Text(page.summary.title).font(.title2); Text(page.opening.body).textSelection(.enabled) }
                else if let error { Text(error) }
                else { ProgressView() }
            }.padding(20)
        }.navigationTitle("Similar discussion").navigationBarTitleDisplayMode(.inline)
        .task { do { page = try await service.discussion(topic, page: 0) } catch { self.error = error.localizedDescription } }
    }
}
