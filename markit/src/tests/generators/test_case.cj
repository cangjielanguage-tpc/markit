package markit.tests.generators

public struct TestCase {
    public let input: String
    public let expectedHtml: String
    public let description: String

    public init(input: String, expectedHtml: String, description!: String = "") {
        this.input = input
        this.expectedHtml = expectedHtml
        this.description = description
    }
}
