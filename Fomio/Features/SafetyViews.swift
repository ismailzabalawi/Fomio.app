import SwiftUI

// MARK: - Report (R03–R11)

struct ReportSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Bindable var state: ReportState
    @State private var confirmDiscard = false
    @FocusState private var detailsFocused: Bool
    private var noun: String { state.target.noun }
    private var heading: String {
        switch state.target { case .discussion: String(localized: "Report discussion"); case let .post(_, _, number, _): number.rawValue == 1 ? String(localized: "Report post") : String(localized: "Report reply") }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if typeSize.isAccessibilitySize { Text(heading).font(.title2.bold()).accessibilityAddTraits(.isHeader) }
                    content
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.fomioBackground)
            .navigationTitle(typeSize.isAccessibilitySize ? "" : heading).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isResult {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { if state.hasEdits && state.phase == .form { confirmDiscard = true } else { dismiss() } }
                            .disabled(state.isSending).accessibilityIdentifier("report-cancel")
                    }
                }
                if state.phase == .form || state.phase == .sending {
                    ToolbarItem(placement: .confirmationAction) {
                        if state.phase == .sending { ProgressView().accessibilityLabel("Sending report") }
                        else {
                            Button(typeSize.isAccessibilitySize ? String(localized: "Send") : String(localized: "Send report")) {
                                detailsFocused = false
                                Task { await state.send(isOffline: app.isOffline) }
                            }.fontWeight(.semibold).disabled(!state.canSend).accessibilityIdentifier("report-send")
                        }
                    }
                }
            }
            .alert("Discard this report?", isPresented: $confirmDiscard) {
                Button("Keep editing", role: .cancel) {}
                Button("Discard report", role: .destructive) { dismiss() }
            } message: { Text("Nothing has been sent. What you entered will be lost.") }
        }
        // Swipe-down can't drop typed input or interrupt a request in flight.
        .interactiveDismissDisabled(state.isSending || (state.hasEdits && state.phase == .form))
        .onChange(of: state.notice, initial: true) { _, notice in
            if notice == .signInRequired { app.resumeReportAfterSignIn(state) }
        }
    }
    private var isResult: Bool { [.received, .already, .unavailable, .removed].contains(state.phase) }
    @ViewBuilder private var content: some View {
        switch state.phase {
        case .loading: ProgressView("Checking what you can report").frame(maxWidth: .infinity).padding(.vertical, 40)
        case .form, .sending: form
        case .received:
            ResultBlock(symbol: "checkmark.circle", title: String(localized: "Report received"), message: String(localized: "Thanks for letting the moderators know. They’ll review this \(noun) and decide what happens next.")) {
                Button { dismiss() } label: { Text("Done").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).accessibilityIdentifier("report-done")
                if offerIgnore {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You can also ignore \(state.target.author) so their posts are collapsed for you. Ignoring is a personal setting and isn’t part of the report.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                        Button { app.queuedIgnore = state.target.author; dismiss() } label: { Label(String(localized: "Ignore \(state.target.author)…"), systemImage: "eye.slash").frame(minHeight: 44) }.buttonStyle(.bordered).accessibilityIdentifier("report-offer-ignore")
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 14))
                }
            }
        case .already:
            ResultBlock(symbol: "checkmark.circle", title: String(localized: "Already reported"), message: String(localized: "You’ve already reported this \(noun). The moderators have it.")) {
                Button { dismiss() } label: { Text("Done").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent)
            }
        case .unavailable:
            ResultBlock(symbol: "nosign", title: String(localized: "You can’t report this \(noun)"), message: String(localized: "Reporting isn’t available for this \(noun) on your account. Nothing was sent. If something needs attention, contact support.")) {
                Button { dismiss() } label: { Text("Close").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.bordered)
                Button("Contact support") { dismiss(); app.navigate(.safety) }.frame(minHeight: 44)
            }
        case .removed:
            ResultBlock(symbol: "bubble.left.and.exclamationmark.bubble.right", title: String(localized: "This \(noun) isn’t available"), message: String(localized: "It may have been removed or moved since you opened it. Nothing was sent.")) {
                Button { dismiss() } label: { Text("Close").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.bordered)
            }
        case let .loadFailed(message):
            ResultBlock(symbol: "exclamationmark.triangle", title: String(localized: "Couldn’t check this \(noun)"), message: message + " " + String(localized: "Nothing was sent.")) {
                Button("Try again") { Task { await state.load(isOffline: app.isOffline, keepInput: true) } }.buttonStyle(.bordered).frame(minHeight: 44)
            }
        }
    }
    private var offerIgnore: Bool {
        let author = state.target.author
        return app.safety.canIgnoreUsers && !author.isEmpty && author != app.username && !app.isIgnored(author)
    }
    @ViewBuilder private var form: some View {
        if let notice = state.notice { NoticeBanner(notice: notice, noun: noun, checking: state.checking) { Task { await state.checkStatus() } } }
        TargetCard(target: state.target, title: state.title, excerpt: state.context?.excerpt ?? "")
        VStack(alignment: .leading, spacing: 10) {
            Text("Why are you reporting this \(noun)?").font(.headline).accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(state.reasons.enumerated()), id: \.element.id) { index, reason in
                    if index > 0 { Divider().overlay(Color.fomioSeparator) }
                    ReasonRow(reason: reason, selected: state.reasonID == reason.id) { state.select(reason.id) }
                        .disabled(state.isSending)
                }
            }.background(Color.fomioFill, in: .rect(cornerRadius: 14))
        }
        if let reason = state.reason, reason.requiresMessage {
            VStack(alignment: .leading, spacing: 6) {
                Text("Details · Required").font(.subheadline.weight(.semibold))
                TextField("What should the moderators look at?", text: $state.details, axis: .vertical)
                    .lineLimit(3...8).focused($detailsFocused).disabled(state.isSending)
                    .padding(12).background(Color.fomioFill, in: .rect(cornerRadius: 12))
                    .overlay { if state.detailsMissing { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.fomioDanger, lineWidth: 1.5) } }
                    .accessibilityIdentifier("report-details")
                if state.detailsMissing {
                    Label("This reason needs a short description. Add it, then send.", systemImage: "exclamationmark.circle.fill").font(.footnote.weight(.semibold)).foregroundStyle(Color.fomioDanger)
                } else {
                    Text("Add a few words so moderators know what to look at.").font(.footnote).foregroundStyle(Color.fomioSecondaryText)
                }
            }
        }
        Text("Moderators review reports and decide what happens. Sending a report doesn’t remove anything by itself.").font(.footnote).foregroundStyle(Color.fomioSecondaryText)
    }
}

private struct ReasonRow: View {
    let reason: ReportReason
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(reason.name).font(.body.weight(selected ? .semibold : .regular)).foregroundStyle(Color.fomioText)
                    if !reason.description.isEmpty { Text(reason.description).font(.footnote).foregroundStyle(Color.fomioSecondaryText) }
                    if reason.requiresMessage { Text("Details required").font(.caption.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText) }
                }
                Spacer(minLength: 8)
                // Selection uses a filled check as well as tint, so it doesn't depend on color.
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(selected ? Color.fomioAccent : Color.fomioSecondaryText).accessibilityHidden(true)
            }.padding(.horizontal, 14).padding(.vertical, 12).frame(minHeight: 44).contentShape(.rect)
        }.buttonStyle(.plain)
        .accessibilityLabel(reason.name).accessibilityHint(reason.description)
        .accessibilityAddTraits(selected ? [.isSelected] : []).accessibilityIdentifier("report-reason-\(reason.id)")
    }
}

private struct TargetCard: View {
    let target: ReportTarget
    let title: String
    let excerpt: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Color.fomioSecondaryText)
            if !excerpt.isEmpty { Text(excerpt).font(.subheadline).lineLimit(3).environment(\.layoutDirection, excerpt.naturalDirection) }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.fomioFill, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
    private var label: String {
        switch target {
        case let .post(_, _, number, author):
            number.rawValue == 1 ? String(localized: "Post by \(author) · in “\(title)”") : String(localized: "Reply by \(author) · #\(number.rawValue) · in “\(title)”")
        case let .discussion(_, _, author): String(localized: "Discussion “\(title)” · started by \(author)")
        }
    }
}

/// Error and status notices: icon, bold title and outline, never color alone.
private struct NoticeBanner: View {
    let notice: ReportState.Notice
    let noun: String
    let checking: Bool
    let check: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.body.weight(.semibold)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.bold))
                Text(message).font(.subheadline)
                if notice == .unconfirmed {
                    Button { check() } label: { HStack { if checking { ProgressView() }; Text("Check status") }.frame(minHeight: 44) }
                        .disabled(checking).accessibilityIdentifier("report-check-status")
                }
            }
            Spacer(minLength: 0)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fomioFill, in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(notice == .notReceived ? Color.fomioSeparator : Color.fomioDanger, lineWidth: 1.5) }
        .accessibilityElement(children: .contain)
        .onAppear { UIAccessibility.post(notification: .announcement, argument: title) }
    }
    private var symbol: String {
        switch notice { case .offline: "wifi.slash"; case .rateLimited: "clock"; case .signInRequired: "person.crop.circle.badge.exclamationmark"; case .rejected: "exclamationmark.circle"; case .unconfirmed: "questionmark.circle"; case .notReceived: "info.circle" }
    }
    private var title: String {
        switch notice {
        case .offline: String(localized: "You’re offline")
        case .rateLimited: String(localized: "Too many reports right now")
        case .signInRequired: String(localized: "Sign in again")
        case .rejected: String(localized: "The community couldn’t accept this report")
        case .unconfirmed: String(localized: "We couldn’t confirm your report")
        case .notReceived: String(localized: "Your report wasn’t received")
        }
    }
    private var message: String {
        switch notice {
        case .offline: String(localized: "Your report hasn’t been sent. What you entered is kept. Send it when you’re connected.")
        case .rateLimited: String(localized: "Your report hasn’t been sent. Wait a few minutes, then send it. What you entered is kept.")
        case .signInRequired: String(localized: "Your session ended before the report was sent. What you entered is kept.")
        case let .rejected(text): text + " " + String(localized: "What you entered is kept.")
        case .unconfirmed: String(localized: "It may have been received. Check before sending again, so it isn’t sent twice.")
        case .notReceived: String(localized: "We checked and your report wasn’t received. You can send it now.")
        }
    }
}

private struct ResultBlock<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder var actions: Actions
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 40, weight: .semibold)).foregroundStyle(Color.fomioAccent).accessibilityHidden(true)
            Text(title).font(.title3.bold()).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
            Text(message).multilineTextAlignment(.center).foregroundStyle(Color.fomioSecondaryText)
            VStack(spacing: 10) { actions }.padding(.top, 6)
        }.frame(maxWidth: .infinity).padding(.vertical, 20)
        .onAppear { UIAccessibility.post(notification: .screenChanged, argument: title) }
    }
}

// MARK: - Ignore (I01–I08)

struct IgnoreSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Bindable var state: IgnoreState
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Avatar(name: state.name ?? state.username, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ignore \(state.username)?").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                            if let name = state.name, name != state.username { Text(name).font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }
                        }
                    }
                    if let banner { banner }
                    explainer(String(localized: "What changes for you"), String(localized: "Their posts are collapsed. Their posts don’t send you notifications. They can’t send you new personal messages."))
                    explainer(String(localized: "What stays the same"), String(localized: "It isn’t a report, and \(state.username) isn’t told. Their public posts stay visible to others, and they can still reply in public discussions. If you muted \(state.username), ignoring replaces the mute."))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration").font(.headline)
                        VStack(spacing: 0) {
                            ForEach(Array(IgnoreDuration.allCases.enumerated()), id: \.element) { index, option in
                                if index > 0 { Divider().overlay(Color.fomioSeparator) }
                                Button { state.duration = option } label: {
                                    HStack {
                                        Text(option.label).fontWeight(state.duration == option ? .semibold : .regular).foregroundStyle(Color.fomioText)
                                        Spacer()
                                        Image(systemName: state.duration == option ? "checkmark.circle.fill" : "circle").foregroundStyle(state.duration == option ? Color.fomioAccent : Color.fomioSecondaryText).accessibilityHidden(true)
                                    }.padding(.horizontal, 14).frame(minHeight: 44).contentShape(.rect)
                                }.buttonStyle(.plain).disabled(state.busy)
                                .accessibilityAddTraits(state.duration == option ? [.isSelected] : []).accessibilityIdentifier("ignore-duration-\(option.rawValue)")
                            }
                        }.background(Color.fomioFill, in: .rect(cornerRadius: 14))
                        if state.duration != .forever {
                            // The far-future Forever timestamp is never shown; finite ends are approximate because expired rows are purged daily.
                            Text("Ends around \(state.duration.expiry().formatted(date: .abbreviated, time: .omitted)). It may last up to a day longer.").font(.footnote).foregroundStyle(Color.fomioSecondaryText)
                        }
                    }
                    Button {
                        Task {
                            if await state.confirm(service: app.service, isOffline: app.isOffline) { await finish() }
                            else if state.phase == .signInRequired { reauthenticate() }
                        }
                    } label: {
                        HStack(spacing: 8) { if state.busy { ProgressView().tint(Color.fomioOnAccent) }; Text("Ignore user") }.frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.glassProminent).foregroundStyle(Color.fomioOnAccent).disabled(!state.canConfirm || state.busy).accessibilityIdentifier("ignore-confirm")
                }.padding(20)
            }.background(Color.fomioBackground)
            .navigationTitle("Ignore user").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(state.busy) } }
        }.interactiveDismissDisabled(state.busy)
    }
    private func explainer(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.subheadline.weight(.semibold)); Text(text).font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }
            .accessibilityElement(children: .combine)
    }
    private var banner: AnyView? {
        switch state.phase {
        case let .denied(message):
            return AnyView(StatusCard(symbol: "nosign", title: String(localized: "You can’t ignore this person"), message: message))
        case let .failed(message):
            return AnyView(StatusCard(symbol: "exclamationmark.triangle", title: String(localized: "Couldn’t ignore \(state.username)"), message: message + " " + String(localized: "Nothing changed.")))
        case .uncertain:
            return AnyView(StatusCard(symbol: "questionmark.circle", title: String(localized: "We couldn’t confirm the change"), message: String(localized: "Refresh to see whether \(state.username) is ignored before trying again.")) {
                Button("Refresh") { Task { if await state.reconcile(service: app.service) { await finish() } } }.frame(minHeight: 44).accessibilityIdentifier("ignore-refresh")
            })
        case .signInRequired:
            return AnyView(StatusCard(symbol: "person.crop.circle.badge.exclamationmark", title: String(localized: "Sign in again"), message: String(localized: "Your session ended and nothing changed. Sign in, then confirm again.")))
        default: return nil
        }
    }
    private func finish() async {
        dismiss()
        await app.safetyChanged()
        app.toast(String(localized: "You’re ignoring \(state.username). Their posts are hidden from you."))
    }
    private func reauthenticate() {
        let username = state.username, name = state.name
        dismiss()
        app.requestAuthAfterDismiss(.ignore(username)) { [app] in app.ignoreSheet = IgnoreState(username: username, name: name, account: app.account) }
    }
}

struct StatusCard<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder var actions: Actions
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.body.weight(.semibold)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.subheadline.weight(.bold)); Text(message).font(.subheadline); actions }
            Spacer(minLength: 0)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fomioFill, in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.fomioSeparator, lineWidth: 1.5) }
        .accessibilityElement(children: .contain)
    }
}
extension StatusCard where Actions == EmptyView {
    init(symbol: String, title: String, message: String) { self.init(symbol: symbol, title: title, message: message) { EmptyView() } }
}

/// Collapsed content from an ignored author. Show once reveals for this launch only; the preference is unchanged.
struct IgnoredPlaceholder: View {
    let text: String
    var author: String?
    let reveal: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.slash").foregroundStyle(Color.fomioSecondaryText).accessibilityHidden(true)
            Text(text).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
            Spacer(minLength: 8)
            Button("Show once", action: reveal).font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                .accessibilityLabel(String(localized: "Show once")).accessibilityHint(String(localized: "Shows it this time. You keep ignoring this person."))
        }.padding(.horizontal, 12).frame(maxWidth: .infinity, alignment: .leading)
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.fomioSeparator, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])) }
        .accessibilityElement(children: .contain)
    }
}

/// Profile safety controls: visible Ignore user, truthful self/staff/new-member/ignored states.
struct ProfileSafetySection: View {
    @Environment(AppState.self) private var app
    let username: String
    let name: String?
    @State private var member: MemberSafety?
    @State private var confirmStop = false
    @State private var working = false
    var body: some View {
        // A container that always exists, so the member check runs even before any control is shown.
        VStack(alignment: .leading, spacing: 0) {
            if username == app.username { EmptyView() }
            else if app.isIgnored(username) || member?.ignored == true {
                StatusCard(symbol: "eye.slash", title: String(localized: "You’re ignoring \(username)"), message: String(localized: "Their posts are hidden from you.")) {
                    Button("Stop ignoring") { confirmStop = true }.buttonStyle(.bordered).frame(minHeight: 44).disabled(working).accessibilityIdentifier("profile-stop-ignoring")
                }
            } else if member?.staff == true {
                Text("Moderators and admins can’t be ignored. If you’re concerned about a moderator, contact support.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
            } else if app.username == nil || member?.canIgnore == true {
                Button { app.startIgnore(username, name: name) } label: { Label("Ignore user", systemImage: "eye.slash").frame(minHeight: 44) }
                    .buttonStyle(.bordered).accessibilityIdentifier("profile-ignore")
            } else if member != nil {
                StatusCard(symbol: "info.circle", title: String(localized: "Ignore isn’t available for your account yet"), message: String(localized: "You can still report posts, or contact support."))
            }
        }
        .task(id: "\(app.account.rawValue)-\(app.safetyRevision)-\(username)") { member = try? await app.service.memberSafety(username) }
        .alert("Stop ignoring \(username)?", isPresented: $confirmStop) {
            Button("Cancel", role: .cancel) {}
            Button("Stop ignoring") { Task { working = true; _ = await stopIgnoring(username, app: app); working = false } }
        } message: { Text("Their posts will show again and you’ll get notifications from them. A mute you had before isn’t restored.") }
    }
}

/// Profile/bio/avatar concerns: no verified moderator route exists, so this escalates to the published support contact.
struct ProfileConcernView: View {
    @Environment(AppState.self) private var app
    let username: String
    @State private var resources: SafetyResources?
    var body: some View {
        ScrollView {
            ReadingColumn {
                VStack(alignment: .leading, spacing: 16) {
                    InfoCard(title: username, message: String(localized: "A name, bio or profile picture can’t be reported to moderators from the app. Contact support instead, and this profile will be included in your message."))
                    ContactSupportButton(resources: resources, subject: String(localized: "Profile concern: @\(username)"), message: app.configuration.map { "\($0.url("u/\(username)").absoluteString)\n\n" } ?? "")
                }.padding(20)
            }
        }.background(Color.fomioBackground).navigationTitle("Concern about a profile").navigationBarTitleDisplayMode(.inline)
        .task { resources = try? await app.service.safetyResources() }
    }
}

/// Opens the community's published contact in Mail. With no published destination it says so, instead of inventing one.
struct ContactSupportButton: View {
    let resources: SafetyResources?
    var subject = ""
    var message = ""
    var body: some View {
        if let email = resources?.contactEmail, let url = Self.mailURL(email, subject: subject, message: message) {
            Link(destination: url) { Label("Contact support", systemImage: "envelope").frame(maxWidth: .infinity, minHeight: 44) }
                .buttonStyle(.bordered).accessibilityHint(String(localized: "Opens Mail. Nothing is sent until you send it there."))
                .accessibilityIdentifier("contact-support")
        } else if resources != nil {
            Text("A support contact hasn’t been published for this community yet.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                .accessibilityIdentifier("contact-support-pending")
        } else { ProgressView() }
    }
    static func mailURL(_ email: String, subject: String, message: String) -> URL? {
        var components = URLComponents(); components.scheme = "mailto"; components.path = email
        var items: [URLQueryItem] = []
        if !subject.isEmpty { items.append(.init(name: "subject", value: subject)) }
        if !message.isEmpty { items.append(.init(name: "body", value: message)) }
        components.queryItems = items.isEmpty ? nil : items
        return components.url
    }
}

// MARK: - Safety & Help (H01–H04), Ignored users (I05–I06)

struct SafetyHelpView: View {
    @Environment(AppState.self) private var app
    @State private var resources: SafetyResources?
    @State private var error: String?
    var body: some View {
        List {
            Section {
                resourceRow(String(localized: "Community guidelines"), symbol: "text.book.closed", url: resources?.guidelines)
                resourceRow(String(localized: "Terms of service"), symbol: "doc.text", url: resources?.terms)
                resourceRow(String(localized: "Privacy policy"), symbol: "hand.raised", url: resources?.privacy)
                Button { app.navigate(.reportingHelp) } label: { row(String(localized: "Reporting and ignoring"), symbol: "questionmark.circle") }.buttonStyle(.plain)
            }
            Section {
                ContactSupportButton(resources: resources)
            } header: { Text("Contact support") } footer: { if let error { Text(error) } }
            Section {
                if app.username != nil {
                    Button { app.navigate(.ignoredUsers) } label: { row(String(localized: "Ignored users"), symbol: "eye.slash", count: app.safetyAccount == app.account && app.safetyError == nil ? app.safety.ignored.count : nil) }
                        .buttonStyle(.plain).accessibilityIdentifier("safety-ignored-users")
                } else {
                    Button { app.requireMember(.safety) { app.navigate(.ignoredUsers) } } label: { row(String(localized: "Ignored users"), symbol: "eye.slash") }.buttonStyle(.plain)
                }
            } footer: { if app.username == nil { Text("Sign in to see and manage people you ignore.") } }
        }.navigationTitle("Safety & Help")
        .task { do { resources = try await app.service.safetyResources(); error = nil } catch { resources = SafetyResources(); self.error = error.localizedDescription } }
    }
    @ViewBuilder private func resourceRow(_ title: String, symbol: String, url: URL?) -> some View {
        if let url { Link(destination: url) { row(title, symbol: symbol, external: true) }.buttonStyle(.plain) }
        else if resources != nil { HStack { Label(title, systemImage: symbol); Spacer(); Text("Not published yet").font(.footnote).foregroundStyle(Color.fomioSecondaryText) }.frame(minHeight: 44).accessibilityElement(children: .combine) }
        else { HStack { Label(title, systemImage: symbol); Spacer(); ProgressView() }.frame(minHeight: 44) }
    }
    private func row(_ title: String, symbol: String, count: Int? = nil, external: Bool = false) -> some View {
        HStack {
            Label(title, systemImage: symbol).foregroundStyle(Color.fomioText)
            Spacer()
            if let count { Text("\(count)").foregroundStyle(Color.fomioSecondaryText) }
            Image(systemName: external ? "arrow.up.right" : "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
        }.frame(minHeight: 44).contentShape(.rect)
    }
}

struct ReportingHelpView: View {
    var body: some View {
        ScrollView {
            ReadingColumn {
                VStack(alignment: .leading, spacing: 14) {
                    InfoCard(title: String(localized: "Report"), message: String(localized: "Sends a post, reply or discussion to the moderators with a reason. They review it and decide what happens. Find it in the ••• menu on any post."), symbol: "flag")
                    InfoCard(title: String(localized: "Ignore user"), message: String(localized: "A personal setting for your account. Their posts are collapsed for you, their posts don’t notify you, and they can’t send you new personal messages. It isn’t a report, and they aren’t told. Find it on their profile."), symbol: "eye.slash")
                    Text("Reporting and ignoring are separate. Doing one doesn’t do the other.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                }.padding(20)
            }
        }.background(Color.fomioBackground).navigationTitle("Reporting and ignoring").navigationBarTitleDisplayMode(.inline)
    }
}

struct IgnoredUsersView: View {
    @Environment(AppState.self) private var app
    @State private var stopping: String?
    @State private var working: Set<String> = []
    @State private var loading = false
    private var loaded: Bool { app.safetyAccount == app.account }
    var body: some View {
        List {
            Section {
                Text("Their posts are collapsed for you and they can’t send you new personal messages. They aren’t told.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
            }
            if !loaded || loading {
                ForEach(0..<3, id: \.self) { _ in HStack { Circle().frame(width: 34, height: 34); RoundedRectangle(cornerRadius: 4).frame(width: 140, height: 14) }.foregroundStyle(Color.fomioFill).frame(minHeight: 44) }
                    .accessibilityElement(children: .ignore).accessibilityLabel("Loading ignored users")
            } else if let error = app.safetyError {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Couldn’t load ignored users").font(.headline); Text(error).font(.subheadline).foregroundStyle(Color.fomioSecondaryText)
                    Button("Try again") { Task { await reload() } }.frame(minHeight: 44)
                }
            } else if app.safety.ignored.isEmpty {
                VStack(alignment: .leading, spacing: 6) { Text("You’re not ignoring anyone").font(.headline); Text("Ignore someone from their profile.").font(.subheadline).foregroundStyle(Color.fomioSecondaryText) }.padding(.vertical, 8)
            } else {
                ForEach(app.safety.ignored.sorted(), id: \.self) { username in
                    HStack(spacing: 12) {
                        Button { app.navigate(.profile(username)) } label: {
                            HStack(spacing: 12) { Avatar(name: username); Text(username).foregroundStyle(Color.fomioText) }.frame(minHeight: 44).contentShape(.rect)
                        }.buttonStyle(.plain).accessibilityLabel(String(localized: "View profile, \(username)"))
                        Spacer()
                        Button("Stop ignoring") { stopping = username }.buttonStyle(.borderless).frame(minHeight: 44).disabled(working.contains(username))
                            .accessibilityLabel(String(localized: "Stop ignoring \(username)")).accessibilityIdentifier("stop-ignoring-\(username)")
                    }
                }
            }
        }.navigationTitle("Ignored users")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Refresh").disabled(loading) } }
        .task(id: app.account) { if !loaded { await reload() } }
        .refreshable { await reload() }
        .alert("Stop ignoring \(stopping ?? "")?", isPresented: Binding(get: { stopping != nil }, set: { if !$0 { stopping = nil } })) {
            Button("Cancel", role: .cancel) { stopping = nil }
            Button("Stop ignoring") { if let name = stopping { Task { working.insert(name); _ = await stopIgnoring(name, app: app); working.remove(name) } }; stopping = nil }
        } message: { Text("Their posts will show again and you’ll get notifications from them. A mute you had before isn’t restored.") }
    }
    private func reload() async { loading = true; await app.loadSafety(); loading = false }
}
