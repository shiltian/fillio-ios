import Foundation
import SwiftUI

// MARK: - Double Extensions

extension Double {
    /// Format as currency (e.g., $3.45)
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    /// Format with specific decimal places
    func formatted(decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is within this week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Check if date is within this month
    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    /// Get relative description (Today, Yesterday, or date)
    var relativeDescription: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            return formatted(date: .abbreviated, time: .omitted)
        }
    }

    /// Start of day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of day
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a modifier conditionally
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Hide keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Color Extensions

extension Color {
    /// Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - String Extensions

extension String {
    /// Check if string is a valid number
    var isNumeric: Bool {
        Double(self) != nil
    }

    /// Trim whitespace and newlines
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Decimal Input TextField (UIKit-based)

/// A UIKit-based TextField that automatically formats input with a fixed number of decimal places
/// For example, with 3 decimal places: typing "1" displays "0.001", typing "12" displays "0.012"
struct DecimalInputField<FocusValue: Hashable>: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let decimalPlaces: Int
    let focusedField: FocusState<FocusValue?>.Binding
    let fieldValue: FocusValue
    let onValueChanged: () -> Void

    init(
        placeholder: String,
        text: Binding<String>,
        decimalPlaces: Int,
        focusedField: FocusState<FocusValue?>.Binding,
        equals fieldValue: FocusValue,
        onValueChanged: @escaping () -> Void
    ) {
        self.placeholder = placeholder
        self._text = text
        self.decimalPlaces = decimalPlaces
        self.focusedField = focusedField
        self.fieldValue = fieldValue
        self.onValueChanged = onValueChanged
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.keyboardType = .numberPad
        textField.textAlignment = .right
        textField.delegate = context.coordinator
        textField.font = UIFont(name: "Avenir Next", size: 16)
        textField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Set initial value
        if let value = Double(text), value > 0 {
            textField.text = context.coordinator.formatValue(value)
        }

        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        // Update from external changes (e.g., auto-calculate)
        let expectedText: String
        if let value = Double(text), value > 0 {
            expectedText = context.coordinator.formatValue(value)
        } else {
            expectedText = ""
        }

        // Only update if not currently editing and value differs
        if !textField.isFirstResponder && textField.text != expectedText {
            textField.text = expectedText
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DecimalInputField
        private var rawDigits: String = ""

        var divisor: Double {
            pow(10.0, Double(parent.decimalPlaces))
        }

        init(_ parent: DecimalInputField) {
            self.parent = parent
            super.init()

            // Initialize rawDigits from existing value
            if let value = Double(parent.text), value > 0 {
                let intValue = Int(round(value * divisor))
                rawDigits = String(intValue)
            }
        }

        func formatValue(_ value: Double) -> String {
            return String(format: "%.\(parent.decimalPlaces)f", value)
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Handle backspace
            if string.isEmpty {
                if !rawDigits.isEmpty {
                    rawDigits.removeLast()
                }
            } else {
                // Only allow digits
                let digits = string.filter { $0.isNumber }
                rawDigits += digits
            }

            // Remove leading zeros
            while rawDigits.count > 1 && rawDigits.first == "0" {
                rawDigits.removeFirst()
            }

            // Update display
            if rawDigits.isEmpty {
                textField.text = ""
                parent.text = ""
            } else if let intValue = Int(rawDigits) {
                let doubleValue = Double(intValue) / divisor
                let formatted = formatValue(doubleValue)
                textField.text = formatted
                parent.text = formatted
            }

            parent.onValueChanged()

            // We handle the text change ourselves
            return false
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            // Sync rawDigits when starting to edit
            if let value = Double(parent.text), value > 0 {
                let intValue = Int(round(value * divisor))
                rawDigits = String(intValue)
            } else {
                rawDigits = ""
            }
        }
    }
}

// MARK: - Array Extensions

extension Array where Element == FuelingRecord {
    /// Get records within a date range
    func records(from startDate: Date, to endDate: Date) -> [FuelingRecord] {
        filter { $0.date >= startDate && $0.date <= endDate }
    }

    /// Get records for a specific month
    func records(forMonth date: Date) -> [FuelingRecord] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth) else {
            return []
        }
        return records(from: startOfMonth, to: endOfMonth)
    }

    /// Calculate total cost for records
    var totalCost: Double {
        reduce(0) { $0 + $1.totalCost }
    }

    /// Calculate total miles for records (using cached values)
    var totalMiles: Double {
        reduce(0) { $0 + $1.getMilesDriven() }
    }

    /// Calculate total gallons for records
    var totalGallons: Double {
        reduce(0) { $0 + $1.gallons }
    }
}

