import Foundation
import MapKit

/// Resolves a saved NSW address with Apple Maps and queries City of Parramatta's live ArcGIS zones.
/// Requires one address match and one zone containing nonblank `DAY` and `WEEK` values.
/// `WEEK` is shown as a recycling area; no exact dates or cleanup bookings are inferred.
struct ArcGISBinService {
    func fetchSchedule(for address: ResidentialAddress) async throws -> CollectionSchedule? {
        let text = "\(address.street), \(address.suburb) NSW \(address.postcode), Australia"
        guard let request = MKGeocodingRequest(addressString: text) else {
            throw FindCollectionScheduleError.addressNotFound
        }
        let matches = try await request.mapItems
        try Task.checkCancellation()
        guard matches.count == 1, let match = matches.first else {
            throw FindCollectionScheduleError.addressNotFound
        }
        let coordinate = match.location.coordinate
        var components = URLComponents(string: "https://services6.arcgis.com/NrOjMi9LSYL3MUze/arcgis/rest/services/CoP_Garbage_Recyle_July2021/FeatureServer/0/query")!
        components.queryItems = [
            URLQueryItem(name: "f", value: "json"),
            URLQueryItem(name: "geometry", value: "\(coordinate.longitude),\(coordinate.latitude)"),
            URLQueryItem(name: "geometryType", value: "esriGeometryPoint"),
            URLQueryItem(name: "inSR", value: "4326"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outFields", value: "DAY,WEEK"),
            URLQueryItem(name: "returnGeometry", value: "false")
        ]
        guard let url = components.url else { throw FindCollectionScheduleError.dataUnavailable }
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 30))
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FindCollectionScheduleError.dataUnavailable
        }
        return try Self.decodeSchedule(data, address: address)
    }

    /// Returns nil for no matching zone and rejects ambiguous, incomplete or error responses.
    /// Valid live results carry the collection day and recycling area, with no dated bin events.
    static func decodeSchedule(_ data: Data, address: ResidentialAddress) throws -> CollectionSchedule? {
        let response = try JSONDecoder().decode(ArcGISResponse.self, from: data)
        // ArcGIS may report an error inside an HTTP 200 response.
        guard response.error == nil, let features = response.features else {
            throw FindCollectionScheduleError.dataUnavailable
        }
        guard !features.isEmpty else { return nil }
        guard features.count == 1,
              let day = features[0].attributes.day?.trimmingCharacters(in: .whitespacesAndNewlines),
              let area = features[0].attributes.week?.trimmingCharacters(in: .whitespacesAndNewlines),
              !day.isEmpty, !area.isEmpty else {
            throw FindCollectionScheduleError.dataUnavailable
        }
        return CollectionSchedule(address: address, collections: [], collectionDay: day, recyclingArea: area)
    }
}

private struct ArcGISResponse: Decodable {
    let features: [ArcGISFeature]?
    let error: ArcGISError?
}

private struct ArcGISError: Decodable {
    let code: Int?
}

private struct ArcGISFeature: Decodable {
    let attributes: ArcGISAttributes
}

private struct ArcGISAttributes: Decodable {
    let day: String?
    let week: String?

    enum CodingKeys: String, CodingKey {
        case day = "DAY"
        case week = "WEEK"
    }
}
