import XCTest

@MainActor final class ShiftLogJapanUITests: XCTestCase {
    private func launch(locale: String = "en", limitBreach: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launchEnvironment["UITEST_LOCALE"] = locale
        app.launchEnvironment["UITEST_DISABLE_SPLASH"] = "1"
        if limitBreach { app.launchEnvironment["UITEST_LIMIT_BREACH"] = "1" }
        app.launchArguments += ["-AppleLanguages", "(\(locale))", "-AppleLocale", locale]
        app.launch()
        return app
    }

    private func launchOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launchEnvironment["UITEST_ONBOARDING"] = "1"
        app.launchEnvironment["UITEST_LOCALE"] = "zh-Hans"
        app.launchEnvironment["UITEST_DISABLE_SPLASH"] = "1"
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
            (option: "繁體中文", languageTitle: "選擇介面語言", continueTitle: "繼續", purposeTitle: "你的主要用途", calendarTitle: "日曆"),
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
            ("zh-Hant", ["日", "週", "月", "薪資週期", "年", "自訂"]),
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

    func testExceededHourRangeIsMarkedOnCalendar() {
        let app = launch(limitBreach: true)

        XCTAssertTrue(app.descendants(matching: .any)["calendar.limit.exceeded.legend"].waitForExistence(timeout: 3))
        let today = app.buttons[calendarDayID(Date())]
        XCTAssertTrue(today.waitForExistence(timeout: 3))
        XCTAssertTrue(today.label.contains("This date is within a period above your hour setting"))
    }

    func testFloatingAddShiftButtonOnlyAppearsOnCalendarTab() {
        let app = launch()
        XCTAssertTrue(app.buttons["shift.add"].waitForExistence(timeout: 3))

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertFalse(app.buttons["shift.add"].exists)
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertFalse(app.buttons["shift.add"].exists)
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertFalse(app.buttons["shift.add"].exists)

        app.tabBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["shift.add"].waitForExistence(timeout: 2))
    }

    func testSupportLinksAndDonationCodesAreReachable() {
        let app = launch(locale: "zh-Hans")
        app.tabBars.buttons.element(boundBy: 3).tap()

        let donate = app.buttons["settings.donate"]
        for _ in 0..<10 where !donate.isHittable { app.swipeUp() }
        XCTAssertTrue(app.descendants(matching: .any)["settings.github"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.website"].exists)
        XCTAssertTrue(donate.waitForExistence(timeout: 3))
        donate.tap()

        XCTAssertTrue(app.images["donation.qr.alipay"].waitForExistence(timeout: 3))
        app.segmentedControls.buttons["微信"].tap()
        XCTAssertTrue(app.images["donation.qr.wechat"].waitForExistence(timeout: 3))
    }

    func testMonthlyPDFExportIsAvailableFromEarnings() {
        let app = launch(locale: "zh-Hant")
        app.tabBars.buttons.element(boundBy: 1).tap()

        let exportButton = app.buttons["report.exportPDF"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 3))
        XCTAssertEqual(exportButton.label, "匯出 PDF 月報")
    }

    func testExistingShiftCanBeDeleted() {
        let app = launch()
        let dayView = app.segmentedControls.buttons["Day"]
        XCTAssertTrue(dayView.waitForExistence(timeout: 3))
        dayView.tap()

        let shiftRow = app.buttons["calendar.day.shift"].firstMatch
        XCTAssertTrue(shiftRow.waitForExistence(timeout: 3))
        shiftRow.tap()

        let deleteButton = app.buttons["shift.delete"]
        for _ in 0..<8 where !deleteButton.isHittable { app.swipeUp() }
        XCTAssertTrue(deleteButton.isHittable)
        deleteButton.tap()
        let deleteAlert = app.alerts["Delete this shift?"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 2))
        let confirmation = deleteAlert.buttons["shift.delete.confirmAction"].firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        confirmation.tap()

        XCTAssertTrue(shiftRow.waitForNonExistence(timeout: 3))
    }

    func testCalendarPeriodsCanBeChangedByHorizontalSwipe() {
        let app = launch()
        let title = app.staticTexts["calendar.period.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        let originalMonth = title.label
        app.scrollViews.firstMatch.swipeLeft()
        XCTAssertNotEqual(title.label, originalMonth)

        let week = app.segmentedControls.buttons["Week"]
        XCTAssertTrue(week.waitForExistence(timeout: 2))
        week.tap()
        XCTAssertTrue(app.staticTexts["calendar.period.subtitle"].waitForExistence(timeout: 2))
        let originalWeek = title.label
        app.scrollViews.firstMatch.swipeLeft()
        XCTAssertNotEqual(title.label, originalWeek)
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

    func testP1LocalToolsAreReachableFromSettings() {
        let app = launch(locale: "zh-Hans")
        app.tabBars.buttons.element(boundBy: 3).tap()

        let credentials = app.buttons["证件与许可提醒"]
        for _ in 0..<6 where !credentials.isHittable { app.swipeUp() }
        XCTAssertTrue(credentials.waitForExistence(timeout: 3))
        let documents = app.buttons["工资与工作资料"]
        XCTAssertTrue(documents.exists)
        documents.tap()
        XCTAssertTrue(app.descendants(matching: .any)["工资单"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["document.type.payslip"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(credentials.waitForExistence(timeout: 3))
        credentials.tap()
        XCTAssertTrue(app.buttons["新增提醒"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let help = app.buttons["需要帮助"]
        XCTAssertTrue(help.waitForExistence(timeout: 3))
        help.tap()
        XCTAssertTrue(app.staticTexts["官方信息入口"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["工资单常见词汇"].exists)
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
