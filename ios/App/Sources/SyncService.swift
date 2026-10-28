import CodeIsraelKit
import Foundation

/// Keeps the progress the same on every device that uses the same sync code. The code is the only key: no account, no
/// e-mail. The server only sees a hash of it. It does nothing until a sync server has been set up (`Data/sync.json`).
@MainActor
@Observable
final class SyncService {
    private(set) var code: String? = UserDefaults.standard.string(forKey: "syncCode")
    private(set) var busy = false
    private(set) var error: String?
    private(set) var lastSync: Date? = UserDefaults.standard.object(forKey: "syncLast") as? Date

    /// Address of the sync server; nil when none is set up, and then the feature stays hidden.
    @ObservationIgnored let server: URL? = {
        struct Config: Decodable { let url: String }
        return Bundle.main.url(forResource: "sync", withExtension: "json", subdirectory: "Data")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(Config.self, from: $0) }
            .flatMap { URL(string: $0.url) }
    }()

    /// The function that mails the code, when one has been set up (`mail` in `Data/sync.json`).
    @ObservationIgnored let mailEndpoint: URL? = {
        struct Config: Decodable { let mail: String? }
        return Bundle.main.url(forResource: "sync", withExtension: "json", subdirectory: "Data")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(Config.self, from: $0) }
            .flatMap { $0.mail }.flatMap { URL(string: $0) }
    }()

    @ObservationIgnored private var pending: Task<Void, Never>?

    var available: Bool { server != nil }

    /// Starts the synchronisation with a new code, or with the code of another device. Returns false for a code that is not valid.
    @discardableResult
    func enable(code entered: String? = nil, model: AppModel) -> Bool {
        let next: String
        if let entered {
            guard let raw = SyncCode.normalize(entered) else {
                error = "Ce code n’est pas valide : il comporte 16 lettres et chiffres."
                return false
            }
            next = SyncCode.display(raw)
        } else {
            next = SyncCode.generate()
        }
        code = next
        error = nil
        UserDefaults.standard.set(next, forKey: "syncCode")
        scheduleSoon(model: model, after: 0)
        return true
    }

    func stop() {
        pending?.cancel()
        code = nil
        error = nil
        lastSync = nil
        UserDefaults.standard.removeObject(forKey: "syncCode")
        UserDefaults.standard.removeObject(forKey: "syncLast")
    }

    /// Synchronises in a few seconds (once, whatever the number of changes in the meantime).
    func scheduleSoon(model: AppModel, after seconds: Double = 8) {
        guard code != nil, server != nil else { return }
        pending?.cancel()
        pending = Task { [weak model] in
            if seconds > 0 { try? await Task.sleep(for: .seconds(seconds)) }
            guard !Task.isCancelled, let model else { return }
            await self.now(model: model)
        }
    }

    /// Downloads the saved progress, merges it with this device's, uploads the result.
    func now(model: AppModel) async {
        guard let code, let server, let id = SyncCode.id(for: code), !busy else { return }
        busy = true
        defer { busy = false }
        let url = server.appending(path: "p").appending(path: id)
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            var merged = model.progress
            if status == 200 {
                merged = ProgressMerge.merge(model.progress, try JSONDecoder().decode(SyncPayload.self, from: data).progress())
            } else if status != 404 {
                throw SyncError.server(status)
            }
            var put = URLRequest(url: url)
            put.httpMethod = "PUT"
            put.setValue("application/json", forHTTPHeaderField: "content-type")
            put.httpBody = try JSONEncoder().encode(SyncPayload(merged))
            let (_, putResponse) = try await URLSession.shared.data(for: put)
            let putStatus = (putResponse as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(putStatus) else { throw SyncError.server(putStatus) }
            model.applySynced(merged)
            lastSync = .now
            UserDefaults.standard.set(lastSync, forKey: "syncLast")
            error = nil
        } catch {
            self.error = (error as? SyncError)?.message ?? "Pas de connexion : la synchronisation reprendra plus tard."
        }
    }

    /// Asks the mail function to send the code. Returns an error message, or nil when it was sent.
    func mailCode(to email: String) async -> String? {
        guard let code, let mailEndpoint else { return "L’envoi par e-mail n’est pas disponible." }
        var request = URLRequest(url: mailEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "code": code])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(status) { return nil }
            return (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "Envoi impossible (\(status))."
        } catch {
            return "Pas de connexion : réessayez plus tard."
        }
    }

    private enum SyncError: Error {
        case server(Int)
        var message: String {
            switch self { case .server(let status): "Le serveur a répondu \(status)." }
        }
    }
}
