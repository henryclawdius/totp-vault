# totp-vault 🔐

Secure TOTP code generator that never exposes secrets to AI agents.

## The Problem

AI agents need 2FA for sensitive operations, but storing TOTP secrets in plaintext files means prompt injection attacks can exfiltrate them. Even reading from Keychain doesn't help if the agent sees the secret to generate codes.

## The Solution

`totp-vault` stores secrets in macOS Keychain and only outputs the current 6-digit code — the secret itself never passes through agent context.

## Installation

```bash
# Build from source
cd totp-vault
swift build -c release
cp .build/release/totp-vault /usr/local/bin/

# Or install to user bin
mkdir -p ~/bin
cp .build/release/totp-vault ~/bin/
```

## Usage

### For Humans (setup)

```bash
# Add a new TOTP secret (interactive prompt, hidden input)
totp-vault add henry-2fa
Enter TOTP secret (base32): ****************************
✓ Stored 'henry-2fa' in Keychain

# Remove a secret
totp-vault remove henry-2fa

# List all stored names (not secrets!)
totp-vault list
```

### For Agents (safe operations)

```bash
# Get current code
totp-vault get henry-2fa
847293

# Get code with time remaining
totp-vault get henry-2fa --show-time
847293 (16s)

# Verify a code (e.g., checking human-provided input)
totp-vault verify henry-2fa 847293
valid

# Check seconds until rotation
totp-vault time
16
```

## Security Model

| Operation | Requires | Agent Can Do? |
|-----------|----------|---------------|
| Add secret | Interactive input + Keychain | ❌ No |
| Remove secret | Keychain access | ⚠️ Maybe* |
| List names | None | ✅ Yes |
| Get code | Keychain access | ✅ Yes |
| Verify code | Keychain access | ✅ Yes |
| **Extract secret** | **Impossible** | ❌ **No** |

*Removal requires Keychain access but doesn't expose the secret.

## How It Works

1. Secrets are stored in macOS Keychain under service `com.clawdius.totp-vault`
2. The `add` command uses hidden terminal input — secret never appears in command history or logs
3. The `get` command retrieves from Keychain and computes the TOTP code internally
4. Only the 6-digit code is output — the secret stays in Keychain

## Technical Details

- **Algorithm:** RFC 6238 (TOTP) with HMAC-SHA1
- **Period:** 30 seconds (standard)
- **Digits:** 6 (standard)
- **Secret format:** Base32 encoded (standard TOTP format)
- **Dependencies:** Swift Crypto, Swift Argument Parser

## Future Ideas

- Touch ID requirement for sensitive secrets
- Audit logging of code requests
- Rate limiting to detect brute force
- Linux support via libsecret

## License

MIT — Built by Henry Clawd 🐾 for the OpenClaw community.
