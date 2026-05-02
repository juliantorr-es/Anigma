# Backward Compatibility with Existing Installer

This simple installer is designed to work alongside the existing Anigma installer package.

## Differences from Existing Installer

| Feature | Existing Installer | Simple Installer |
|---------|-------------------|------------------|
| **Installation Method** | Package (.pkg) with GUI | Command-line scripts |
| **Daemon Location** | `/Applications/AnigmaDaemon.app` | `/usr/local/bin/anigmad` or `~/.local/bin/anigmad` |
| **LaunchAgent** | Same name (`com.anigma.daemon.plist`) | Same name (`com.anigma.daemon.plist`) |
| **Configuration** | `~/Library/Application Support/Anigma/` | `~/Library/Application Support/AnigmaDaemon/` |
| **CLI Tools** | `anigmad`, `anigma-cli` in `/usr/local/bin/` | `anigmad` only |
| **GUI App** | `Anigma.app` in `/Applications/` | No GUI app |

## Coexistence

Both installers can coexist because:
1. They use different configuration directories
2. The LaunchAgent names are the same, but only one can run at a time
3. CLI tools have the same name but different installation paths

## Migration Path

To migrate from existing installer to simple installer:

1. **Uninstall existing daemon**:
   ```bash
   /Applications/AnigmaDaemon.app/Contents/MacOS/uninstall
   ```

2. **Install simple daemon**:
   ```bash
   cd installer/daemon-simple
   ./one_command_install.sh
   ```

3. **Migrate configuration** (if needed):
   ```bash
   cp ~/Library/Application\ Support/Anigma/config.json \
      ~/Library/Application\ Support/AnigmaDaemon/config.json
   ```

4. **Update clients** to use new API key if generated.

## Testing Compatibility

Run the compatibility test:
```bash
cd installer/daemon-simple
./test_installation.sh
```

This will check for conflicts with existing installations.

## Fallback to Existing Installer

If the simple installer doesn't meet your needs, you can always:
1. Uninstall simple daemon: `./uninstall.sh`
2. Install the full package: `open installer/Anigma-1.0.0.pkg`

## Development Notes

For developers working on both installers:
- Keep LaunchAgent naming consistent
- Document configuration differences
- Test both installers side-by-side
- Provide clear migration instructions
