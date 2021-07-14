//
//  BawiBrowserTests.swift
//  BawiBrowserTests
//
//  Created by Jae Seung Lee on 6/28/21.
//

import XCTest
@testable import BawiBrowser
@testable import MultipartKit

class BawiBrowserTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testMultiPartFormWithImage() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let testBundle = Bundle(for: type(of: self))
        
        guard let ressourceURL = testBundle.url(forResource: "multipartFormWithImage", withExtension: nil) else {
            // file does not exist
            print("file does not exist")
            return
        }
        
        var bawiWriteForm: BawiWriteForm?
        do {
            let testData = try Data(contentsOf: ressourceURL)
            let boundary = "----WebKitFormBoundaryYAleMZtX2PlNDTBQ"
            bawiWriteForm = try FormDataDecoder().decode(BawiWriteForm.self, from: [UInt8](testData), boundary: boundary)
        } catch {
            print("Error while reading a file \(ressourceURL): \(error)")
        }
        
        XCTAssertNotNil(bawiWriteForm)
        XCTAssertEqual("1765", bawiWriteForm!.bid)
        XCTAssertEqual("145", bawiWriteForm!.p)
        XCTAssertEqual("0", bawiWriteForm!.img)
        XCTAssertEqual("디테일", bawiWriteForm!.title)
        
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
