import CoreGraphics
import RectangleContour
import XCTest

final class ContourTests: XCTestCase {
    func testEmpty() throws {
        let expected: IsoOrientedContour = .init(cycles: [])
        let actual = [].contour()
        XCTAssertEqual(actual, expected)
    }
    
    func testSingleRectangle() throws {
        let rect = CGRect(x: 1, y: 2, width: 3, height: 4)
        let expected: IsoOrientedContour = .init(cycles: [
            .init([
                .init(x: 1, y: 2),
                .init(x: 4, y: 2),
                .init(x: 4, y: 6),
                .init(x: 1, y: 6),
            ])
        ])
        let actual = [rect].contour().normalized()

        XCTAssertEqual(actual, expected)
    }

    func testTwoSeparateRectangles() throws {
        let r0 = CGRect(x: 1, y: 2, width: 3, height: 4)
        let r1 = CGRect(x: 5, y: 6, width: 7, height: 8)

        let expected: IsoOrientedContour = .init(cycles: [
            .init([
                .init(x: 1, y: 2),
                .init(x: 4, y: 2),
                .init(x: 4, y: 6),
                .init(x: 1, y: 6),
            ]),
            .init([
                .init(x: 5, y: 6),
                .init(x: 12, y: 6),
                .init(x: 12, y: 14),
                .init(x: 5, y: 14),
            ]),
        ])

        let actual = [r1, r0].contour().normalized()

        XCTAssertEqual(actual, expected)
    }

    func testTwoOverlappingRectangles() throws {
        let r0 = CGRect(x: 1, y: 2, width: 3, height: 4)
        let r1 = CGRect(x: 2, y: 3, width: 5, height: 6)

        let expected: IsoOrientedContour = .init(cycles: [
            .init([
                .init(x: 1, y: 2),
                .init(x: 4, y: 2),
                .init(x: 4, y: 3),
                .init(x: 7, y: 3),
                .init(x: 7, y: 9),
                .init(x: 2, y: 9),
                .init(x: 2, y: 6),
                .init(x: 1, y: 6),
            ]),
        ])

        let actual = [r1, r0].contour().normalized()

        XCTAssertEqual(actual, expected)
    }

    func testTwoOverlappingRectangles2() throws {
        let r0 = CGRect(x: 2, y: 71, width: 2, height: 3)
        let r1 = CGRect(x: 1, y: 72, width: 2, height: 1)

        let expected: IsoOrientedContour = .init(cycles: [
            .init([
                .init(x: 1, y: 72),
                .init(x: 2, y: 72),
                .init(x: 2, y: 71),
                .init(x: 4, y: 71),
                .init(x: 4, y: 74),
                .init(x: 2, y: 74),
                .init(x: 2, y: 73),
                .init(x: 1, y: 73),
            ]),
        ])

        let actual = [r0, r1].contour().normalized()

        XCTAssertEqual(actual, expected)
    }
}
