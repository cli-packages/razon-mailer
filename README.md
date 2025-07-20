# Razon Email Client

A powerful command-line email client built with Bun runtime, featuring advanced email automation, bulk sending capabilities, and integrated browser automation for modern email workflows.

## Features

- **High-Performance Runtime**: Built with Bun for lightning-fast execution
- **Bulk Email Sending**: Send emails to thousands of recipients efficiently
- **Browser Automation**: Integrated Puppeteer for web-based email interactions
- **Multiple Email Protocols**: Support for SMTP and Outlook Web App (OWA)
- **Template System**: Customizable email templates with dynamic content
- **Attachment Support**: Send files, images, and documents
- **Progress Tracking**: Real-time progress bars and detailed logging
- **Cross-Platform**: Windows, macOS, and Linux support (AMD64 and ARM64)
- **Standalone Executable**: No dependencies required after installation

## Installation

### Quick Install

#### macOS and Linux
```bash
curl -fsSL https://raw.githubusercontent.com/cli-packages/razon-mailer/main/scripts/install.sh | bash
```

#### Windows (PowerShell as Administrator)
```powershell
iwr -useb https://raw.githubusercontent.com/cli-packages/razon-mailer/main/scripts/install.ps1 | iex
```

### What the Install Scripts Do

The installation scripts automatically:

1. **Download the binary** for your platform (Linux, macOS, Windows)
2. **Install to system PATH** (`/usr/local/bin` or `~/.local/bin` on Unix, `Program Files` on Windows)
3. **Download latest Chromium** browser for email automation
4. **Configure browser path** by setting `JM_BROWSER_PATH` environment variable
5. **Create data directory** (`~/.razon` on Unix, `%USERPROFILE%\.razon` on Windows)

#### 🌐 **Automatic Browser Setup**

The install scripts now include **intelligent Chromium management**:

- **Smart Detection**: Checks if Chromium is already installed and up-to-date
- **Version Comparison**: Compares installed vs. latest stable versions  
- **Skip Downloads**: Avoids unnecessary ~150MB downloads when browser is current
- **Auto-Update**: Downloads latest version only when needed
- **Platform-Specific**: Downloads correct Chromium build for your OS/architecture
- **Environment Setup**: Configures `JM_BROWSER_PATH` automatically
- **Fallback Support**: Works even if Chrome for Testing API is unavailable

**Installation behavior:**
- ✅ **Fresh Install**: Downloads latest Chromium automatically
- ✅ **Existing Install**: Skips download if Chromium is up-to-date  
- ✅ **Version Mismatch**: Updates to latest version seamlessly

### Manual Installation

1. Download the latest release from [GitHub Releases](https://github.com/cli-packages/razon-mailer/releases)
2. Extract the binary for your platform:
   - Linux: `razon-linux-amd64` or `razon-linux-arm64`
   - macOS: `razon-darwin-amd64` or `razon-darwin-arm64`
   - Windows: `razon-windows-amd64.exe`
3. Move to a directory in your PATH
4. Download Chromium manually or let Razon download it on first run

## Quick Start

### 1. Initialize Configuration

Create a new configuration:

```bash
razon init
```

This creates configuration files in the `config/` directory:
- `smtp.jsonc` - SMTP server settings
- `core.jsonc` - Core application settings
- `attachments.jsonc` - Attachment configurations
- `message.jsonc` - Email message templates
- `addon/owa.jsonc` - Outlook Web App settings

### 2. Configure SMTP Settings

Edit `config/smtp.jsonc`:

```jsonc
{
  "host": "smtp.gmail.com",
  "port": 587,
  "secure": false,
  "auth": {
    "user": "your-email@gmail.com",
    "pass": "your-app-password"
  }
}
```

### 3. Set Up Recipients

Create a `recipients.txt` file with email addresses (one per line):

```
user1@example.com
user2@example.com
user3@example.com
```

### 4. Send Emails

Send to all recipients:

```bash
razon send
```

Send test emails to first N recipients:

```bash
razon test 5
```

## Configuration

### SMTP Configuration (`config/smtp.jsonc`)

```jsonc
{
  "host": "smtp.gmail.com",
  "port": 587,
  "secure": false,
  "auth": {
    "user": "your-email@gmail.com",
    "pass": "your-app-password"
  },
  "pool": true,
  "maxConnections": 5,
  "maxMessages": 100
}
```

### Message Configuration (`config/message.jsonc`)

```jsonc
{
  "subject": "Your Email Subject",
  "from": "Your Name <your-email@gmail.com>",
  "html_template": "letter.html",
  "text_template": "letter.txt",
  "recipient_file": "recipients.txt",
  "attachments": []
}
```

### Core Configuration (`config/core.jsonc`)

```jsonc
{
  "concurrent_limit": 10,
  "delay_between_emails": 1000,
  "retry_attempts": 3,
  "log_level": "info",
  "database_path": "mailer.db"
}
```

## Advanced Features

### Email Templates

Create dynamic email templates with placeholders:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Welcome Email</title>
</head>
<body>
    <h1>Hello {{name}}!</h1>
    <p>Welcome to our service. Your account ID is: {{id}}</p>
</body>
</html>
```

### Attachments

Configure attachments in `config/attachments.jsonc`:

```jsonc
{
  "files": [
    {
      "path": "document.pdf",
      "name": "Important Document.pdf"
    },
    {
      "path": "image.jpg",
      "name": "Company Logo.jpg"
    }
  ]
}
```

### Browser Automation

Razon includes Chromium for web-based email automation. The browser is automatically downloaded and configured for your platform.

## Command Reference

### Email Sending Commands

```bash
# Send emails to all recipients
razon send

# Send emails ignoring duplicate check (force send to already contacted recipients)
razon send -f

# Send emails to first N recipients
razon send <count>

# Send emails to first N recipients (force)
razon send <count> -f

# Send test emails (default: 5 recipients, or specify count)
razon test [count]
```

### Email Management Commands

```bash
# Remove duplicate emails from file using regex extraction
razon remove-dup [filepath]
razon remove-dup [filepath] -o output.txt

# Remove invalid emails from file
razon remove-bad [filepath]
razon remove-bad [filepath] --type syntax
razon remove-bad [filepath] --type provider --domains gmail.com,yahoo.com
razon remove-bad [filepath] -o clean-emails.txt

# Remove emails that already exist in database
razon remove-non-unique [filepath]
razon remove-non-unique [filepath] -o new-emails.txt

# Remove emails that don't exist in database (keep only existing)
razon remove-unique [filepath]
razon remove-unique [filepath] -o existing-only.txt
```

### Statistics & Information Commands

```bash
# Show total emails sent from each SMTP/OWA provider
razon count-total

# Show comprehensive system summary
razon summary

# Show specific summary sections
razon summary --smtp
razon summary --owa
razon summary --config
razon summary --database
```

### Database Management Commands

```bash
# Create a database backup with .razon extension
razon backup [name]
razon backup [name] -p /custom/path

# Restore database from a .razon backup file
razon restore <name>
razon restore <name> -p /custom/path
razon restore <name> --clear --verify

# List available .razon backup files
razon list-backups
razon list-backups -p /custom/path

# Clear entire database (DANGEROUS OPERATION)
razon clear --confirm
```

### System Management Commands

```bash
# Initialize configuration files
razon init

# Force overwrite existing configuration
razon init -f

# Install Chromium browser for email automation
razon install
razon install --latest

# Check for available updates
razon check-for-update
razon check-for-update -u

# Update Razon to the latest version
razon update
razon update -f

# Display version information
razon version
razon v

# Show help
razon --help
```

### Global Options

```bash
# Initialize configuration (can be used with any command)
razon -i
razon --init

# Force operations (context-dependent)
razon -f
razon --force
```

## Platform Support

Razon supports the following platforms:

| Platform | Architecture | Status |
|----------|-------------|--------|
| Linux | x64 (AMD64) | ✅ Supported |
| Linux | ARM64 | ✅ Supported |
| Windows | x64 (AMD64) | ✅ Supported |
| Windows | ARM64 | ❌ Not supported |
| macOS | x64 (Intel) | ✅ Supported |
| macOS | ARM64 (Apple Silicon) | ✅ Supported |

## Development

### Prerequisites

- [Bun](https://bun.sh) runtime
- Node.js 18+ (for development)
- Git

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/cli-packages/razon-mailer.git
cd razon-mailer
```

2. Install dependencies:
```bash
bun install
```

3. Build for development:
```bash
bun run scripts/dev-build.ts
```

4. Build with watch mode:
```bash
bun run scripts/dev-build.ts --watch
```

### Creating a Release

To create a new release:

1. Update version in `package.json`
2. Commit and push changes
3. Run the release script:
```bash
./git/scripts/release.sh v1.0.0
```

The script will:
- Build binaries for all supported platforms
- Download and bundle Chromium for each platform
- Generate SHA256 checksums
- Create a GitHub release with all binaries

## Environment Variables

- `JM_BROWSER_PATH`: Path to the Chromium executable (automatically set during build)
- `NODE_ENV`: Environment mode (development/production)

## Troubleshooting

### Common Issues

1. **SMTP Authentication Errors**
   - Use app-specific passwords for Gmail
   - Enable "Less secure app access" if required
   - Check firewall settings

2. **Browser Download Issues**
   - Ensure internet connection during first run
   - Check proxy settings if behind corporate firewall

3. **Permission Errors**
   - Run installer as administrator on Windows
   - Use `sudo` for system-wide installation on Unix systems

### Logs

Razon creates detailed logs:
- `mailer.log` - General application logs
- `mailer-sent.log` - Successfully sent emails
- `mailer-failed.log` - Failed email attempts

## Security

- Never commit credentials to version control
- Use environment variables for sensitive data
- Regularly rotate email passwords
- Monitor sending limits to avoid being flagged as spam

## License

MIT License - feel free to use in your own projects.

## Support

For issues and feature requests, please file an issue on [GitHub](https://github.com/cli-packages/razon-mailer/issues).

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

---

Built with ❤️ using [Bun](https://bun.sh) runtime for maximum performance.