import ArchivistNetworking
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct NetworkingErrorTests {
    @Test(arguments: [401, 403])
    func authStatusesAreAuthErrors(code: Int) {
        let error = NetworkingError.errorStatusCode(code, "")
        #expect(error.isAuthError)
        #expect(error.userMessage == "Invalid or expired token")
    }

    @Test func otherStatusesAreServerErrors() {
        let error = NetworkingError.errorStatusCode(500, "")
        #expect(!error.isAuthError)
        #expect(error.userMessage == "Server error (500)")
    }

    @Test func invalidTokenNeedsBothTheStatusAndTheMessage() {
        #expect(NetworkingError.errorStatusCode(403, #"{"detail":"Invalid token."}"#).isInvalidToken)
        #expect(NetworkingError.errorStatusCode(401, "invalid token").isInvalidToken)
        #expect(!NetworkingError.errorStatusCode(403, "Forbidden").isInvalidToken)
        #expect(!NetworkingError.errorStatusCode(500, "Invalid token").isInvalidToken)
    }

    @Test func statusInitKeepsTheBodyText() {
        #expect(NetworkingError(statusCode: 404, body: Data("missing".utf8)) == .errorStatusCode(404, "missing"))
    }

    @Test func genericErrorsGetAGenericMessage() {
        struct Other: Error {}
        #expect(Other().userMessage == "A network error occurred")
        #expect((NetworkingError.invalidURL as any Error).userMessage == "Invalid server URL")
    }
}
