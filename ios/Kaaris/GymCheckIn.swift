import CoreLocation
import SwiftUI

struct GymCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CoachStore
    @StateObject private var location = GymLocationReader()
    @State private var feedback: String?
    @State private var showGymOptions = false

    let onConfirmed: () -> Void

    private var isDemo: Bool { store.isDemo }
    private var gym: GymCoordinate? {
        guard let data = store.gymCoordinateData else { return nil }
        return try? JSONDecoder().decode(GymCoordinate.self, from: data)
    }

    var body: some View {
        KPage {
            SectionLabel(text: "Pointage")
            KTitle(text: "T’ES À LA SALLE ?")
            Text(isDemo ? "Déclare ton arrivée pour tester le pointage." : "Tu peux déclarer ton arrivée ou vérifier que tu es à 200 m ou moins de ta salle. La position est demandée à ton clic. Le repère de salle est enregistré sur cet iPhone.")
                .foregroundStyle(muted)

            if store.accountID != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Label(gym == nil ? "Aucune salle enregistrée" : "Salle enregistrée", systemImage: "mappin.circle")
                        .font(.headline)
                    if gym == nil {
                        Text("Enregistre ta position quand tu es à la salle.")
                            .font(.subheadline)
                            .foregroundStyle(muted)
                        Button("Enregistrer cette salle") { saveGym() }
                            .buttonStyle(ActionStyle())
                    } else {
                        Button("Vérifier ma position") { verifyGym() }
                            .buttonStyle(ActionStyle())
                        Button("Gérer ma salle") { showGymOptions = true }
                            .buttonStyle(ActionStyle(filled: false))
                    }
                    if location.isLocating {
                        ProgressView("Recherche de ta position…")
                            .font(.subheadline)
                    }
                    if let feedback {
                        Text(feedback).font(.subheadline).foregroundStyle(muted)
                    }
                }
                .disabled(location.isLocating)
                .kPanel()
            }

            Button("Pointer manuellement") { confirm() }
                .buttonStyle(ActionStyle(filled: isDemo))
            Button("Fermer") { dismiss() }
                .buttonStyle(ActionStyle(filled: false))
        }
        .confirmationDialog("Gérer la salle enregistrée", isPresented: $showGymOptions, titleVisibility: .visible) {
            Button("Remplacer par ma position") { saveGym() }
            Button("Réinitialiser le repère", role: .destructive) {
                store.gymCoordinateData = nil
                feedback = "Le repère a été effacé de cet iPhone."
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Choisis une nouvelle salle ou retire le repère enregistré sur cet iPhone.")
        }
        .onDisappear { location.cancel() }
    }

    private func saveGym() {
        feedback = nil
        location.request { result in
            switch result {
            case .success(let position):
                let coordinate = GymCoordinate(latitude: position.coordinate.latitude, longitude: position.coordinate.longitude)
                if let data = try? JSONEncoder().encode(coordinate) {
                    store.gymCoordinateData = data
                    feedback = "Salle enregistrée. Tu peux vérifier ta présence."
                } else {
                    feedback = "Le repère n’a pas pu être enregistré. Réessaie."
                }
            case .failure(let error):
                feedback = error.message
            }
        }
    }

    private func verifyGym() {
        guard let gym else { return }
        feedback = nil
        location.request { result in
            switch result {
            case .success(let position):
                if position.distance(from: gym.location) <= 200 {
                    confirm()
                } else {
                    feedback = "Ta position est à plus de 200 m du repère. Vérifie le lieu ou pointe manuellement."
                }
            case .failure(let error):
                feedback = error.message
            }
        }
    }

    private func confirm() {
        location.cancel()
        onConfirmed()
        dismiss()
    }
}

private struct GymCoordinate: Codable {
    let latitude: Double
    let longitude: Double

    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
}

@MainActor
private final class GymLocationReader: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var isLocating = false

    private let manager = CLLocationManager()
    private var didRequestLocation = false
    private var didRequestAuthorization = false
    private var completion: ((Result<CLLocation, GymLocationError>) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func request(_ completion: @escaping (Result<CLLocation, GymLocationError>) -> Void) {
        guard self.completion == nil else { return }
        self.completion = completion
        isLocating = true
        startWhenAuthorized()
    }

    func cancel() {
        completion = nil
        didRequestLocation = false
        didRequestAuthorization = false
        isLocating = false
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startWhenAuthorized()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let position = locations.last,
              CLLocationCoordinate2DIsValid(position.coordinate),
              (0...100).contains(position.horizontalAccuracy),
              abs(position.timestamp.timeIntervalSinceNow) <= 30 else {
            finish(.failure(.imprecise))
            return
        }
        finish(.success(position))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let denied = (error as? CLError)?.code == .denied
        finish(.failure(denied ? .denied : .unavailable))
    }

    private func startWhenAuthorized() {
        guard completion != nil else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            guard !didRequestAuthorization else { return }
            didRequestAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            guard !didRequestLocation else { return }
            didRequestLocation = true
            manager.requestLocation()
        case .denied, .restricted:
            finish(.failure(.denied))
        @unknown default:
            finish(.failure(.unavailable))
        }
    }

    private func finish(_ result: Result<CLLocation, GymLocationError>) {
        guard let callback = completion else { return }
        cancel()
        callback(result)
    }
}

private enum GymLocationError: Error {
    case denied, imprecise, unavailable

    var message: String {
        switch self {
        case .denied: "Autorise la localisation dans les réglages de ton iPhone ou pointe manuellement."
        case .imprecise: "La position est trop imprécise. Active la position exacte, déplace-toi près d’une fenêtre ou pointe manuellement."
        case .unavailable: "La position est indisponible. Réessaie ou pointe manuellement."
        }
    }
}
