import Foundation
import CoreLocation // For CLLocationCoordinate2D

// Basic Restaurant struct
// This can be expanded to match the properties in your GeoJSON features
struct Restaurant: Identifiable, Decodable {
    let id = UUID() // Conform to Identifiable for SwiftUI lists/iteration
    var name: String?
    var latitude: Double
    var longitude: Double
    // Add other properties from your GeoJSON as needed
    // e.g., var cuisine: String?
    // var address: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // Custom Decodable initializer if your GeoJSON structure is nested
    // For example, if coordinates are in a "geometry" object with a "coordinates" array
    // and properties are in a "properties" object.
    enum CodingKeys: String, CodingKey {
        case properties
        case geometry
    }

    enum PropertiesCodingKeys: String, CodingKey {
        case name // Assuming 'name' is a top-level property in 'properties'
        // Add other property keys here
    }

    enum GeometryCodingKeys: String, CodingKey {
        case coordinates // An array [longitude, latitude]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let propertiesContainer = try container.nestedContainer(keyedBy: PropertiesCodingKeys.self, forKey: .properties)
        self.name = try propertiesContainer.decodeIfPresent(String.self, forKey: .name)
        
        let geometryContainer = try container.nestedContainer(keyedBy: GeometryCodingKeys.self, forKey: .geometry)
        var coordinatesContainer = try geometryContainer.nestedUnkeyedContainer(forKey: .coordinates)
        
        // GeoJSON coordinates are [longitude, latitude]
        self.longitude = try coordinatesContainer.decode(Double.self)
        self.latitude = try coordinatesContainer.decode(Double.self)
    }

    // Convenience init for direct creation if needed
    init(name: String?, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}

// A structure to represent the top-level GeoJSON object (FeatureCollection)
// This is used by MLNGeoJSONDecoder
struct FeatureCollection: Decodable {
    let type: String
    let features: [RestaurantFeature]
}

// A structure to represent a single "feature" in the GeoJSON
// MLNMapView expects an array of objects conforming to MLNFeature
// However, for decoding, we'll define a structure that matches the GeoJSON
// and then convert it if needed, or MLNGeoJSONDecoder might handle it.
// Let's refine this. MLNGeoJSONDecoder.decode(featureCollectionFrom:) returns MLNFeature objects directly
// so we might not need a custom Feature struct for MapLibre, but it's good for understanding
// and for potentially decoding the data for other uses.
// For MapLibre's MLNShapeSource(identifier:features:options:), it expects [MLNFeature].
// Let's assume MLNGeoJSONDecoder handles the parsing into MLNFeature for now.

// For the purpose of using `MLNGeoJSONDecoder().decode(featureCollectionFrom: geojsonData)`,
// we don't need to decode into our custom `Restaurant` struct here.
// The `MLNFeature` objects returned by the decoder will have `attributes`
// that we can access (e.g., feature.attribute(forKey: "name")).

// The Restaurant struct above is more for if you were parsing the GeoJSON
// into an array of `Restaurant` objects for use elsewhere in your app (e.g., in a list view).
// For now, MapView's Coordinator will use MLNFeature attributes directly.

// Let's make `RestaurantFeature` match the GeoJSON structure for `features` array elements.
struct RestaurantFeature: Decodable {
    let type: String
    let properties: [String: AnyCodableValue]? // Or define specific properties
    let geometry: GeometryData
    
    struct GeometryData: Decodable {
        let type: String // e.g., "Point"
        let coordinates: [Double] // [longitude, latitude]
    }
}

// Helper to decode "any" value in properties, as GeoJSON properties can have mixed types.
struct AnyCodableValue: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else {
            throw DecodingError.typeMismatch(AnyCodableValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}