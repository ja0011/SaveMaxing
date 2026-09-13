import Foundation

enum MockFinancialData {
    static let user = User(
        id: UUID(uuidString: "8F1C2BA7-74E5-4872-8E15-B795B69A1001")!,
        name: "Maya Johnson",
        email: "maya@savemaxing.demo"
    )

    static let tvGoal = SavingsGoal(
        id: UUID(uuidString: "6A69DC23-E4A7-441B-9129-45BDB61D9343")!,
        name: "TV Fund",
        targetAmount: 1000,
        currentAmount: 640,
        deadline: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 30)) ?? Date().addingTimeInterval(18 * 86_400),
        createdAt: Calendar.current.date(byAdding: .day, value: -26, to: Date()) ?? Date(),
        kind: .savings,
        currentLabel: "saved",
        stake: nil
    )

    static let eatingOutGoal = SavingsGoal(
        id: UUID(uuidString: "29B57DC1-A60F-4D8C-B12B-FC0751202324")!,
        name: "Eating Out Limit",
        targetAmount: 250,
        currentAmount: 185,
        deadline: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 21)) ?? Date().addingTimeInterval(9 * 86_400),
        createdAt: Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date(),
        kind: .spendingLimit,
        currentLabel: "spent",
        stake: nil
    )

    static let habitGoal = SavingsGoal(
        id: UUID(uuidString: "622E74B6-6EEA-4557-81F0-6F4FAFE91D58")!,
        name: "No Takeout",
        targetAmount: 30,
        currentAmount: 11,
        deadline: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1)) ?? Date().addingTimeInterval(19 * 86_400),
        createdAt: Calendar.current.date(byAdding: .day, value: -11, to: Date()) ?? Date(),
        kind: .habit,
        currentLabel: "days complete",
        stake: nil
    )

    static let goals = [tvGoal, eatingOutGoal, habitGoal]

    static let accounts: [Account] = [
        Account(id: UUID(), name: "360 Checking", type: .checking, balance: 2480.45, institutionName: "Capital One"),
        Account(id: UUID(), name: "Performance Savings", type: .savings, balance: 2340.00, institutionName: "Capital One"),
        Account(id: UUID(), name: "Quicksilver", type: .credit, balance: -184.33, institutionName: "Capital One")
    ]

    static let categories: [SpendingCategory] = [
        SpendingCategory(kind: .dining, amount: 210, budget: 175),
        SpendingCategory(kind: .shopping, amount: 185, budget: 140),
        SpendingCategory(kind: .transportation, amount: 140, budget: 160),
        SpendingCategory(kind: .entertainment, amount: 95, budget: 70),
        SpendingCategory(kind: .groceries, amount: 320, budget: 340)
    ]

    static let subscriptions: [Subscription] = [
        Subscription(id: UUID(), merchantName: "Netflix", monthlyAmount: 22.99, category: .entertainment, nextBillingDate: date(month: 9, day: 16)),
        Subscription(id: UUID(), merchantName: "Spotify", monthlyAmount: 11.99, category: .entertainment, nextBillingDate: date(month: 9, day: 18)),
        Subscription(id: UUID(), merchantName: "iCloud", monthlyAmount: 2.99, category: .subscriptions, nextBillingDate: date(month: 9, day: 20)),
        Subscription(id: UUID(), merchantName: "Gym", monthlyAmount: 35.00, category: .subscriptions, nextBillingDate: date(month: 9, day: 24))
    ]

    static let recentTransactions: [Transaction] = [
        Transaction(id: UUID(), merchantName: "McDonald's", amount: 12.48, date: date(month: 9, day: 12), category: .dining, accountName: "360 Checking"),
        Transaction(id: UUID(), merchantName: "Whole Foods", amount: 42.18, date: date(month: 9, day: 12), category: .groceries, accountName: "360 Checking"),
        Transaction(id: UUID(), merchantName: "Steam", amount: 19.99, date: date(month: 9, day: 11), category: .entertainment, accountName: "Quicksilver"),
        Transaction(id: UUID(), merchantName: "Prime Steakhouse", amount: 92.40, date: date(month: 9, day: 10), category: .dining, accountName: "Quicksilver"),
        Transaction(id: UUID(), merchantName: "Target", amount: 38.11, date: date(month: 9, day: 9), category: .shopping, accountName: "360 Checking")
    ]

    static let savingsImpact = SavingsImpact(purchasesResisted: 4, moneyProtected: 87.42)

    static let demoMonthTransactions: [[Transaction]] = [
        [
            Transaction(id: UUID(), merchantName: "Payroll Deposit", amount: -3110.00, date: date(year: 2025, month: 10, day: 1), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer to Savings", amount: 125.00, date: date(year: 2025, month: 10, day: 2), category: .savings, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer from Checking", amount: -125.00, date: date(year: 2025, month: 10, day: 2), category: .savings, accountName: "Performance Savings"),
            Transaction(id: UUID(), merchantName: "Rent", amount: 1850.00, date: date(year: 2025, month: 10, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Utilities", amount: 218.40, date: date(year: 2025, month: 10, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Phone Bill", amount: 84.99, date: date(year: 2025, month: 10, day: 5), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Student Loan", amount: 420.00, date: date(year: 2025, month: 10, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Campus Cafe", amount: 9.80, date: date(year: 2025, month: 10, day: 7), category: .dining, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Whole Foods", amount: 36.44, date: date(year: 2025, month: 10, day: 9), category: .groceries, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Target", amount: 42.17, date: date(year: 2025, month: 10, day: 12), category: .shopping, accountName: "360 Checking")
        ],
        [
            Transaction(id: UUID(), merchantName: "Payroll Deposit", amount: -3120.00, date: date(year: 2025, month: 11, day: 1), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer to Savings", amount: 135.00, date: date(year: 2025, month: 11, day: 2), category: .savings, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer from Checking", amount: -135.00, date: date(year: 2025, month: 11, day: 2), category: .savings, accountName: "Performance Savings"),
            Transaction(id: UUID(), merchantName: "Rent", amount: 1850.00, date: date(year: 2025, month: 11, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Utilities", amount: 231.18, date: date(year: 2025, month: 11, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Phone Bill", amount: 84.99, date: date(year: 2025, month: 11, day: 5), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Student Loan", amount: 420.00, date: date(year: 2025, month: 11, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Campus Bookstore", amount: 318.42, date: date(year: 2025, month: 11, day: 8), category: .shopping, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "DoorDash", amount: 28.64, date: date(year: 2025, month: 11, day: 5), category: .dining, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Spotify", amount: 11.99, date: date(year: 2025, month: 11, day: 7), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Steam", amount: 19.99, date: date(year: 2025, month: 11, day: 11), category: .entertainment, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Campus Cafe", amount: 13.20, date: date(year: 2025, month: 11, day: 16), category: .dining, accountName: "360 Checking")
        ],
        [
            Transaction(id: UUID(), merchantName: "Payroll Deposit", amount: -3180.00, date: date(year: 2025, month: 12, day: 1), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer to Savings", amount: 155.00, date: date(year: 2025, month: 12, day: 2), category: .savings, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer from Checking", amount: -155.00, date: date(year: 2025, month: 12, day: 2), category: .savings, accountName: "Performance Savings"),
            Transaction(id: UUID(), merchantName: "Rent", amount: 1850.00, date: date(year: 2025, month: 12, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Utilities", amount: 246.75, date: date(year: 2025, month: 12, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Phone Bill", amount: 84.99, date: date(year: 2025, month: 12, day: 5), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Student Loan", amount: 420.00, date: date(year: 2025, month: 12, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Holiday Gifts", amount: 684.15, date: date(year: 2025, month: 12, day: 18), category: .shopping, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Netflix", amount: 22.99, date: date(year: 2025, month: 12, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Chipotle", amount: 15.80, date: date(year: 2025, month: 12, day: 8), category: .dining, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Whole Foods", amount: 58.22, date: date(year: 2025, month: 12, day: 14), category: .groceries, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Lyft", amount: 18.45, date: date(year: 2025, month: 12, day: 20), category: .transportation, accountName: "Quicksilver")
        ],
        [
            Transaction(id: UUID(), merchantName: "Payroll Deposit", amount: -3140.00, date: date(year: 2026, month: 1, day: 1), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer to Savings", amount: 155.00, date: date(year: 2026, month: 1, day: 2), category: .savings, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer from Checking", amount: -155.00, date: date(year: 2026, month: 1, day: 2), category: .savings, accountName: "Performance Savings"),
            Transaction(id: UUID(), merchantName: "Rent", amount: 1850.00, date: date(year: 2026, month: 1, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Utilities", amount: 224.10, date: date(year: 2026, month: 1, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Phone Bill", amount: 84.99, date: date(year: 2026, month: 1, day: 5), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Student Loan", amount: 420.00, date: date(year: 2026, month: 1, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Campus Cafe", amount: 16.40, date: date(year: 2026, month: 1, day: 6), category: .dining, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Gym", amount: 35.00, date: date(year: 2026, month: 1, day: 8), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Amazon", amount: 64.19, date: date(year: 2026, month: 1, day: 15), category: .shopping, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Trader Joe's", amount: 47.03, date: date(year: 2026, month: 1, day: 22), category: .groceries, accountName: "360 Checking")
        ],
        [
            Transaction(id: UUID(), merchantName: "Payroll Deposit", amount: -3160.00, date: date(year: 2026, month: 2, day: 1), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer to Savings", amount: 125.00, date: date(year: 2026, month: 2, day: 2), category: .savings, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer from Checking", amount: -125.00, date: date(year: 2026, month: 2, day: 2), category: .savings, accountName: "Performance Savings"),
            Transaction(id: UUID(), merchantName: "Rent", amount: 1850.00, date: date(year: 2026, month: 2, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Utilities", amount: 236.80, date: date(year: 2026, month: 2, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Phone Bill", amount: 84.99, date: date(year: 2026, month: 2, day: 5), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Student Loan", amount: 420.00, date: date(year: 2026, month: 2, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Car Repair", amount: 742.30, date: date(year: 2026, month: 2, day: 21), category: .transportation, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "DoorDash", amount: 34.18, date: date(year: 2026, month: 2, day: 4), category: .dining, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Spotify", amount: 11.99, date: date(year: 2026, month: 2, day: 7), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Movie Theater", amount: 28.50, date: date(year: 2026, month: 2, day: 13), category: .entertainment, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Target", amount: 73.10, date: date(year: 2026, month: 2, day: 18), category: .shopping, accountName: "360 Checking")
        ],
        [
            Transaction(id: UUID(), merchantName: "Payroll Deposit", amount: -3150.00, date: date(year: 2026, month: 3, day: 1), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer to Savings", amount: 90.00, date: date(year: 2026, month: 3, day: 2), category: .savings, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer from Checking", amount: -90.00, date: date(year: 2026, month: 3, day: 2), category: .savings, accountName: "Performance Savings"),
            Transaction(id: UUID(), merchantName: "Rent", amount: 1850.00, date: date(year: 2026, month: 3, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Utilities", amount: 241.25, date: date(year: 2026, month: 3, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Phone Bill", amount: 84.99, date: date(year: 2026, month: 3, day: 5), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Student Loan", amount: 420.00, date: date(year: 2026, month: 3, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Spring Break Hotel", amount: 640.00, date: date(year: 2026, month: 3, day: 18), category: .entertainment, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Prime Steakhouse", amount: 86.40, date: date(year: 2026, month: 3, day: 5), category: .dining, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Netflix", amount: 22.99, date: date(year: 2026, month: 3, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Shell", amount: 38.70, date: date(year: 2026, month: 3, day: 12), category: .transportation, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Whole Foods", amount: 61.81, date: date(year: 2026, month: 3, day: 17), category: .groceries, accountName: "360 Checking")
        ],
        [
            Transaction(id: UUID(), merchantName: "Payroll Deposit", amount: -3190.00, date: date(year: 2026, month: 4, day: 1), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer to Savings", amount: 115.00, date: date(year: 2026, month: 4, day: 2), category: .savings, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer from Checking", amount: -115.00, date: date(year: 2026, month: 4, day: 2), category: .savings, accountName: "Performance Savings"),
            Transaction(id: UUID(), merchantName: "Tax Refund", amount: -780.00, date: date(year: 2026, month: 4, day: 2), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Rent", amount: 1850.00, date: date(year: 2026, month: 4, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Utilities", amount: 205.35, date: date(year: 2026, month: 4, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Phone Bill", amount: 84.99, date: date(year: 2026, month: 4, day: 5), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Student Loan", amount: 420.00, date: date(year: 2026, month: 4, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "DoorDash", amount: 42.55, date: date(year: 2026, month: 4, day: 2), category: .dining, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "iCloud", amount: 2.99, date: date(year: 2026, month: 4, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Steam", amount: 39.99, date: date(year: 2026, month: 4, day: 11), category: .entertainment, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Target", amount: 52.26, date: date(year: 2026, month: 4, day: 19), category: .shopping, accountName: "360 Checking")
        ],
        [
            Transaction(id: UUID(), merchantName: "Payroll Deposit", amount: -3200.00, date: date(year: 2026, month: 5, day: 1), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer to Savings", amount: 125.00, date: date(year: 2026, month: 5, day: 2), category: .savings, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer from Checking", amount: -125.00, date: date(year: 2026, month: 5, day: 2), category: .savings, accountName: "Performance Savings"),
            Transaction(id: UUID(), merchantName: "Rent", amount: 1850.00, date: date(year: 2026, month: 5, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Utilities", amount: 198.20, date: date(year: 2026, month: 5, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Phone Bill", amount: 84.99, date: date(year: 2026, month: 5, day: 5), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Student Loan", amount: 420.00, date: date(year: 2026, month: 5, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Campus Cafe", amount: 18.10, date: date(year: 2026, month: 5, day: 3), category: .dining, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Gym", amount: 35.00, date: date(year: 2026, month: 5, day: 8), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Lyft", amount: 24.90, date: date(year: 2026, month: 5, day: 14), category: .transportation, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Trader Joe's", amount: 55.70, date: date(year: 2026, month: 5, day: 22), category: .groceries, accountName: "360 Checking")
        ],
        [
            Transaction(id: UUID(), merchantName: "Payroll Deposit", amount: -3180.00, date: date(year: 2026, month: 6, day: 1), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer to Savings", amount: 65.00, date: date(year: 2026, month: 6, day: 2), category: .savings, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer from Checking", amount: -65.00, date: date(year: 2026, month: 6, day: 2), category: .savings, accountName: "Performance Savings"),
            Transaction(id: UUID(), merchantName: "Rent", amount: 1850.00, date: date(year: 2026, month: 6, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Utilities", amount: 226.95, date: date(year: 2026, month: 6, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Phone Bill", amount: 84.99, date: date(year: 2026, month: 6, day: 5), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Student Loan", amount: 420.00, date: date(year: 2026, month: 6, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Summer Tuition", amount: 1290.00, date: date(year: 2026, month: 6, day: 9), category: .shopping, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Emergency Dental", amount: 2300.00, date: date(year: 2026, month: 6, day: 14), category: .shopping, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "DoorDash", amount: 49.72, date: date(year: 2026, month: 6, day: 5), category: .dining, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Spotify", amount: 11.99, date: date(year: 2026, month: 6, day: 7), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Amazon", amount: 81.35, date: date(year: 2026, month: 6, day: 15), category: .shopping, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Movie Theater", amount: 34.25, date: date(year: 2026, month: 6, day: 23), category: .entertainment, accountName: "Quicksilver")
        ],
        [
            Transaction(id: UUID(), merchantName: "Payroll Deposit", amount: -3220.00, date: date(year: 2026, month: 7, day: 1), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer to Savings", amount: 125.00, date: date(year: 2026, month: 7, day: 2), category: .savings, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer from Checking", amount: -125.00, date: date(year: 2026, month: 7, day: 2), category: .savings, accountName: "Performance Savings"),
            Transaction(id: UUID(), merchantName: "Rent", amount: 1850.00, date: date(year: 2026, month: 7, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Utilities", amount: 238.44, date: date(year: 2026, month: 7, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Phone Bill", amount: 84.99, date: date(year: 2026, month: 7, day: 5), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Student Loan", amount: 420.00, date: date(year: 2026, month: 7, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Campus Cafe", amount: 21.40, date: date(year: 2026, month: 7, day: 3), category: .dining, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Netflix", amount: 22.99, date: date(year: 2026, month: 7, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Whole Foods", amount: 72.18, date: date(year: 2026, month: 7, day: 12), category: .groceries, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Target", amount: 66.42, date: date(year: 2026, month: 7, day: 18), category: .shopping, accountName: "Quicksilver")
        ],
        [
            Transaction(id: UUID(), merchantName: "Payroll Deposit", amount: -3200.00, date: date(year: 2026, month: 8, day: 1), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer to Savings", amount: 95.00, date: date(year: 2026, month: 8, day: 2), category: .savings, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer from Checking", amount: -95.00, date: date(year: 2026, month: 8, day: 2), category: .savings, accountName: "Performance Savings"),
            Transaction(id: UUID(), merchantName: "Rent", amount: 1850.00, date: date(year: 2026, month: 8, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Utilities", amount: 251.60, date: date(year: 2026, month: 8, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Phone Bill", amount: 84.99, date: date(year: 2026, month: 8, day: 5), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Student Loan", amount: 420.00, date: date(year: 2026, month: 8, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Moving Supplies", amount: 388.70, date: date(year: 2026, month: 8, day: 14), category: .shopping, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "DoorDash", amount: 58.84, date: date(year: 2026, month: 8, day: 4), category: .dining, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Prime Steakhouse", amount: 92.40, date: date(year: 2026, month: 8, day: 10), category: .dining, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Gym", amount: 35.00, date: date(year: 2026, month: 8, day: 12), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Shell", amount: 41.55, date: date(year: 2026, month: 8, day: 20), category: .transportation, accountName: "Quicksilver")
        ],
        [
            Transaction(id: UUID(), merchantName: "Payroll Deposit", amount: -3200.00, date: date(year: 2026, month: 9, day: 1), category: .income, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer to Savings", amount: 205.00, date: date(year: 2026, month: 9, day: 2), category: .savings, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Auto Transfer from Checking", amount: -205.00, date: date(year: 2026, month: 9, day: 2), category: .savings, accountName: "Performance Savings"),
            Transaction(id: UUID(), merchantName: "Rent", amount: 1850.00, date: date(year: 2026, month: 9, day: 3), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Utilities", amount: 212.10, date: date(year: 2026, month: 9, day: 4), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Phone Bill", amount: 84.99, date: date(year: 2026, month: 9, day: 5), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Student Loan", amount: 420.00, date: date(year: 2026, month: 9, day: 6), category: .subscriptions, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "McDonald's", amount: 12.48, date: date(month: 9, day: 12), category: .dining, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Whole Foods", amount: 42.18, date: date(month: 9, day: 12), category: .groceries, accountName: "360 Checking"),
            Transaction(id: UUID(), merchantName: "Steam", amount: 19.99, date: date(month: 9, day: 11), category: .entertainment, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Prime Steakhouse", amount: 92.40, date: date(month: 9, day: 10), category: .dining, accountName: "Quicksilver"),
            Transaction(id: UUID(), merchantName: "Target", amount: 38.11, date: date(month: 9, day: 9), category: .shopping, accountName: "360 Checking")
        ]
    ]

    static let demoMonthSavingsImpact: [SavingsImpact] = [
        SavingsImpact(purchasesResisted: 0, moneyProtected: 0),
        SavingsImpact(purchasesResisted: 1, moneyProtected: 28.64),
        SavingsImpact(purchasesResisted: 1, moneyProtected: 28.64),
        SavingsImpact(purchasesResisted: 2, moneyProtected: 44.44),
        SavingsImpact(purchasesResisted: 2, moneyProtected: 44.44),
        SavingsImpact(purchasesResisted: 3, moneyProtected: 86.99),
        SavingsImpact(purchasesResisted: 3, moneyProtected: 86.99),
        SavingsImpact(purchasesResisted: 4, moneyProtected: 105.09),
        SavingsImpact(purchasesResisted: 5, moneyProtected: 154.81),
        SavingsImpact(purchasesResisted: 5, moneyProtected: 154.81),
        SavingsImpact(purchasesResisted: 6, moneyProtected: 213.65),
        SavingsImpact(purchasesResisted: 7, moneyProtected: 306.05)
    ]

    private static func date(month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day)) ?? Date()
    }

    private static func date(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
