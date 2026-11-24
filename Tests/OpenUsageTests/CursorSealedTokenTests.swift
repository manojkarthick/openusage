import XCTest
@testable import OpenUsage

final class CursorSealedTokenTests: XCTestCase {
    func testRoundTripsAJWT() throws {
        let token = makeCursorJWT(sub: "auth0|sealed-user")
        let sealed = try CursorSealedToken.seal(token: token, password: "test-password")

        XCTAssertTrue(CursorSealedToken.isSealed(sealed))
        XCTAssertEqual(CursorSealedToken.open(stored: sealed, password: "test-password"), token)
        XCTAssertNil(CursorSealedToken.open(stored: sealed, password: "other-password"))
        XCTAssertNil(CursorSealedToken.open(stored: "cursor-safe-storage:v1:not-base64", password: "test-password"))

        let nonJWT = try CursorSealedToken.seal(token: "not-a-jwt", password: "test-password")
        XCTAssertNil(CursorSealedToken.open(stored: nonJWT, password: "test-password"))
    }

    func testOpensSealedEditorLoginAheadOfTheCLIKeychain() throws {
        let editor = makeCursorJWT(sub: "auth0|editor-user")
        let cli = makeCursorJWT(sub: "auth0|cli-user")
        let password = "test-password"
        let store = CursorAuthStore(
            sqlite: KeyValueSQLite(values: [
                CursorAuthStore.accessTokenKey: try CursorSealedToken.seal(token: editor, password: password),
                CursorAuthStore.refreshTokenKey: try CursorSealedToken.seal(
                    token: makeCursorJWT(sub: "auth0|editor-refresh"),
                    password: password
                ),
                CursorAuthStore.membershipTypeKey: "ultra"
            ]),
            keychain: ServiceKeychain(values: [
                CursorAuthStore.keychainAccessTokenService: cli,
                CursorAuthStore.keychainRefreshTokenService: "cli-refresh"
            ]),
            safeStorageKey: StaticSafeStorageKey(password: password)
        )

        let state = store.loadAuthState()

        XCTAssertEqual(state?.source, .sqlite)
        XCTAssertEqual(state?.isSealed, true)
        XCTAssertEqual(state?.accessToken, editor)
        XCTAssertEqual(state?.membershipType, "ultra")
        XCTAssertEqual(CursorAuthStore.tokenSubject(state?.refreshToken), "auth0|editor-refresh")
        XCTAssertFalse(store.needsRefresh(state?.accessToken))
    }

    func testSealedLoginWithoutAKeyFallsBackToTheCLILogin() throws {
        let cli = makeCursorJWT(sub: "auth0|cli-user")
        let store = CursorAuthStore(
            sqlite: KeyValueSQLite(values: [
                CursorAuthStore.accessTokenKey: try CursorSealedToken.seal(
                    token: makeCursorJWT(),
                    password: "editor-password"
                ),
                CursorAuthStore.membershipTypeKey: "ultra"
            ]),
            keychain: ServiceKeychain(values: [
                CursorAuthStore.keychainAccessTokenService: cli,
                CursorAuthStore.keychainRefreshTokenService: "cli-refresh"
            ]),
            safeStorageKey: StaticSafeStorageKey(password: nil)
        )

        let state = store.loadAuthState()

        XCTAssertEqual(state?.source, .keychain)
        XCTAssertEqual(state?.isSealed, false)
        XCTAssertEqual(state?.accessToken, cli)
        XCTAssertNil(state?.membershipType)
    }

    func testPersistsARotatedEditorTokenStillSealed() throws {
        let password = "test-password"
        let sqlite = KeyValueSQLite(values: [
            CursorAuthStore.accessTokenKey: try CursorSealedToken.seal(token: makeCursorJWT(), password: password)
        ])
        let store = CursorAuthStore(
            sqlite: sqlite,
            keychain: FakeKeychain(),
            safeStorageKey: StaticSafeStorageKey(password: password)
        )
        let rotated = makeCursorJWT(sub: "auth0|rotated")

        try store.saveAccessToken(rotated, source: .sqlite)

        let written = try XCTUnwrap(sqlite.writtenValues[CursorAuthStore.accessTokenKey])
        XCTAssertTrue(CursorSealedToken.isSealed(written))
        XCTAssertEqual(CursorSealedToken.open(stored: written, password: password), rotated)
        XCTAssertFalse(written.contains(rotated))
    }

    func testDoesNotReplaceASealedEditorTokenWithPlaintext() throws {
        let sealed = try CursorSealedToken.seal(token: makeCursorJWT(), password: "editor-password")
        let sqlite = KeyValueSQLite(values: [CursorAuthStore.accessTokenKey: sealed])
        let store = CursorAuthStore(
            sqlite: sqlite,
            keychain: FakeKeychain(),
            safeStorageKey: StaticSafeStorageKey(password: nil)
        )

        XCTAssertThrowsError(try store.saveAccessToken("plaintext-jwt", source: .sqlite))
        XCTAssertNil(sqlite.writtenValues[CursorAuthStore.accessTokenKey])
    }

    func testDoesNotDowngradeToPlaintextWhenSaveTimeReadFails() throws {
        let sqlite = FailingReadSQLite()
        let store = CursorAuthStore(
            sqlite: sqlite,
            keychain: FakeKeychain(),
            safeStorageKey: StaticSafeStorageKey(password: "editor-password")
        )

        XCTAssertThrowsError(try store.saveAccessToken(makeCursorJWT(sub: "auth0|rotated"), source: .sqlite, sealed: true))
        XCTAssertEqual(sqlite.executeCount, 0)
    }

    func testPersistsSealedWhenSessionWasLoadedSealedEvenIfCellAbsent() throws {
        let password = "test-password"
        let sqlite = KeyValueSQLite(values: [:])
        let store = CursorAuthStore(
            sqlite: sqlite,
            keychain: FakeKeychain(),
            safeStorageKey: StaticSafeStorageKey(password: password)
        )
        let rotated = makeCursorJWT(sub: "auth0|rotated")

        try store.saveAccessToken(rotated, source: .sqlite, sealed: true)

        let written = try XCTUnwrap(sqlite.writtenValues[CursorAuthStore.accessTokenKey])
        XCTAssertTrue(CursorSealedToken.isSealed(written))
        XCTAssertEqual(CursorSealedToken.open(stored: written, password: password), rotated)
    }

    func testHasCredentialMaterialDetectsSealedLoginWithoutReadingSafeStorageKey() throws {
        let sealed = try CursorSealedToken.seal(token: makeCursorJWT(), password: "editor-password")
        let spyKey = SpySafeStorageKey()
        let store = CursorAuthStore(
            sqlite: KeyValueSQLite(values: [CursorAuthStore.accessTokenKey: sealed]),
            keychain: FakeKeychain(),
            safeStorageKey: spyKey
        )

        XCTAssertTrue(store.hasCredentialMaterial())
        XCTAssertEqual(spyKey.readCount, 0)
    }
}

private struct StaticSafeStorageKey: CursorSafeStorageKeyReading {
    var password: String?

    func readPassword() throws -> String? {
        password
    }
}

private final class SpySafeStorageKey: CursorSafeStorageKeyReading, @unchecked Sendable {
    var readCount = 0

    func readPassword() throws -> String? {
        readCount += 1
        return nil
    }
}

private final class FailingReadSQLite: SQLiteAccessing, @unchecked Sendable {
    enum Failure: Error { case transientReadError }
    var executeCount = 0

    func queryValue(path: String, sql: String) throws -> String? {
        throw Failure.transientReadError
    }

    func execute(path: String, sql: String) throws {
        executeCount += 1
    }
}
