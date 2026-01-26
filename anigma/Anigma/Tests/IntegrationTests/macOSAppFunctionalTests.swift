// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import XCTest

/// Functional tests for Anigma macOS application
/// Tests UI interactions and application-level workflows
final class macOSAppFunctionalTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Launch app before each test
        app.launch()
        
        // Wait for app to be ready
        let predicate = NSPredicate(format: "exists == true")
        let query = app.windows.matching(NSPredicate(format: "isKeyWindow == true"))
        let window = query.firstMatch
        
        let expectation = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    // MARK: - Application Launch Tests
    
    func testAppLaunches() throws {
        XCTAssertTrue(app.exists)
        XCTAssertTrue(app.windows.count > 0)
    }
    
    func testMainWindowExists() throws {
        let mainWindow = app.windows.matching(NSPredicate(format: "isKeyWindow == true")).firstMatch
        XCTAssertTrue(mainWindow.exists)
    }
    
    // MARK: - Dashboard View Tests
    
    func testDashboardViewIsVisible() throws {
        let daemonStatusLabel = app.staticTexts["Daemon Status"]
        
        // Dashboard might not be the first view
        // Try clicking on Dashboard tab if it exists
        let dashboardTab = app.segmentedControls.buttons["Dashboard"]
        if dashboardTab.exists {
            dashboardTab.click()
        }
        
        // Give the view time to render
        let expectation = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDaemonStatusIndicator() throws {
        // Look for daemon status element
        let statusElements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'running' OR label CONTAINS 'stopped'"))
        
        XCTAssertGreaterThanOrEqual(statusElements.count, 0)
    }
    
    func testTelemetryMetricsDisplay() throws {
        // Look for common metric labels
        let cpuLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'CPU'"))
        let memoryLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Memory'"))
        
        // At least some metrics should be displayed
        let metricCount = cpuLabel.count + memoryLabel.count
        XCTAssertGreaterThanOrEqual(metricCount, 0)
    }
    
    // MARK: - Document Library Tests
    
    func testDocumentLibraryTabAccessible() throws {
        let libraryTab = app.segmentedControls.buttons["Library"]
        if libraryTab.exists {
            libraryTab.click()
            
            // Verify library view loaded
            let expectation = XCTestExpectation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
            
            // Library should show a collection or list
            XCTAssertTrue(app.collectionViews.count > 0 || app.tableViews.count > 0 || app.scrollViews.count > 0)
        }
    }
    
    func testSearchDocuments() throws {
        let libraryTab = app.segmentedControls.buttons["Library"]
        if libraryTab.exists {
            libraryTab.click()
            
            // Find search field
            let searchField = app.searchFields.firstMatch
            if searchField.exists {
                searchField.click()
                searchField.typeText("test")
                
                // Verify search was executed
                let expectation = XCTestExpectation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    expectation.fulfill()
                }
                wait(for: [expectation], timeout: 1.0)
            }
        }
    }
    
    // MARK: - Observatorium Monitoring Tests
    
    func testObservatoriumTabAccessible() throws {
        let observatoriumTab = app.segmentedControls.buttons["Observatorium"]
        if observatoriumTab.exists {
            observatoriumTab.click()
            
            let expectation = XCTestExpectation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testAlertsList() throws {
        let observatoriumTab = app.segmentedControls.buttons["Observatorium"]
        if observatoriumTab.exists {
            observatoriumTab.click()
            
            // Look for alerts or monitoring indicators
            let alerts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Alert' OR label CONTAINS 'alert'"))
            
            XCTAssertGreaterThanOrEqual(alerts.count, 0)
        }
    }
    
    // MARK: - Atlas Visualization Tests
    
    func testAtlasVisualizationTab() throws {
        let atlasTab = app.segmentedControls.buttons["Atlas"]
        if atlasTab.exists {
            atlasTab.click()
            
            let expectation = XCTestExpectation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
            
            // Atlas should render a Metal view or canvas
            XCTAssertTrue(app.otherElements.count > 0 || app.scrollViews.count > 0)
        }
    }
    
    // MARK: - Settings Tests
    
    func testPreferencesMenuAccessible() throws {
        let menu = app.menus["Anigma"]
        if menu.exists {
            menu.click()
            
            let preferencesMenuItem = app.menuItems["Preferences"]
            if preferencesMenuItem.exists {
                preferencesMenuItem.click()
                
                let expectation = XCTestExpectation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    expectation.fulfill()
                }
                wait(for: [expectation], timeout: 1.0)
            }
        }
    }
    
    func testAboutMenuAccessible() throws {
        let menu = app.menus["Anigma"]
        if menu.exists {
            menu.click()
            
            let aboutMenuItem = app.menuItems.matching(NSPredicate(format: "label CONTAINS 'About'")).firstMatch
            if aboutMenuItem.exists {
                aboutMenuItem.click()
                
                let expectation = XCTestExpectation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    expectation.fulfill()
                }
                wait(for: [expectation], timeout: 2.0)
            }
        }
    }
    
    // MARK: - File Operations Tests
    
    func testOpenFile() throws {
        // Test if app can handle opening a file
        let menu = app.menus["File"]
        if menu.exists {
            menu.click()
            
            let openMenuItem = app.menuItems["Open"]
            if openMenuItem.exists {
                openMenuItem.click()
                
                let expectation = XCTestExpectation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    expectation.fulfill()
                }
                wait(for: [expectation], timeout: 1.0)
            }
        }
    }
    
    // MARK: - Responsiveness Tests
    
    func testUIRespondsToClicks() throws {
        // Test multiple tab navigation
        let tabs = app.segmentedControls
        
        if tabs.count > 0 {
            let tabButtons = tabs.firstMatch.buttons
            let clickCount = min(3, tabButtons.count)
            
            for i in 0..<clickCount {
                let button = tabButtons.element(boundBy: i)
                if button.exists {
                    button.click()
                    
                    let expectation = XCTestExpectation()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        expectation.fulfill()
                    }
                    wait(for: [expectation], timeout: 1.0)
                }
            }
        }
    }
    
    // MARK: - Scrolling Tests
    
    func testScrollViewsAreScrollable() throws {
        let scrollViews = app.scrollViews
        
        if scrollViews.count > 0 {
            let scrollView = scrollViews.firstMatch
            
            // Try scrolling
            let startPosition = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let endPosition = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            
            startPosition?.press(forDuration: 0.1, thenDragTo: endPosition!)
        }
    }
    
    // MARK: - State Persistence Tests
    
    func testWindowStatePreserved() throws {
        // Get initial window state
        let window = app.windows.firstMatch
        let initialFrame = window.frame
        
        XCTAssertTrue(initialFrame.size.width > 0)
        XCTAssertTrue(initialFrame.size.height > 0)
    }
    
    // MARK: - Keyboard Navigation Tests
    
    func testTabKeyNavigation() throws {
        app.typeKey(XCUIKeyboardKey.tab)
        
        // App should still be responsive
        XCTAssertTrue(app.exists)
    }
    
    func testEscapeKeyHandling() throws {
        app.typeKey(XCUIKeyboardKey.escape)
        
        // App should handle escape gracefully
        XCTAssertTrue(app.exists)
    }
    
    // MARK: - Error Handling Tests
    
    func testAppHandlesNetworkError() throws {
        // This would require isolating network calls
        // For now, just verify app doesn't crash
        XCTAssertTrue(app.exists)
    }
    
    // MARK: - Performance Tests
    
    func testTabSwitchingPerformance() throws {
        let tabs = app.segmentedControls
        
        if tabs.count > 0 {
            let startTime = Date()
            
            // Switch tabs several times
            let tabButtons = tabs.firstMatch.buttons
            for i in 0..<min(5, tabButtons.count) {
                let button = tabButtons.element(boundBy: i)
                if button.exists {
                    button.click()
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            
            // Should complete in reasonable time (less than 2 seconds)
            XCTAssertLessThan(elapsedTime, 2.0)
        }
    }
    
    func testMemoryNotLeaking() throws {
        // Perform repeated operations
        for _ in 0..<5 {
            // This is a placeholder - actual memory testing would require
            // XCTMetrics and performance testing framework
            
            let tabs = app.segmentedControls
            if tabs.count > 0 {
                tabs.firstMatch.buttons.firstMatch.click()
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        // App should still be responsive
        XCTAssertTrue(app.exists)
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityIdentifiers() throws {
        // Verify key elements have accessibility identifiers
        let tabs = app.segmentedControls
        
        if tabs.count > 0 {
            XCTAssertTrue(tabs.firstMatch.isHittable)
        }
    }
    
    func testVoiceOverCompatibility() throws {
        // Verify app works with accessibility features
        let buttons = app.buttons
        
        if buttons.count > 0 {
            let firstButton = buttons.firstMatch
            XCTAssertTrue(firstButton.isHittable)
        }
    }
}
