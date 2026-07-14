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

    private func launchOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launchEnvironment["UITEST_ONBOARDING"] = "1"
        app.launchEnvironment["UITEST_LOCALE"] = "zh-Hans"
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh-Hans"]
        app.launch()
        return app
    }

    func testOnboardingOrMainInterfaceLaunches() {
        let app = launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.buttons.count, 0)
    }

    func testOnboardingLanguageSelectionUpdatesCurrentAndFollowingPages() {
        let cases = [
            (option: "简体中文", languageTitle: "选择界面语言", continueTitle: "继续", purposeTitle: "你的主要用途", calendarTitle: "日历"),
            (option: "日本語", languageTitle: "表示言語を選択", continueTitle: "次へ", purposeTitle: "主な利用目的", calendarTitle: "カレンダー"),
            (option: "English", languageTitle: "Choose a language", continueTitle: "Continue", purposeTitle: "How will you use the app?", calendarTitle: "Calendar")
        ]

        for item in cases {
            let app = launchOnboarding()
            let option = app.buttons[item.option]
            XCTAssertTrue(option.waitForExistence(timeout: 3))
            option.tap()

            let languageTitle = app.staticTexts["onboarding.language.title"]
            XCTAssertTrue(languageTitle.waitForExistence(timeout: 2))
            XCTAssertEqual(languageTitle.label, item.languageTitle)
            let continueButton = app.buttons["onboarding.continue"]
            XCTAssertEqual(continueButton.label, item.continueTitle)
            continueButton.tap()

            let purposeTitle = app.staticTexts["onboarding.purpose.title"]
            XCTAssertTrue(purposeTitle.waitForExistence(timeout: 2))
            XCTAssertEqual(purposeTitle.label, item.purposeTitle)

            continueButton.tap()
            continueButton.tap()
            let jobName = app.textFields["onboarding.job.name"]
            XCTAssertTrue(jobName.waitForExistence(timeout: 2))
            jobName.tap()
            jobName.typeText("Test Job")
            continueButton.tap()
            XCTAssertTrue(app.tabBars.buttons[item.calendarTitle].waitForExistence(timeout: 3))
            app.terminate()
        }
    }

    func testEarningsRangeTitlesAreLocalizedInAllLanguages() {
        let cases = [
            ("zh-Hans", ["日", "周", "月", "工资周期", "年", "自定义"]),
            ("ja", ["日", "週", "月", "給与期間", "年", "期間指定"]),
            ("en", ["Day", "Week", "Month", "Pay period", "Year", "Custom"])
        ]
        for (locale, expectedTitles) in cases {
            let app = launch(locale: locale)
            app.tabBars.buttons.element(boundBy: 1).tap()
            for (range, expectedTitle) in zip(["day", "week", "month", "payPeriod", "year", "custom"], expectedTitles) {
                let button = app.buttons["earnings.range.\(range)"]
                XCTAssertTrue(button.waitForExistence(timeout: 2))
                XCTAssertEqual(button.label, expectedTitle)
                XCTAssertFalse(button.label.hasPrefix("range."))
            }
            app.terminate()
        }
    }

    func testShiftEditorSupportsMultipleScheduledBreaks() {
        let app = launch()
        app.buttons["shift.add"].tap()

        let addBreak = app.buttons["shift.break.add.scheduled"]
        XCTAssertTrue(addBreak.waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["shift.break.scheduled.0"].exists)
        for _ in 0..<4 where !addBreak.isHittable { app.swipeUp() }
        XCTAssertTrue(addBreak.isHittable)
        addBreak.tap()
        XCTAssertTrue(app.descendants(matching: .any)["shift.break.scheduled.1"].waitForExistence(timeout: 4))
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
