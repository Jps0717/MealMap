import SwiftUI

struct MenuItemDetailView: View {
    let item: NutritionData

    var body: some View {
        Form {
            Section(header: Text("Overview")) {
                Text(item.item)
                    .font(.headline)
                HStack {
                    Text("Calories")
                    Spacer()
                    Text("\(Int(item.calories)) kcal")
                }
            }

            Section(header: Text("Macronutrients")) {
                nutrientRow("Protein", "\(format(item.protein)) g")
                nutrientRow("Fat",     "\(format(item.fat)) g")
                nutrientRow("Carbs",   "\(format(item.carbs)) g")
                nutrientRow("Fiber",   "\(format(item.fiber)) g")
            }

            Section(header: Text("Sodium")) {
                nutrientRow("Sodium", "\(Int(item.sodium)) mg")
            }
        }
        .navigationTitle(item.item)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func nutrientRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    private func format(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}