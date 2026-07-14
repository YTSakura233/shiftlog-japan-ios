import Foundation
import SwiftData

@MainActor enum DemoDataService {
    static func load(into context: ModelContext) {
        let calendar = Calendar.current
        let convenience = Job(displayName: String(localized: "demo.convenience"), employerName: "Demo Mart", colorHex: AppTheme.palette[0])
        convenience.defaultStartHour = 21; convenience.defaultEndHour = 2; convenience.defaultBreakMinutes = 15
        let restaurant = Job(displayName: String(localized: "demo.restaurant"), employerName: "Demo Kitchen", colorHex: AppTheme.palette[3])
        restaurant.defaultStartHour = 11; restaurant.defaultEndHour = 17; restaurant.defaultBreakMinutes = 30
        restaurant.transportKindRaw = TransportKind.perShift.rawValue; restaurant.transportAmount = 500
        context.insert(convenience); context.insert(restaurant)
        context.insert(WageRate(jobID: convenience.id, hourlyAmount: 1_200))
        context.insert(WageRate(jobID: restaurant.id, hourlyAmount: 1_300))
        let night = PremiumRule(jobID: convenience.id, name: "Deep Night 22:00–05:00", percentage: Decimal(string: "0.25")!)
        night.startMinutesFromMidnight = 1_320; night.endMinutesFromMidnight = 300; night.priority = 100
        context.insert(night)

        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        for day in [0, 2, 4] {
            let date = calendar.date(byAdding: .day, value: day, to: weekStart)!
            let start = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: date)!
            let end = calendar.date(byAdding: .hour, value: 4, to: start)!
            let shift = Shift(jobID: convenience.id, scheduledStart: start, scheduledEnd: end)
            shift.transportAmount = 0; context.insert(shift)
            context.insert(ShiftBreak(shiftID: shift.id, isActual: false, start: start.addingTimeInterval(2.5 * 3_600), end: start.addingTimeInterval(2.75 * 3_600)))
        }
        for day in [1, 3, 5] {
            let date = calendar.date(byAdding: .day, value: day, to: weekStart)!
            let start = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: date)!
            let end = calendar.date(byAdding: .hour, value: 6, to: start)!
            let shift = Shift(jobID: restaurant.id, scheduledStart: start, scheduledEnd: end)
            shift.transportAmount = 500; context.insert(shift)
            context.insert(ShiftBreak(shiftID: shift.id, isActual: false, start: start.addingTimeInterval(3 * 3_600), end: start.addingTimeInterval(3.5 * 3_600)))
        }
        let payment = Payment(jobID: restaurant.id, periodStart: Date().startOfMonth, periodEnd: Date())
        payment.estimatedLabor = 52_000; payment.grossAmount = 51_700; payment.deductions = 2_000; payment.receivedAmount = 49_700; payment.receivedDate = Date()
        context.insert(payment); try? context.save()
    }
}
