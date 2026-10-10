# Security Policy

## Supported Versions

Security updates are actively provided for the following versions:

| Version | Supported          |
| :------ | :----------------- |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

The AppsChannel project takes security and user privacy seriously. Because AppsChannel executes outside the macOS sandbox to index and launch local applications, maintaining strict boundaries against remote code execution, URL injection, and arbitrary script invocation is critical.

If you believe you have found a security vulnerability in AppsChannel, please report it privately:

1. **Do not open a public issue.**
2. Send an email describing the vulnerability to the repository maintainer, or submit a report via GitHub Private Vulnerability Reporting on this repository.
3. Include detailed steps to reproduce the vulnerability, proof-of-concept code if available, and any potential mitigations.

You will receive an acknowledgment within 48 hours and regular updates on the resolution.

## Local Privacy & Data Retention

AppsChannel operates with strict local privacy principles:
* **Zero Telemetry**: No analytics or usage tracking are ever sent to external servers.
* **Local Processing**: Usage statistics and cache files are stored solely on your machine in `~/Library/Application Support/AppsChannel` and `~/Library/Caches/AppsChannel`.
* **Network Access**: The only outgoing network activity is checking for signed application updates via Sparkle (`SUFeedURL`).
