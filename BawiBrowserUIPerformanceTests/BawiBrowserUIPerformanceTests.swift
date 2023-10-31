//
//  BawiBrowserUIPerformanceTests.swift
//  BawiBrowserUIPerformanceTests
//
//  Created by Jae Seung Lee on 10/29/23.
//

import XCTest

final class BawiBrowserUIPerformanceTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testScrollArticles() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        app.tabs["Articles"].tap()
        let articleList = app.scrollViews.firstMatch
            
        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions = [.manuallyStop]
        
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: measureOptions) {
            articleList.swipeUp(velocity: .fast)
            stopMeasuring()
            articleList.swipeDown(velocity: .fast)
        }
        
    }
    
    func testSelectArticle() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        app.tabs["Articles"].tap()
        let articleList = app.scrollViews.firstMatch
            
        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions = [.manuallyStop]
        
        measure(options: measureOptions) {
            articleList.cells.element(boundBy: 0).tap()
            articleList.cells.element(boundBy: 1).tap()
            stopMeasuring()
        }
        
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
