import SwiftUI
import MapLibre
import CoreLocation

struct MapView: UIViewRepresentable {
    @StateObject private var locationManager = LocationManager()
    @State private var geojsonFilename: String? = nil
    private var styleURL: URL? {
        // Using a default MapTiler style. Replace with your own if needed.
        // Make sure to add your MapTiler key to your Info.plist as MGLMapTilerApiKey
        return URL(string: "https://api.maptiler.com/maps/streets-v2/style.json")
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.logoView.isHidden = true // Hide the MapLibre logo if desired
        mapView.attributionButton.isHidden = true // Hide the attribution button if desired
        return mapView
    }

    func updateUIView(_ uiView: MLNMapView, context: Context) {
        if let userLocation = locationManager.lastKnownLocation, uiView.userLocation == nil {
             uiView.setCenter(userLocation, zoomLevel: 14, animated: false)
        } else if let userLocation = uiView.userLocation?.coordinate {
             uiView.setCenter(userLocation, zoomLevel: uiView.zoomLevel, animated: true)
        }

        if let filename = geojsonFilename {
            context.coordinator.updateGeoJSON(on: uiView, geojsonFilename: filename)
            DispatchQueue.main.async {
                self.geojsonFilename = nil // Reset after loading
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, locationManager: locationManager)
    }

    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapView
        var locationManager: LocationManager

        init(_ parent: MapView, locationManager: LocationManager) {
            self.parent = parent
            self.locationManager = locationManager
        }

        func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
            // Map finished loading, start updating location if not already.
            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                locationManager.startUpdatingLocation()
            }
            // If a filename was set before map loaded, load it now.
            if let filename = parent.geojsonFilename {
                updateGeoJSON(on: mapView, geojsonFilename: filename)
                DispatchQueue.main.async {
                    // Ensures it's reset on the parent view's state
                    self.parent.geojsonFilename = nil
                }
            }
        }
        
        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            guard let userLocation = userLocation, let coordinate = userLocation.location?.coordinate else { return }
            // This can be used if you want to recenter the map whenever the user location updates,
            // but userTrackingMode = .follow already does this.
            // mapView.setCenter(coordinate, animated: true)
            
            // Update the @Published property in LocationManager
            // This isn't strictly necessary if MapView itself handles location,
            // but useful if other parts of your app need to observe the location.
            locationManager.lastKnownLocation = coordinate
        }

        func updateGeoJSON(on mapView: MLNMapView, geojsonFilename: String) {
            guard let style = mapView.style else { return }

            // Remove existing source and layer if they exist to avoid conflicts
            if let existingSource = style.source(withIdentifier: "restaurants-source") {
                style.removeSource(existingSource)
            }
            if let existingLayer = style.layer(withIdentifier: "restaurants-layer") { 
                style.removeLayer(existingLayer)
            }
            if let existingSymbolLayer = style.layer(withIdentifier: "restaurants-names-layer") {
                style.removeLayer(existingSymbolLayer)
            }

            // Use URL for MLNShapeSource
            guard let geojsonURL = Bundle.main.url(forResource: geojsonFilename, withExtension: "geojson") else {
                print("Error: GeoJSON file '\(geojsonFilename).geojson' not found in bundle.")
                return
            }

            let source = MLNShapeSource(identifier: "restaurants-source", url: geojsonURL, options: nil)
            style.addSource(source)

            let layer = MLNCircleStyleLayer(identifier: "restaurants-layer", source: source)
            layer.circleColor = NSExpression(forConstantValue: UIColor.systemBlue)
            layer.circleRadius = NSExpression(forConstantValue: 5)
            layer.circleOpacity = NSExpression(forConstantValue: 0.8)
            
            // Add a symbol layer for names if your GeoJSON has a "name" property
            let symbolLayer = MLNSymbolStyleLayer(identifier: "restaurants-names-layer", source: source)
            symbolLayer.text = NSExpression(forKeyPath: "name") // Assumes your GeoJSON features have a "name" property
            symbolLayer.textColor = NSExpression(forConstantValue: UIColor.black)
            symbolLayer.textFontSize = NSExpression(forConstantValue: 12)
            symbolLayer.textOffset = NSExpression(forConstantValue: CGVector(dx: 0, dy: 1.5)) // Offset text slightly below the circle
            symbolLayer.textHaloColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.75))
            symbolLayer.textHaloWidth = NSExpression(forConstantValue: 1)

            style.addLayer(layer)
            style.addLayer(symbolLayer)
            
            print("GeoJSON source and layers added for \(geojsonFilename).geojson")
        }
    }
    
    // Function to load GeoJSON (call this from ContentView or elsewhere)
    func loadGeoJSON(named filename: String) -> Self {
        var newSelf = self
        // Set the filename, the Coordinator or updateUIView will handle loading it
        newSelf._geojsonFilename = State(initialValue: filename)
        return newSelf
    }
}
