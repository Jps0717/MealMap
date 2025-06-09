import SwiftUI

struct NutritionDetailView: View {
    let item: NutritionData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with item name and calories
                    VStack(spacing: 8) {
                        Text(item.item)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(Int(item.calories)) Calories")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Macronutrients
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Macronutrients")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 12) {
                            MacronutrientRow(
                                name: "Fat",
                                amount: item.fat,
                                unit: "g",
                                color: .blue,
                                icon: "drop.fill"
                            )
                            
                            MacronutrientRow(
                                name: "Saturated Fat",
                                amount: item.saturatedFat,
                                unit: "g",
                                color: .purple,
                                icon: "drop.fill"
                            )
                            
                            MacronutrientRow(
                                name: "Carbohydrates",
                                amount: item.carbs,
                                unit: "g",
                                color: .orange,
                                icon: "leaf.fill"
                            )
                            
                            MacronutrientRow(
                                name: "Fiber",
                                amount: item.fiber,
                                unit: "g",
                                color: .brown,
                                icon: "leaf.fill"
                            )
                            
                            MacronutrientRow(
                                name: "Sugar",
                                amount: item.sugar,
                                unit: "g",
                                color: .pink,
                                icon: "cube.fill"
                            )
                            
                            MacronutrientRow(
                                name: "Protein",
                                amount: item.protein,
                                unit: "g",
                                color: .green,
                                icon: "figure.strengthtraining.traditional"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Other nutrients
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Other Nutrients")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 12) {
                            MacronutrientRow(
                                name: "Cholesterol",
                                amount: item.cholesterol,
                                unit: "mg",
                                color: .red,
                                icon: "heart.fill"
                            )
                            
                            MacronutrientRow(
                                name: "Sodium",
                                amount: item.sodium,
                                unit: "mg",
                                color: .yellow,
                                icon: "drop.fill"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Nutrition Facts")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct MacronutrientRow: View {
    let name: String
    let amount: Double
    let unit: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(name)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text("\(formatNumber(amount))\(unit)")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.1f", value)
        }
    }
}

#Preview {
    let sampleItem = NutritionData(
        item: "Big Mac",
        calories: 550,
        fat: 30,
        saturatedFat: 10,
        cholesterol: 80,
        sodium: 1010,
        carbs: 44,
        fiber: 3,
        sugar: 9,
        protein: 25
    )
    
    NutritionDetailView(item: sampleItem)
}