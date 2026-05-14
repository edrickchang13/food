import Foundation

/// Parses a MacroFactor "Export Food Log" CSV into Bulk AI's FoodEntry shape.
///
/// MacroFactor's export columns (60+ of them) cover calories, all four macros,
/// fiber/sugar/sodium/potassium/cholesterol/sat-mono-poly-fat that Bulk AI
/// already models — plus dozens of micronutrients (B vitamins, amino acids,
/// omega-3/6 breakdowns) we don't. Unmapped columns are dropped on import.
enum MacroFactorCSVImporter {
    enum ImportError: Error, LocalizedError {
        case fileUnreadable
        case noRows
        case missingRequiredColumn(String)

        var errorDescription: String? {
            switch self {
            case .fileUnreadable: "Couldn't read the CSV file."
            case .noRows: "The CSV had a header but no data rows."
            case .missingRequiredColumn(let name): "Expected column '\(name)' is missing."
            }
        }
    }

    /// Parse the file at `url` and return ready-to-add FoodEntry instances.
    /// Caller is responsible for inserting them into FoodStore. Throws on
    /// missing files, missing required columns (Date / Time / Food Name /
    /// Calories), or malformed UTF-8.
    static func parse(url: URL) throws -> [FoodEntry] {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            throw ImportError.fileUnreadable
        }

        // Strip the BOM MacroFactor writes at the start of its UTF-8 exports.
        var content = raw
        if content.hasPrefix("\u{FEFF}") {
            content.removeFirst()
        }

        let rows = parseCSV(content)
        guard rows.count >= 2 else { throw ImportError.noRows }

        let header = rows[0]
        let dataRows = rows.dropFirst()

        // Build a name → index map for O(1) column lookup per row.
        var columnIndex: [String: Int] = [:]
        for (i, name) in header.enumerated() {
            columnIndex[name] = i
        }
        for required in ["Date", "Time", "Food Name", "Calories (kcal)"] {
            if columnIndex[required] == nil {
                throw ImportError.missingRequiredColumn(required)
            }
        }

        func value(_ row: [String], _ column: String) -> String? {
            guard let i = columnIndex[column], i < row.count else { return nil }
            let v = row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }

        var entries: [FoodEntry] = []
        entries.reserveCapacity(dataRows.count)

        for row in dataRows {
            guard let dateStr = value(row, "Date"),
                  let timeStr = value(row, "Time"),
                  let name = value(row, "Food Name"),
                  let calStr = value(row, "Calories (kcal)"),
                  let calories = Int(calStr.replacingOccurrences(of: ",", with: ""))
            else { continue }

            guard let timestamp = parseTimestamp(date: dateStr, time: timeStr) else { continue }

            let protein = parseInt(value(row, "Protein (g)")) ?? 0
            let carbs = parseInt(value(row, "Carbs (g)")) ?? 0
            let fat = parseInt(value(row, "Fat (g)")) ?? 0

            let servingUnit = value(row, "Serving Size")
            let servingQty = parseDouble(value(row, "Serving Qty"))
            let servingGrams = parseDouble(value(row, "Serving Weight (g)"))

            let entry = FoodEntry(
                name: name,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                timestamp: timestamp,
                imageData: nil,
                imageFilename: nil,
                emoji: nil,
                source: .manual,
                mealType: mealType(forHour: Calendar.current.component(.hour, from: timestamp)),
                sugar: parseDouble(value(row, "Sugars (g)")),
                addedSugar: parseDouble(value(row, "Sugars Added (g)")),
                fiber: parseDouble(value(row, "Fiber (g)")),
                saturatedFat: parseDouble(value(row, "Saturated Fat (g)")),
                monounsaturatedFat: parseDouble(value(row, "Monounsaturated Fat (g)")),
                polyunsaturatedFat: parseDouble(value(row, "Polyunsaturated Fat (g)")),
                cholesterol: parseDouble(value(row, "Cholesterol (mg)")),
                sodium: parseDouble(value(row, "Sodium (mg)")),
                potassium: parseDouble(value(row, "Potassium (mg)")),
                servingSizeGrams: servingGrams,
                servingUnitOptions: [],
                selectedServingUnit: servingUnit,
                selectedServingQuantity: servingQty
            )
            entries.append(entry)
        }

        return entries
    }

    // MARK: - Helpers

    private static func parseTimestamp(date: String, time: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd hh:mm a"
        return formatter.date(from: "\(date) \(time)")
    }

    private static func parseInt(_ s: String?) -> Int? {
        guard let s, let d = Double(s.replacingOccurrences(of: ",", with: "")) else { return nil }
        return Int(d.rounded())
    }

    private static func parseDouble(_ s: String?) -> Double? {
        guard let s else { return nil }
        return Double(s.replacingOccurrences(of: ",", with: ""))
    }

    private static func mealType(forHour hour: Int) -> MealType {
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<21: return .dinner
        default: return .snack
        }
    }

    /// RFC 4180-ish parser sufficient for MacroFactor exports. Fields may be
    /// quoted with double quotes; commas inside quotes are preserved; a doubled
    /// double-quote inside a quoted field represents a literal ". Newlines
    /// inside quoted fields are also preserved. Loose enough to handle every
    /// row we've seen from MacroFactor without pulling in a heavier dependency.
    static func parseCSV(_ source: String) -> [[String]] {
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false
        var iter = source.makeIterator()

        while let ch = iter.next() {
            if inQuotes {
                if ch == "\"" {
                    if let peeked = peekNext(of: ch, in: &iter, append: &field) {
                        if peeked == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            handleScanned(peeked, field: &field, current: &current, rows: &rows)
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else {
                switch ch {
                case "\"":
                    inQuotes = true
                case ",":
                    current.append(field)
                    field = ""
                case "\r":
                    continue
                case "\n":
                    current.append(field)
                    field = ""
                    rows.append(current)
                    current = []
                default:
                    field.append(ch)
                }
            }
        }
        if !field.isEmpty || !current.isEmpty {
            current.append(field)
            rows.append(current)
        }
        return rows
    }

    /// Peeks one character past a closing quote so we can distinguish a true
    /// field terminator from an escaped quote (`""`). Returns the peeked
    /// character so the caller can act on it.
    private static func peekNext(of closeChar: Character, in iter: inout String.Iterator, append: inout String) -> Character? {
        return iter.next()
    }

    private static func handleScanned(_ ch: Character, field: inout String, current: inout [String], rows: inout [[String]]) {
        switch ch {
        case ",":
            current.append(field)
            field = ""
        case "\r":
            return
        case "\n":
            current.append(field)
            field = ""
            rows.append(current)
            current = []
        default:
            // Stray character right after a closing quote (rare); append it.
            field.append(ch)
        }
    }
}
