import Foundation
import SwiftData

@Model
final class FuelingRecord {
    var id: UUID
    var date: Date
    var currentMiles: Double
    var previousMiles: Double
    var pricePerGallon: Double
    var gallons: Double
    var totalCost: Double
    var isPartialFillUp: Bool
    var notes: String?
    var createdAt: Date

    var vehicle: Vehicle?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        currentMiles: Double,
        previousMiles: Double,
        pricePerGallon: Double,
        gallons: Double,
        totalCost: Double,
        isPartialFillUp: Bool = false,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.currentMiles = currentMiles
        self.previousMiles = previousMiles
        self.pricePerGallon = pricePerGallon
        self.gallons = gallons
        self.totalCost = totalCost
        self.isPartialFillUp = isPartialFillUp
        self.notes = notes
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    /// Miles driven since last fill-up
    var milesDriven: Double {
        currentMiles - previousMiles
    }

    /// Miles per gallon for this fill-up
    var mpg: Double {
        guard gallons > 0 else { return 0 }
        return milesDriven / gallons
    }

    /// Cost per mile for this fill-up
    var costPerMile: Double {
        guard milesDriven > 0 else { return 0 }
        return totalCost / milesDriven
    }

    // MARK: - Static Calculation Helpers

    /// Calculate total cost from price per gallon and gallons
    static func calculateTotalCost(pricePerGallon: Double, gallons: Double) -> Double {
        return pricePerGallon * gallons
    }

    /// Calculate gallons from total cost and price per gallon
    static func calculateGallons(totalCost: Double, pricePerGallon: Double) -> Double {
        guard pricePerGallon > 0 else { return 0 }
        return totalCost / pricePerGallon
    }

    /// Calculate price per gallon from total cost and gallons
    static func calculatePricePerGallon(totalCost: Double, gallons: Double) -> Double {
        guard gallons > 0 else { return 0 }
        return totalCost / gallons
    }
}

// MARK: - CSV Export/Import Support
extension FuelingRecord {
    static let csvHeader = "date,currentMiles,previousMiles,pricePerGallon,gallons,totalCost,isPartialFillUp,notes"

    func toCSVRow() -> String {
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: date)
        let notesEscaped = (notes ?? "").replacingOccurrences(of: "\"", with: "\"\"")

        return "\(dateString),\(currentMiles),\(previousMiles),\(pricePerGallon),\(gallons),\(totalCost),\(isPartialFillUp),\"\(notesEscaped)\""
    }

    static func fromCSVRow(_ row: String) -> FuelingRecord? {
        let components = parseCSVRow(row)
        guard components.count >= 6 else { return nil }

        let dateFormatter = ISO8601DateFormatter()

        guard let date = dateFormatter.date(from: components[0]),
              let currentMiles = Double(components[1]),
              let previousMiles = Double(components[2]),
              let pricePerGallon = Double(components[3]),
              let gallons = Double(components[4]),
              let totalCost = Double(components[5]) else {
            return nil
        }

        let isPartialFillUp = components.count > 6 ? components[6].lowercased() == "true" : false
        let notes = components.count > 7 && !components[7].isEmpty ? components[7] : nil

        return FuelingRecord(
            date: date,
            currentMiles: currentMiles,
            previousMiles: previousMiles,
            pricePerGallon: pricePerGallon,
            gallons: gallons,
            totalCost: totalCost,
            isPartialFillUp: isPartialFillUp,
            notes: notes
        )
    }

    private static func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false

        for char in row {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)

        return result
    }
}

