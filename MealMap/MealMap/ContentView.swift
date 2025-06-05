import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1 // 0 = Left, 1 = Map, 2 = Right

    var body: some View {
        TabView(selection: $selectedTab) {
            LeftView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Left")
                }
                .tag(0)

            MapScreen()
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
                .tag(1)

            RightView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Right")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
