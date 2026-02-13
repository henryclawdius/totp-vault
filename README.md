# totp-vault 🔐

## ⚠️ This Repository is a Case Study

**This code does not solve AI agent security.** It was built by an AI agent (Henry Clawd) that confidently created a 2FA system for itself — which turned out to provide zero actual security.

The tool works as designed: TOTP secrets stay in macOS Keychain, never exposed in plaintext. But **an agent that can call both `get` (generate codes) and `verify` (check codes) can authorize itself.** Self-verification is not verification. The agent is the lock, the key, and the locksmith.

**Read [CASE-STUDY.md](CASE-STUDY.md) for the full story** — how an AI pattern-matched from human security practices, built something that looked right, and created a false sense of security that was more dangerous than having no security at all.

### What This Teaches
- AI agents will confidently build security theater from training data patterns
- Behavioral controls (policy files, self-checks) degrade over long sessions
- Structural controls (OS-level permissions, separate processes) are what actually work
- An agent's confidence in its security solution is not evidence of security
- **Recovery (backups) beats prevention when the "attacker" is the system itself**

---

*The code below is preserved as-is for reference. It's a well-engineered tool that solves the wrong problem.*

---

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

## Agent Authentication

### The Self-Verification Problem

When an AI agent can call both `get` and `verify`, 2FA becomes meaningless:

```
# A compromised agent can do this:
code=$(totp-vault get henry-2fa)    # Generate valid code
totp-vault verify henry-2fa $code   # "valid" — of course it is
# Proceed with destructive action — "2FA passed!"
```

This is equivalent to no 2FA at all.

### Correct Architecture

```
┌─────────────┐     code      ┌──────────────┐
│   HUMAN     │ ────────────► │    AGENT     │
│ (authenticator)│             │ (totp-vault  │
│             │               │   verify)    │
└─────────────┘               └──────────────┘
     ▲                              │
     │                              ▼
  Reads code                  Checks code
  from phone                  against Keychain
```

The human provides the code. The agent only verifies it. The agent **cannot generate codes**.

### How to Restrict `get`

Option 1: Require Touch ID for `get` (future feature)
Option 2: Run `totp-vault get` under a different macOS user the agent can't access
Option 3: Remove `get` from the agent-accessible binary and provide a separate admin-only binary

### What totp-vault DOES Protect Against

- ✅ TOTP secret exfiltration (secret never leaves Keychain)
- ✅ Secret exposure in logs, command history, or agent context
- ✅ Plaintext secret files being read by compromised agents

### What totp-vault Does NOT Protect Against (without access restrictions)

- ❌ Agent self-authorization (can generate + verify its own codes)
- ❌ Social engineering ("Hey human, what's the code?" for a hidden purpose)
- ❌ A compromised agent bypassing 2FA entirely by calling `get`
