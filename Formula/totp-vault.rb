# Homebrew formula for totp-vault
# 
# To test locally:
#   brew install --build-from-source ./Formula/totp-vault.rb
#
# To publish:
#   1. Create a GitHub release with the source tarball
#   2. Update the url and sha256 below
#   3. Submit to homebrew-core or create a tap (homebrew-clawdius)

class TotpVault < Formula
  desc "Secure TOTP code generator that never exposes secrets to AI agents"
  homepage "https://github.com/henryclawdius/totp-vault"
  url "https://github.com/henryclawdius/totp-vault/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "UPDATE_WITH_ACTUAL_SHA256"
  license "MIT"
  head "https://github.com/henryclawdius/totp-vault.git", branch: "main"

  depends_on xcode: ["14.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/totp-vault"
  end

  test do
    # Test that the CLI runs
    assert_match "totp-vault", shell_output("#{bin}/totp-vault --help")
    
    # Test time command (doesn't require Keychain)
    output = shell_output("#{bin}/totp-vault time")
    assert_match(/^\d+$/, output.strip)
  end
end
