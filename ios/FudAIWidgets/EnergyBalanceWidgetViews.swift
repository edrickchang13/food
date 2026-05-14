import SwiftUI
import WidgetKit

// MARK: - Energy Balance palette
// These are local to the EnergyBalance widget — do NOT add to WidgetPalette
// (which lives in CalorieWidgetViews.swift) to avoid touching other widgets.

private let energyRingColor   = Color(red: 0x4C / 255.0, green: 0x9A / 255.0, blue: 0xFF / 255.0) // #4C9AFF
private let energyRingTrack   = energyRingColor.opacity(0.18)
private let macroProteinColor = Color(red: 0xE3 / 255.0, green: 0x6B / 255.0, blue: 0x5E / 255.0) // #E36B5E
private let macroFatColor     = Color(red: 0xE8 / 255.0, green: 0xC5 / 255.0, blue: 0x47 / 255.0) // #E8C547
private let macroCarbsColor   = Color(red: 0x5B / 255.0, green: 0xC9 / 255.0, blue: 0x8B / 255.0) // #5BC98B

// MARK: - Entry view

struct EnergyBalanceWidgetEntryView: View {
    let entry: EnergyBalanceEntry

    var body: some View {
        MediumEnergyBalanceView(snapshot: entry.snapshot)
    }
}

// MARK: - Medium layout

private struct MediumEnergyBalanceView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 16) {
            KcalRingView(snapshot: snapshot)
                .frame(width: 96, height: 96)

            MacroListView(snapshot: snapshot)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Calorie ring

private struct KcalRingView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        ZStack {
            Circle()
                .stroke(energyRingTrack, lineWidth: 10)
            Circle()
                .trim(from: 0, to: snapshot.calorieProgress)
                .stroke(
                    energyRingColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(snapshot.calories)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("/ \(snapshot.calorieGoal)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Macro list

private struct MacroListView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MacroRow(color: macroProteinColor, grams: snapshot.protein, letter: "P")
            MacroRow(color: macroFatColor,     grams: snapshot.fat,     letter: "F")
            MacroRow(color: macroCarbsColor,   grams: snapshot.carbs,   letter: "C")
        }
    }
}

private struct MacroRow: View {
    let color: Color
    let grams: Int
    let letter: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(grams) g")
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(letter)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
