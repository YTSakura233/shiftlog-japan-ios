import XCTest

@MainActor final class ShiftLogJapanUITests: XCTestCase {
    private func launch(locale: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launchEnvironment["UITEST_LOCALE"] = locale
        app.launchArguments += ["-AppleLanguages", "(\(locale))", "-AppleLocale", locale]
        app.launch()
        return app
    }

    func testOnboardingOrMainInterfaceLaunches() {
        let app = launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.buttons.count, 0)
    }

    func testEarningsRangeTitlesAreLocalizedInAllLanguages() {
        let cases = [
            ("zh-Hans", ["日", "周", "月", "年", "自定义"]),
            ("ja", ["日", "週", "月", "年", "期間指定"]),
            ("en", ["Day", "Week", "Month", "Year", "Custom"])
        ]
        for (locale, expectedTitles) in cases {
            let app = launch(locale: locale)
            app.tabBars.buttons.element(boundBy: 1).tap()
            for (range, expectedTitle) in zip(["day", "week", "month", "year", "custom"], expectedTitles) {
                let button = app.buttons["earnings.range.\(range)"]
                XCTAssertTrue(button.waitForExistence(timeout: 2))
                XCTAssertEqual(button.label, expectedTitle)
                XCTAssertFalse(button.label.hasPrefix("range."))
            }
            app.terminate()
        }
    }

    func testCalendarDayOpensDetailAndUsesSingleDayEditor() {
        let app = launch()
        let todayID = calendarDayID(Date())
        let day = app.buttons[todayID]
        XCTAssertTrue(day.waitForExistence(timeout: 3))
        day.tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendar.day.detail"].waitForExistence(timeout: 2))
        app.buttons["calendar.day.add"].tap()
        XCTAssertTrue(app.switches["shift.crossDay"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.switches["shift.crossDay"].value as? String, "0")
        XCTAssertTrue(app.datePickers["shift.start"].exists)
        XCTAssertTrue(app.datePickers["shift.end"].exists)
    }

    func testEmptyAndAdjacentMonthDaysOpenDetails() throws {
        let app = launch()
        let calendar = Calendar.current
        let today = Date()
        let month = try XCTUnwrap(calendar.dateInterval(of: .month, for: today))
        let firstDay = month.start
        let emptyDay = calendar.isDate(firstDay, inSameDayAs: today)
            ? try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDay))
            : firstDay

        let emptyCell = app.buttons[calendarDayID(emptyDay)]
        XCTAssertTrue(emptyCell.waitForExistence(timeout: 3))
        emptyCell.tap()
        XCTAssertTrue(app.buttons["calendar.day.add"].waitForExistence(timeout: 2))
        app.navigationBars.buttons["Close"].tap()

        let nextMonthFirstDay = month.end
        let adjacentCell = app.buttons[calendarDayID(nextMonthFirstDay)]
        XCTAssertTrue(adjacentCell.waitForExistence(timeout: 3))
        adjacentCell.tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendar.day.detail"].waitForExistence(timeout: 2))
    }

    func testConflictAndWageErrorsAppearInSummary() {
        let app = launch()
        app.buttons["shift.add"].tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["form.error.summary"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["View conflicting shift"].exists)
        app.navigationBars.buttons["Cancel"].tap()

        app.tabBars.buttons.element(boundBy: 2).tap()
        app.buttons["job.add"].tap()
        let wage = app.textFields["job.field.wage"]
        XCTAssertTrue(wage.waitForExistence(timeout: 2))
        wage.tap()
        wage.clearText()
        wage.typeText("0")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["form.error.summary"].waitForExistence(timeout: 2))
    }
}

private func calendarDayID(_ date: Date) -> String {
    "calendar.day.\(date.formatted(.iso8601.year().month().day()))"
}

private extension XCUIElement {
    func clearText() {
        guard let value = value as? String else { return }
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
    }
}
