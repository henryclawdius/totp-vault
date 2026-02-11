import ArgumentParser
import Foundation
import Security
import Crypto

// MARK: - Keychain Helpers

enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound: return "Secret not found in Keychain"
        case .duplicateItem: return "Secret already exists (use 'remove' first)"
        case .unexpectedStatus(let status): return "Keychain error: \(status)"
        case .invalidData: return "Invalid data in Keychain"
        }
    }
}

struct Keychain {
    static let service = "com.clawdius.totp-vault"
    
    static func store(secret: String, for name: String) throws {
        let secretData = secret.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
            kSecValueData as String: secretData
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            throw KeychainError.duplicateItem
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    static func retrieve(for name: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let secret = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return secret
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    static func delete(name: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    static func listNames() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let items = result as? [[String: Any]] else {
                return []
            }
            return items.compactMap { $0[kSecAttrAccount as String] as? String }
        case errSecItemNotFound:
            return []
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

// MARK: - TOTP Implementation

struct TOTP {
    /// Generate a TOTP code from a base32-encoded secret
    static func generate(secret: String, time: Date = Date(), period: Int = 30, digits: Int = 6) throws -> String {
        // Decode base32 secret
        let cleanSecret = secret.uppercased().replacingOccurrences(of: " ", with: "")
        guard let secretData = base32Decode(cleanSecret) else {
            throw TOTPError.invalidSecret
        }
        
        // Calculate time counter
        let counter = UInt64(time.timeIntervalSince1970) / UInt64(period)
        
        // Convert counter to big-endian bytes
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: 8)
        
        // HMAC-SHA1
        let key = SymmetricKey(data: secretData)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let hmacBytes = Array(hmac)
        
        // Dynamic truncation
        let offset = Int(hmacBytes[hmacBytes.count - 1] & 0x0f)
        let truncatedHash = hmacBytes[offset..<offset+4]
        
        var number = truncatedHash.reduce(0) { ($0 << 8) | UInt32($1) }
        number &= 0x7fffffff
        
        // Get the requested number of digits
        let modulo = UInt32(pow(10, Double(digits)))
        let code = number % modulo
        
        return String(format: "%0\(digits)d", code)
    }
    
    /// Verify a TOTP code (checks current and adjacent periods for clock drift)
    static func verify(secret: String, code: String, window: Int = 1) throws -> Bool {
        let now = Date()
        for offset in -window...window {
            let checkTime = now.addingTimeInterval(Double(offset * 30))
            if try generate(secret: secret, time: checkTime) == code {
                return true
            }
        }
        return false
    }
    
    /// Seconds remaining until code rotates
    static func timeRemaining(period: Int = 30) -> Int {
        let now = Int(Date().timeIntervalSince1970)
        return period - (now % period)
    }
}

enum TOTPError: Error, LocalizedError {
    case invalidSecret
    
    var errorDescription: String? {
        switch self {
        case .invalidSecret: return "Invalid base32 secret"
        }
    }
}

// Base32 decoding (RFC 4648)
func base32Decode(_ input: String) -> Data? {
    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    var bits = ""
    
    for char in input {
        if char == "=" { continue }
        guard let index = alphabet.firstIndex(of: char) else { return nil }
        let value = alphabet.distance(from: alphabet.startIndex, to: index)
        bits += String(value, radix: 2).leftPad(to: 5, with: "0")
    }
    
    var bytes = [UInt8]()
    for i in stride(from: 0, to: bits.count - 7, by: 8) {
        let start = bits.index(bits.startIndex, offsetBy: i)
        let end = bits.index(start, offsetBy: 8)
        if let byte = UInt8(String(bits[start..<end]), radix: 2) {
            bytes.append(byte)
        }
    }
    
    return Data(bytes)
}

extension String {
    func leftPad(to length: Int, with pad: Character) -> String {
        if count >= length { return self }
        return String(repeating: pad, count: length - count) + self
    }
}

// MARK: - CLI Commands

@main
struct TOTPVault: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "totp-vault",
        abstract: "Secure TOTP code generator that never exposes secrets",
        version: "1.0.0",
        subcommands: [Add.self, Remove.self, List.self, Get.self, Verify.self, Time.self]
    )
}

struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add a new TOTP secret (interactive - for humans only)"
    )
    
    @Argument(help: "Name for this TOTP secret")
    var name: String
    
    func run() throws {
        // Check if already exists
        let existing = try Keychain.listNames()
        if existing.contains(name) {
            print("Error: '\(name)' already exists. Use 'remove' first.")
            throw ExitCode.failure
        }
        
        // Prompt for secret (hidden input)
        print("Enter TOTP secret (base32): ", terminator: "")
        
        // Disable echo for secret input
        var oldTermios = termios()
        tcgetattr(STDIN_FILENO, &oldTermios)
        var newTermios = oldTermios
        newTermios.c_lflag &= ~UInt(ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &newTermios)
        
        guard let secret = readLine(), !secret.isEmpty else {
            tcsetattr(STDIN_FILENO, TCSANOW, &oldTermios)
            print("\nError: No secret provided")
            throw ExitCode.failure
        }
        
        tcsetattr(STDIN_FILENO, TCSANOW, &oldTermios)
        print() // newline after hidden input
        
        // Validate secret by generating a test code
        do {
            _ = try TOTP.generate(secret: secret)
        } catch {
            print("Error: Invalid TOTP secret (must be base32 encoded)")
            throw ExitCode.failure
        }
        
        // Store in Keychain
        try Keychain.store(secret: secret, for: name)
        print("✓ Stored '\(name)' in Keychain")
    }
}

struct Remove: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove a TOTP secret from Keychain"
    )
    
    @Argument(help: "Name of the TOTP secret to remove")
    var name: String
    
    func run() throws {
        try Keychain.delete(name: name)
        print("✓ Removed '\(name)' from Keychain")
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List all stored TOTP names (not the secrets)"
    )
    
    func run() throws {
        let names = try Keychain.listNames()
        if names.isEmpty {
            print("No TOTP secrets stored")
        } else {
            print("Stored TOTP secrets:")
            for name in names.sorted() {
                print("  • \(name)")
            }
        }
    }
}

struct Get: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Get the current TOTP code (agent-safe)"
    )
    
    @Argument(help: "Name of the TOTP secret")
    var name: String
    
    @Flag(name: .shortAndLong, help: "Show time remaining until rotation")
    var showTime = false
    
    func run() throws {
        let secret = try Keychain.retrieve(for: name)
        let code = try TOTP.generate(secret: secret)
        
        if showTime {
            let remaining = TOTP.timeRemaining()
            print("\(code) (\(remaining)s)")
        } else {
            print(code)
        }
    }
}

struct Verify: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Verify a TOTP code (agent-safe)"
    )
    
    @Argument(help: "Name of the TOTP secret")
    var name: String
    
    @Argument(help: "Code to verify")
    var code: String
    
    func run() throws {
        let secret = try Keychain.retrieve(for: name)
        let valid = try TOTP.verify(secret: secret, code: code)
        
        if valid {
            print("valid")
        } else {
            print("invalid")
            throw ExitCode.failure
        }
    }
}

struct Time: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show seconds until code rotates"
    )
    
    func run() throws {
        let remaining = TOTP.timeRemaining()
        print(remaining)
    }
}
