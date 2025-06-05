import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var body: some View {
        ZStack {
            if let locationError = locationManager.locationError {
                VStack {
                    Spacer()
                    Image(systemName: "location.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text(locationError)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding()
                    Spacer()
                }
                .background(Color(.systemBackground).ignoresSafeArea())
            } else if networkMonitor.isConnected {
                Map(coordinateRegion: $region, showsUserLocation: true)
                    .onAppear {
                        if let location = locationManager.lastLocation {
                            region = MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        }
                    }
                    .onChange(of: locationManager.lastLocation) { newLocation in
                        if let location = newLocation {
                            region = MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        }
                    }
                    .ignoresSafeArea()
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Network Connection")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .background(Color(.systemBackground).ignoresSafeArea())
            }
        }
    }
}
public protocol EquatableBytes: Equatable {
    init(bytes: [UInt8])
    var bytes: [UInt8] { get }
}

