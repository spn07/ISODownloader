# ISO Downloader Project 🛡️

Secure powershell tool, for downloading my own ISOs, adding rufus to the ISO so it's easier to interact with the ISO.

## Features 📊

- **Self-Integrity Check:** The script verifies its own hash before running. If modified, it refuses to execute.
- **Secure Config:** URLs are Base64 encoded.
- **Secure Delete:** Overwrites partial files with zeros before deletion to prevent recovery.
- **Disk Space Check:** Prevents corruption due to full drives.
- **TLS 1.2/1.3:** Enforced secure connections.