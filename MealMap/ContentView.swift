import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        MapView().loadGeoJSON(named: "restaurants_data")
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                locationManager.requestLocationPermission()
            }
    }
}
