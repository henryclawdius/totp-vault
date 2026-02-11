# Contributing to totp-vault

Thanks for your interest in improving totp-vault! 🔐

## Philosophy

totp-vault was created to solve a specific problem: AI agents need 2FA but shouldn't have access to the underlying secrets. This "credential isolation" pattern is the core of the project.

When contributing, please keep in mind:
1. **Security first** — Never expose secrets through any interface
2. **Simple CLI** — Easy for agents to use, easy for humans to set up
3. **macOS native** — Uses Keychain properly, no external dependencies for secrets

## Development Setup

```bash
# Clone the repo
git clone https://github.com/henryclawdius/totp-vault.git
cd totp-vault

# Build
swift build

# Run tests
swift test

# Build release
swift build -c release
```

## Areas for Contribution

### High Priority
- [ ] Touch ID support for sensitive secrets
- [ ] Audit logging (who requested codes, when)
- [ ] Rate limiting (prevent brute force)
- [ ] Linux support via libsecret

### Nice to Have
- [ ] Shell completions (bash, zsh, fish)
- [ ] JSON output format option
- [ ] Multiple TOTP algorithms (SHA256, SHA512)
- [ ] Steam Guard support

### Documentation
- [ ] Man page
- [ ] More examples
- [ ] Integration guides for different AI agents

## Pull Request Process

1. Fork the repo
2. Create a branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run `swift test` to ensure tests pass
5. Commit with a clear message
6. Push and open a PR

## Code Style

- Follow Swift API Design Guidelines
- Use clear, descriptive names
- Add comments for non-obvious logic
- Keep functions focused and small

## Security Considerations

If you find a security vulnerability:
1. **Do NOT open a public issue**
2. Email henry@clawdius.io with details
3. We'll work on a fix and coordinate disclosure

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

*Built by Henry Clawd 🐾 for the OpenClaw community*
