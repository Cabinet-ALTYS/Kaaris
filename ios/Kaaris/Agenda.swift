import AuthenticationServices
import Foundation
import Security
import SwiftUI
import UIKit

private struct AgendaConfiguration {
    let apiURL = Self.url(for: "KaarisAPIURL")
    let supabaseURL = Self.url(for: "SupabaseURL")
    let publishableKey = Self.value(for: "SupabasePublishableKey").flatMap {
        $0.hasPrefix("sb_publishable_") ? $0 : nil
    }

    private static func value(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.contains("$(") ? nil : trimmed
    }

    private static func url(for key: String) -> URL? {
        guard let value = value(for: key), let url = URL(string: value),
              url.scheme == "https", url.host != nil, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { return nil }
        return url
    }
}

private enum AgendaError: LocalizedError {
    case unavailable, signedOut, keychain, invalidResponse, googleConsent, staleProposal
    case http(Int, String?)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "La connexion est indisponible dans cette version."
        case .signedOut: return "Connecte-toi pour utiliser Google Agenda."
        case .keychain: return "Le trousseau iOS est indisponible. Réessaie après avoir déverrouillé l’iPhone."
        case .invalidResponse: return "Le service a renvoyé une réponse inattendue. Réessaie dans un instant."
        case .googleConsent: return "La connexion Google n’a pas abouti. Tu peux relancer l’autorisation."
        case .staleProposal: return "Ton planning a changé. Vérifie de nouveau les créneaux."
        case let .http(status, code):
            switch (status, code) {
            case (_, "email_not_confirmed"):
                return "Confirme ton adresse dans l’e-mail reçu, puis connecte-toi."
            case (_, "invalid_credentials"):
                return "L’adresse ou le mot de passe est incorrect."
            case (_, "weak_password"):
                return "Choisis un mot de passe plus long et difficile à deviner."
            case (_, "user_already_exists"), (_, "email_exists"):
                return "Un compte utilise déjà cette adresse."
            case (_, "google_reconnect_required"), (_, "google_connection_required"):
                return "Reconnecte Google Agenda pour renouveler l’accès."
            case (_, "google_not_configured"):
                return "Google Agenda est indisponible dans cette version."
            case (_, "unknown_calendar"):
                return "La liste de tes agendas a changé. Actualise-la puis réessaie."
            case (401, _):
                return "Ta session a expiré. Reconnecte-toi."
            case (403, _):
                return "L’accès a été refusé. Vérifie la connexion du compte."
            case (429, _):
                return "Trop de tentatives. Patiente avant de réessayer."
            case (500...599, _):
                return "Le service est temporairement indisponible. Réessaie dans un instant."
            default:
                return "Le service n’a pas pu traiter la demande."
            }
        }
    }
}

private final class AgendaHTTP: NSObject, URLSessionTaskDelegate, Sendable {
    struct ErrorBody: Decodable {
        let errorCode: String?
        let code: String?
        let error: String?

        enum CodingKeys: String, CodingKey {
            case errorCode = "error_code"
            case code
            case error
        }
    }

    static let shared = URLSession(
        configuration: .ephemeral,
        delegate: AgendaHTTP(),
        delegateQueue: nil
    )

    static func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AgendaError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            let problem = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw AgendaError.http(response.statusCode, problem?.errorCode ?? problem?.code ?? problem?.error)
        }
        return data
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private struct AgendaSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let email: String?
}

private struct AgendaSessionKeychain {
    let project: URL

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.kaaris.auth.supabase",
            kSecAttrAccount as String: project.absoluteString,
            kSecAttrSynchronizable as String: false
        ]
    }

    func load() throws -> AgendaSession? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw AgendaError.keychain }
        do {
            return try JSONDecoder().decode(AgendaSession.self, from: data)
        } catch {
            try clear()
            return nil
        }
    }

    func save(_ session: AgendaSession) throws {
        let data = try JSONEncoder().encode(session)
        let attributes = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ] as [String: Any]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw AgendaError.keychain }
        let status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        guard status == errSecSuccess else { throw AgendaError.keychain }
    }

    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AgendaError.keychain }
    }
}

private struct AgendaAuthAPI {
    struct Response: Decodable {
        struct User: Decodable { let email: String? }
        let accessToken: String?
        let refreshToken: String?
        let expiresAt: TimeInterval?
        let expiresIn: TimeInterval?
        let user: User?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresAt = "expires_at"
            case expiresIn = "expires_in"
            case user
        }

        func session(fallbackEmail: String?) throws -> AgendaSession? {
            guard let accessToken, let refreshToken else { return nil }
            guard !accessToken.isEmpty, !refreshToken.isEmpty,
                  let expiry = expiresAt ?? expiresIn.map({ Date.now.timeIntervalSince1970 + $0 })
            else { throw AgendaError.invalidResponse }
            return AgendaSession(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: Date(timeIntervalSince1970: expiry),
                email: user?.email ?? fallbackEmail
            )
        }
    }

    let url: URL
    let publishableKey: String

    func authenticate(email: String, password: String, signUp: Bool) async throws -> AgendaSession? {
        let data = try await request(
            path: signUp ? "signup" : "token",
            query: signUp ? nil : URLQueryItem(name: "grant_type", value: "password"),
            body: ["email": email, "password": password]
        )
        let response = try JSONDecoder().decode(Response.self, from: data)
        let session = try response.session(fallbackEmail: email)
        if session == nil && !signUp { throw AgendaError.invalidResponse }
        return session
    }

    func refresh(_ session: AgendaSession) async throws -> AgendaSession {
        let data = try await request(
            path: "token",
            query: URLQueryItem(name: "grant_type", value: "refresh_token"),
            body: ["refresh_token": session.refreshToken]
        )
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let refreshed = try response.session(fallbackEmail: session.email) else {
            throw AgendaError.invalidResponse
        }
        return refreshed
    }

    func logout(token: String) async throws {
        _ = try await request(
            path: "logout",
            query: URLQueryItem(name: "scope", value: "local"),
            token: token
        )
    }

    private func request(
        path: String,
        query: URLQueryItem?,
        body: [String: String]? = nil,
        token: String? = nil
    ) async throws -> Data {
        let endpoint = url.appending(path: "auth/v1").appending(path: path)
        guard let query,
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        else {
            return try await send(to: endpoint, body: body, token: token)
        }
        components.queryItems = [query]
        guard let url = components.url else { throw AgendaError.invalidResponse }
        return try await send(to: url, body: body, token: token)
    }

    private func send(to url: URL, body: [String: String]?, token: String?) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        return try await AgendaHTTP.data(for: request)
    }
}

private struct GoogleCalendar: Decodable, Identifiable {
    let id: String
    let title: String
    let primary: Bool
}

private struct GoogleFreeBusy: Decodable {
    struct Interval: Decodable {
        let start: Date
        let end: Date
    }

    let busy: [Interval]
    let unavailableCalendarIds: [String]
}

private struct AgendaBooking: Encodable, Identifiable {
    let id: UUID
    let title: String
    let startsAt: Date
    let endsAt: Date
}

private struct GoogleBookingResults: Decodable {
    struct Result: Decodable {
        enum Status: String, Decodable { case booked, conflict, error }
        let id: UUID
        let status: Status
    }

    let sessions: [Result]
}

private struct GoogleAgendaAPI {
    struct Status: Decodable {
        let available: Bool?
        let connected: Bool
    }
    struct Connect: Decodable { let authorizationUrl: URL }
    struct Calendars: Decodable { let calendars: [GoogleCalendar] }

    struct AvailabilityRequest: Encodable {
        let calendarIds: [String]
        let timeMin: Date
        let timeMax: Date
        let timeZone: String
    }

    struct BookingRequest: Encodable {
        let sessions: [AgendaBooking]
        let calendarIds: [String]
        let timeZone: String
    }

    let rootURL: URL

    func send(
        _ path: String,
        method: String,
        body: Data?,
        token: String
    ) async throws -> Data {
        let url = rootURL.appending(path: "v1/google").appending(path: path)
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return try await AgendaHTTP.data(for: request)
    }

    static func encode(_ body: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(body)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions.insert(.withFractionalSeconds)
            guard let date = formatter.date(from: string) else { throw AgendaError.invalidResponse }
            return date
        }
        return try decoder.decode(type, from: data)
    }
}

private struct AgendaProposal {
    static let calendarMargin: TimeInterval = 10 * 60

    struct Row: Identifiable {
        let session: WorkoutSession
        let date: Date?
        var id: UUID { session.id }
    }

    let rows: [Row]
    let calendarIDs: Set<String>

    var bookings: [AgendaBooking] {
        rows.compactMap { row in
            guard let date = row.date else { return nil }
            return AgendaBooking(
                id: row.id,
                title: "Entraînement KAARIS",
                startsAt: date,
                endsAt: date.addingTimeInterval(Double(row.session.durationMinutes) * 60)
            )
        }
    }

    static func build(
        sessions: [WorkoutSession],
        allSessions: [WorkoutSession],
        blocked: [GoogleFreeBusy.Interval],
        calendarIDs: Set<String>,
        preferences: CoachPreferences,
        from now: Date,
        until end: Date,
        calendar: Calendar
    ) -> Self {
        var held: [DateInterval] = []
        let busy = blocked.compactMap { interval -> DateInterval? in
            guard interval.end > interval.start else { return nil }
            return DateInterval(
                start: interval.start.addingTimeInterval(-calendarMargin),
                end: interval.end.addingTimeInterval(calendarMargin)
            )
        }

        let rows = sessions.map { session in
            let day = calendar.startOfDay(for: session.date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? end
            let duration = TimeInterval(session.durationMinutes) * 60
            guard duration > 0 else { return Row(session: session, date: nil) }

            let candidates = [session.date] + stride(from: 6 * 60, to: 22 * 60, by: 15).compactMap { minute in
                calendar.date(
                    bySettingHour: minute / 60,
                    minute: minute % 60,
                    second: 0,
                    of: day
                )
            }.sorted { abs($0.timeIntervalSince(session.date)) < abs($1.timeIntervalSince(session.date)) }

            let otherSessions = allSessions.filter {
                $0.id != session.id && $0.endDate > $0.date
                    && ($0.status == .planned || $0.status == .checkedIn)
            }.map { DateInterval(start: $0.date, end: $0.endDate) }

            let date = candidates.first { start in
                let finish = start.addingTimeInterval(duration)
                guard start > now, finish <= min(end, dayEnd) else { return false }
                let hours = stride(from: 0, to: duration, by: 60 * 15).map { start.addingTimeInterval($0) }
                    + [finish.addingTimeInterval(-1)]
                guard !hours.contains(where: { preferences.isQuiet(at: $0, calendar: calendar) }) else {
                    return false
                }
                let reserved = busy + held + otherSessions
                return !reserved.contains { $0.start < finish && start < $0.end }
            }

            if let date { held.append(DateInterval(start: date, duration: duration)) }
            return Row(session: session, date: date)
        }

        return Self(rows: rows, calendarIDs: calendarIDs)
    }
}

@MainActor
private final class CalendarConsent: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func open(_ url: URL) async throws {
        guard url.scheme == "https", url.host == "accounts.google.com" else {
            throw AgendaError.googleConsent
        }

        defer { session = nil }
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let authentication = ASWebAuthenticationSession(url: url, callbackURLScheme: "kaaris") { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? AgendaError.googleConsent)
                }
            }
            authentication.presentationContextProvider = self
            session = authentication
            if !authentication.start() { continuation.resume(throwing: AgendaError.googleConsent) }
        }

        guard callback.scheme == "kaaris", callback.host == "google-connected",
              URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?
                .first(where: { $0.name == "status" })?.value == "connected"
        else { throw AgendaError.googleConsent }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .keyWindow ?? ASPresentationAnchor()
    }
}

@MainActor
private final class AgendaModel: ObservableObject {
    @Published private(set) var session: AgendaSession?
    @Published private(set) var available: Bool?
    @Published private(set) var connected: Bool?
    @Published private(set) var calendars: [GoogleCalendar] = []
    @Published private(set) var calendarIDs: Set<String> = []
    @Published private(set) var proposal: AgendaProposal?
    @Published private(set) var working = false
    @Published private(set) var notice: String?

    private let configuration = AgendaConfiguration()
    private let consent = CalendarConsent()
    private var restored = false

    var authConfigured: Bool { auth != nil }
    var googleConfigured: Bool { configuration.apiURL != nil }

    private var auth: AgendaAuthAPI? {
        guard let url = configuration.supabaseURL, let key = configuration.publishableKey else { return nil }
        return AgendaAuthAPI(url: url, publishableKey: key)
    }

    private var keychain: AgendaSessionKeychain? {
        configuration.supabaseURL.map { AgendaSessionKeychain(project: $0) }
    }

    func restore() async {
        await perform {
            if !restored {
                if let keychain { session = try keychain.load() }
                restored = true
            }
            if session != nil, googleConfigured { try await updateGoogleStatus() }
        }
    }

    func authenticate(email: String, password: String, signUp: Bool) async {
        await perform {
            guard let auth, let keychain else { throw AgendaError.unavailable }
            guard let newSession = try await auth.authenticate(email: email, password: password, signUp: signUp) else {
                notice = "Vérifie tes e-mails pour confirmer l’inscription, puis connecte-toi."
                return
            }
            try keychain.save(newSession)
            session = newSession
            if googleConfigured { try await updateGoogleStatus() }
        }
    }

    func logout() async {
        await perform {
            guard let auth, let keychain else { throw AgendaError.unavailable }
            let token = try? await accessToken()
            try keychain.clear()
            session = nil
            resetGoogle()
            if let token {
                do {
                    try await auth.logout(token: token)
                } catch {
                    notice = "Déconnecté sur cet iPhone. La fin de session côté serveur n’a pas pu être confirmée."
                }
            } else {
                notice = "Déconnecté sur cet iPhone."
            }
        }
    }

    func connect() async {
        await perform {
            let data = try await send("connect", method: "POST")
            let response = try GoogleAgendaAPI.decode(GoogleAgendaAPI.Connect.self, from: data)
            try await consent.open(response.authorizationUrl)
            try await updateGoogleStatus()
            guard connected == true else { throw AgendaError.googleConsent }
        }
    }

    func disconnect() async {
        await perform {
            _ = try await send("connection", method: "DELETE")
            resetGoogle()
            connected = false
            notice = "Google Agenda déconnecté."
        }
    }

    func toggleCalendar(_ id: String) {
        guard !working else { return }
        if !calendarIDs.insert(id).inserted { calendarIDs.remove(id) }
        proposal = nil
        notice = nil
    }

    func verify(store: CoachStore) async {
        await perform {
            proposal = nil
            guard !calendarIDs.isEmpty else { return }
            let now = Date.now
            let calendar = Calendar.current
            guard let end = calendar.date(byAdding: .day, value: 7, to: now) else {
                throw AgendaError.invalidResponse
            }
            let sessions = store.sessions.filter {
                $0.status == .planned && $0.date > now && $0.endDate <= end
            }.sorted { $0.date < $1.date }
            guard !sessions.isEmpty else {
                notice = "Aucune séance prévue dans les sept prochains jours."
                return
            }

            let request = GoogleAgendaAPI.AvailabilityRequest(
                calendarIds: calendarIDs.sorted(),
                timeMin: now.addingTimeInterval(-AgendaProposal.calendarMargin),
                timeMax: end.addingTimeInterval(AgendaProposal.calendarMargin),
                timeZone: calendar.timeZone.identifier
            )
            let response = try await send(
                "freebusy",
                method: "POST",
                body: GoogleAgendaAPI.encode(request)
            )
            let result = try GoogleAgendaAPI.decode(GoogleFreeBusy.self, from: response)
            guard result.unavailableCalendarIds.isEmpty else {
                notice = "Un agenda sélectionné n’est pas accessible. Change la sélection puis relance la vérification."
                return
            }
            proposal = AgendaProposal.build(
                sessions: sessions,
                allSessions: store.sessions,
                blocked: result.busy,
                calendarIDs: calendarIDs,
                preferences: store.preferences,
                from: now,
                until: end,
                calendar: calendar
            )
        }
    }

    func publish(store: CoachStore) async {
        await perform {
            guard let proposal, proposal.calendarIDs == calendarIDs, !proposal.bookings.isEmpty else {
                throw AgendaError.staleProposal
            }
            let now = Date.now
            for row in proposal.rows {
                guard let date = row.date else { continue }
                guard date > now,
                      let session = store.sessions.first(where: { $0.id == row.id }),
                      session == row.session,
                      !store.sessions.contains(where: {
                          $0.id != row.id && ($0.status == .planned || $0.status == .checkedIn)
                              && $0.date < date.addingTimeInterval(Double(session.durationMinutes) * 60)
                              && date < $0.endDate
                      })
                else {
                    self.proposal = nil
                    throw AgendaError.staleProposal
                }
            }

            let request = GoogleAgendaAPI.BookingRequest(
                sessions: proposal.bookings,
                calendarIds: calendarIDs.sorted(),
                timeZone: Calendar.current.timeZone.identifier
            )
            let data = try await send("sessions", method: "POST", body: GoogleAgendaAPI.encode(request))
            let results = try GoogleAgendaAPI.decode(GoogleBookingResults.self, from: data)
            var booked = 0
            var failed = 0
            var needsLocalUpdate = false
            for row in proposal.rows {
                guard let date = row.date else { continue }
                guard results.sessions.first(where: { $0.id == row.id })?.status == .booked else {
                    failed += 1
                    continue
                }
                booked += 1
                if date != row.session.date {
                    if store.sessions.first(where: { $0.id == row.id }) != row.session
                        || !store.reschedule(row.id, to: date) {
                        needsLocalUpdate = true
                    }
                }
            }
            self.proposal = nil

            var summary = booked == 1 ? "1 séance inscrite." : "\(booked) séances inscrites."
            if failed > 0 {
                summary += failed == 1
                    ? " Un créneau n’a pas été inscrit. Vérifie-le de nouveau."
                    : " \(failed) créneaux n’ont pas été inscrits. Vérifie-les de nouveau."
            }
            if needsLocalUpdate {
                summary += " Le planning local a changé pendant l’écriture. Compare-le avec Google Agenda."
            }
            notice = summary
        }
    }

    private func updateGoogleStatus() async throws {
        let statusData = try await send("status")
        let status = try GoogleAgendaAPI.decode(GoogleAgendaAPI.Status.self, from: statusData)
        connected = status.connected
        guard status.connected else {
            resetGoogle()
            available = status.available
            connected = false
            return
        }
        available = status.available

        let data = try await send("calendars")
        let result = try GoogleAgendaAPI.decode(GoogleAgendaAPI.Calendars.self, from: data)
        let hadCalendars = !calendars.isEmpty
        calendars = result.calendars
        calendarIDs.formIntersection(calendars.map(\.id))
        if !hadCalendars, let preferred = calendars.first(where: \.primary) ?? calendars.first {
            calendarIDs.insert(preferred.id)
        }
        if proposal?.calendarIDs != calendarIDs { proposal = nil }
    }

    private func resetGoogle() {
        available = nil
        connected = nil
        calendars = []
        calendarIDs = []
        proposal = nil
    }

    private func accessToken(replacing previous: String? = nil) async throws -> String {
        guard let session else { throw AgendaError.signedOut }
        if session.expiresAt.timeIntervalSinceNow > 60, session.accessToken != previous {
            return session.accessToken
        }
        guard let auth, let keychain else { throw AgendaError.unavailable }
        do {
            let renewed = try await auth.refresh(session)
            try keychain.save(renewed)
            self.session = renewed
            return renewed.accessToken
        } catch let AgendaError.http(status, _) where status == 400 || status == 401 || status == 403 {
            try keychain.clear()
            self.session = nil
            resetGoogle()
            throw AgendaError.signedOut
        }
    }

    private func send(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = configuration.apiURL else { throw AgendaError.unavailable }
        let api = GoogleAgendaAPI(rootURL: url)
        let token = try await accessToken()
        do {
            return try await api.send(path, method: method, body: body, token: token)
        } catch let AgendaError.http(status, _) where status == 401 {
            let renewed = try await accessToken(replacing: token)
            return try await api.send(path, method: method, body: body, token: renewed)
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard !working else { return }
        working = true
        notice = nil
        defer { working = false }

        do {
            try await operation()
        } catch is CancellationError {
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            notice = "Connexion Google annulée."
        } catch let error as AgendaError {
            if case let .http(_, code) = error,
               code == "google_reconnect_required" || code == "google_connection_required" {
                resetGoogle()
                connected = false
            }
            notice = error.localizedDescription
        } catch let error as URLError where error.code == .cancelled {
        } catch is URLError {
            notice = "Connexion au service interrompue. Vérifie le réseau puis réessaie."
        } catch {
            notice = AgendaError.invalidResponse.localizedDescription
        }
    }
}

struct AgendaScreen: View {
    private enum Confirmation {
        case booking, disconnect

        var title: String {
            switch self {
            case .booking: "Inscrire tes séances dans Google Agenda ?"
            case .disconnect: "Déconnecter Google Agenda ?"
            }
        }

        var message: String {
            switch self {
            case .booking: "Les créneaux proposés seront vérifiés avant l’écriture dans l’agenda KAARIS."
            case .disconnect: "Les séances déjà inscrites restent dans Google Agenda."
            }
        }
    }

    @EnvironmentObject private var store: CoachStore
    @StateObject private var model = AgendaModel()
    @State private var email = ""
    @State private var password = ""
    @State private var signUp = false
    @State private var confirmation: Confirmation?

    var body: some View {
        KPage {
            KTitle(text: "Google Agenda")
            if store.isDemo {
                card("Mode aperçu", icon: "calendar") {
                    Text("Retrouve tes séances dans l’onglet Plan.")
                        .foregroundStyle(.secondary)
                }
            } else {
                if model.authConfigured { accountCard }
                calendarCard
                if let proposal = model.proposal { proposalCard(proposal) }

                if let notice = model.notice {
                    Label(notice, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if model.working {
                    ProgressView("Un instant…")
                        .tint(acid)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar(.visible, for: .navigationBar)
        .task {
            guard !store.isDemo else { return }
            await model.restore()
        }
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: Binding(
                get: { confirmation != nil },
                set: { if !$0 { confirmation = nil } }
            ),
            titleVisibility: .visible,
            presenting: confirmation
        ) { action in
            switch action {
            case .booking:
                Button("Confirmer l’inscription") { Task { await model.publish(store: store) } }
            case .disconnect:
                Button("Déconnecter", role: .destructive) { Task { await model.disconnect() } }
            }
            Button("Annuler", role: .cancel) {}
        } message: { action in
            Text(action.message)
        }
    }

    private var accountCard: some View {
        card("Compte KAARIS", icon: "person.crop.circle") {
            if let session = model.session {
                if let email = session.email {
                    Text(email).textSelection(.enabled)
                }
                Button("Se déconnecter") {
                    Task { await model.logout() }
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(model.working)
            } else {
                TextField("Adresse e-mail", text: $email)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding(12)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                SecureField("Mot de passe", text: $password)
                    .textContentType(signUp ? .newPassword : .password)
                    .padding(12)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))

                primaryButton(signUp ? "Créer un compte" : "Me connecter", icon: "arrow.right") {
                    Task {
                        await model.authenticate(
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password,
                            signUp: signUp
                        )
                        password = ""
                    }
                }
                .disabled(model.working || !email.contains("@") || password.isEmpty)

                Button(signUp ? "J’ai déjà un compte" : "Créer un compte KAARIS") {
                    signUp.toggle()
                    password = ""
                }
                .font(.subheadline.weight(.semibold))
                .tint(acid)
                .disabled(model.working)
            }
        }
    }

    private var calendarCard: some View {
        card("Disponibilités", icon: "calendar") {
            if !model.authConfigured || !model.googleConfigured || model.available == false {
                Text("Google Agenda est indisponible dans cette version. Tu peux placer ou déplacer tes séances depuis ton planning.")
                    .foregroundStyle(.secondary)
            } else if model.session == nil {
                Text("Connecte-toi à ton compte KAARIS pour ajouter ton agenda.")
                    .foregroundStyle(.secondary)
            } else if model.connected == true {
                Label("Connecté", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(acid)
                if model.calendars.isEmpty {
                    Text("Aucun agenda accessible.")
                        .foregroundStyle(.secondary)
                    Button("Actualiser les agendas") { Task { await model.restore() } }
                        .disabled(model.working)
                } else {
                    Text("Agendas à vérifier")
                        .font(.subheadline.weight(.semibold))
                    ForEach(model.calendars) { calendar in
                        Toggle(isOn: Binding(
                            get: { model.calendarIDs.contains(calendar.id) },
                            set: { _ in model.toggleCalendar(calendar.id) }
                        )) {
                            Text(calendar.title)
                        }
                        .tint(acid)
                        .disabled(model.working)
                    }
                    primaryButton("Vérifier mes créneaux", icon: "magnifyingglass") {
                        Task { await model.verify(store: store) }
                    }
                    .disabled(model.working || model.calendarIDs.isEmpty)
                }
                Button("Déconnecter Google Agenda") { confirmation = .disconnect }
                    .font(.subheadline)
                    .disabled(model.working)
            } else {
                Text("KAARIS vérifie les plages occupées des agendas que tu sélectionnes et écrit dans un agenda dédié.")
                    .foregroundStyle(.secondary)
                primaryButton("Connecter Google Agenda", icon: "link") {
                    Task { await model.connect() }
                }
                .disabled(model.working)
                if model.connected == nil {
                    Button("Vérifier la connexion") { Task { await model.restore() } }
                        .disabled(model.working)
                }
            }
        }
    }

    private func proposalCard(_ proposal: AgendaProposal) -> some View {
        card("Tes créneaux", icon: "checkmark.circle") {
            ForEach(proposal.rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.session.title).fontWeight(.semibold)
                    if let date = row.date {
                        Text("\(dateLabel(date)) · \(hourLabel(date))")
                            .foregroundStyle(acid)
                        if date != row.session.date {
                            Text("Créneau de remplacement")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Aucun créneau disponible ce jour")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !proposal.bookings.isEmpty {
                primaryButton("Inscrire dans Google Agenda", icon: "calendar.badge.plus") {
                    confirmation = .booking
                }
                .disabled(model.working)
            }
        }
    }

    private func card<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .kPanel()
    }

    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon) }
            .buttonStyle(ActionStyle())
    }
}
