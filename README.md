# homebrew-strongman

This is a Homebrew formula that helps install Strongman on a MacOS machine. While the install does work, there are various 500 errors in the server, and it is not functional. *PLease do not use it.*

### Uninstall

After playing around with it a bit, the following should help ensure that there's nothing left once you want it gone.

```bash
# 1. Stop and remove the Homebrew service
brew services stop strongman

# 2. Uninstall the package
brew uninstall --force strongman

# 3. Clean up Homebrew cache
brew cleanup strongman

# 4. Remove any leftover Cellar directories
sudo rm -rf /usr/local/Cellar/strongman/

# 5. Remove data directories created by strongman
sudo rm -rf /usr/local/var/lib/strongman/
sudo rm -rf /usr/local/var/log/strongman*

# 6. Remove configuration files
sudo rm -rf /usr/local/etc/strongman/

# 7. Remove any strongSwan VICI configuration we created (optional - only if you're not using strongSwan for other purposes)
sudo rm -f /usr/local/etc/strongswan.d/charon/vici.conf

# 8. Remove launch agent files (if any remain)
rm -f ~/Library/LaunchAgents/homebrew.mxcl.strongman.plist

# 9. If you also want to remove strongSwan (since it was installed as a dependency)
brew uninstall strongswan
brew cleanup strongswan

# 10. Remove any remaining strongSwan processes
sudo ipsec stop

# 11. Clean up any remaining Homebrew metadata
brew cleanup -s

# 12. Verify cleanup
echo "Checking for any remaining strongman files..."
find /usr/local -name "*strongman*" 2>/dev/null || echo "No strongman files found"
```