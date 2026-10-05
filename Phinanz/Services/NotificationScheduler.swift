//
//  NotificationScheduler.swift
//  Phinanz
//
//  Optional local reminders: a daily "write down today's spending" nudge and
//  a reminder the evening before each recurring payment. Nothing leaves the device.
//

import Foundation
import SwiftData
import UserNotifications

enum NotificationScheduler {
    static let dailyIdentifier = "daily-reminder"
    static let paymentPrefix = "payment-"

    /// Asks for permission if needed. Returns whether notifications are allowed.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Rebuilds all pending PHINANZ reminders from the current settings and data.
    @MainActor
    static func refresh(context: ModelContext, now: Date = Date(), calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        let defaults = UserDefaults.standard
        let daily = defaults.bool(forKey: SettingsKeys.dailyReminder)
        let payments = defaults.bool(forKey: SettingsKeys.paymentReminders)

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0 == dailyIdentifier || $0.hasPrefix(paymentPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard daily || payments else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        if daily {
            let minutes = defaults.object(forKey: SettingsKeys.dailyReminderMinutes) as? Int ?? 20 * 60
            var components = DateComponents()
            components.hour = minutes / 60
            components.minute = minutes % 60
            let content = UNMutableNotificationContent()
            content.title = String(localized: "PHINANZ")
            content.body = String(localized: "Did you write down today's spending?")
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: dailyIdentifier, content: content, trigger: trigger))
        }

        if payments {
            let descriptor = FetchDescriptor<RecurringPayment>(predicate: #Predicate { $0.isActive })
            let active = (try? context.fetch(descriptor)) ?? []
            for payment in active {
                for reminder in reminderDates(for: payment, now: now, calendar: calendar) {
                    let content = UNMutableNotificationContent()
                    content.title = payment.isIncome
                        ? String(localized: "Income expected tomorrow")
                        : String(localized: "Payment due tomorrow")
                    // No amount on the Lock Screen: the name is enough of a reminder.
                    content.body = payment.name
                    content.sound = .default
                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let identifier = "\(paymentPrefix)\(payment.persistentModelID.hashValue)-\(Int(reminder.timeIntervalSince1970))"
                    try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
                }
            }
        }
    }

    /// 18:00 on the day before each due date in the next 60 days.
    static func reminderDates(for payment: RecurringPayment, now: Date, calendar: Calendar = .current) -> [Date] {
        reminderDates(
            start: payment.startDate,
            dayOfMonth: payment.dayOfMonth,
            now: now,
            calendar: calendar
        )
    }

    static func reminderDates(start: Date, dayOfMonth: Int, now: Date, calendar: Calendar = .current) -> [Date] {
        let horizon = calendar.date(byAdding: .day, value: 60, to: now) ?? now
        let dues = RecurringScheduler.dueDates(
            start: max(start, now),
            dayOfMonth: dayOfMonth,
            lastGenerated: now,
            now: horizon,
            calendar: calendar
        )
        return dues.compactMap { due in
            guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: due),
                  let reminder = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayBefore),
                  reminder > now
            else { return nil }
            return reminder
        }
    }
}
