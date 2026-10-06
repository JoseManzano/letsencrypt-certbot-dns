# Let's Encrypt Certbot DNS Certificate Generator

A Docker-based Bash utility for generating **Let's Encrypt wildcard and single-host certificates** using **Certbot** with manual **DNS-01 validation**.

Certbot runs inside Docker, so Certbot does not need to be installed directly on the Linux host.

## Features

- Uses the official Certbot Docker image
- Creates wildcard certificates such as `*.example.com`
- Creates single-host certificates such as `app1.example.com`
- Uses manual DNS-01 validation
- Automatically creates persistent `etc/` and `lib/` directories if they do not exist
- Shows existing certificate directories
- Keeps wildcard and single-host Certbot lineages separate
- Dynamically discovers files in the issued certificate directory
- Provides an interactive menu for displaying certificate files
- Displays certificate subject, issuer, serial number, validity dates, SHA-256 fingerprint, and SANs
- Requires confirmation before displaying `privkey.pem`
- Preserves Certbot certificate and account data between container runs

## Requirements

- Linux
- Bash
- Docker installed and running
- `sudo`
- OpenSSL
- Internet access
- A registered domain
- Access to the domain's public DNS provider so TXT records can be created

Because DNS-01 validation is used, the TLS service itself does **not** need to be publicly reachable.

## Installation

Download or copy `letsencrypt-certbot-dns.sh`.

Make it executable:

```bash
chmod +x letsencrypt-certbot-dns.sh
```

Run it:

```bash
./letsencrypt-certbot-dns.sh
```

The directory containing the script is used as the working directory.

## Persistent Certbot Directories

The script checks for:

```text
./etc
./lib
```

If either directory does not exist, the script creates it automatically.

They are mounted into the Certbot container as:

```text
./etc  -> /etc/letsencrypt
./lib  -> /var/lib/letsencrypt
```

This preserves certificates, private keys, Certbot account information, renewal configuration, and related data after the temporary Docker container exits.

> **Important:** Never commit the `etc/` or `lib/` directories to source control.

## Usage

At startup, the script checks its Certbot directories and displays existing certificate directories.

Example:

```text
========================================
 Let's Encrypt Certificate Generator
========================================

Checking Certbot directories...

  [OK] etc directory exists
  [OK] lib directory exists

Existing certificate directories:

  - example.com
  - app1.example.com
```

The script then prompts for the base domain and email address:

```text
Enter base domain (example: example.com): example.com
Enter email address: admin@example.com
```

It then presents:

```text
Select certificate type:

  1) Wildcard Certificate (*.example.com)
  2) Single Host Certificate (e.g. app1.example.com)
```

## Wildcard Certificates

Selecting option `1` requests:

```text
*.example.com
```

The Certbot storage name is the base domain, so the certificate lineage is stored under:

```text
./etc/live/example.com/
```

A wildcard such as `*.example.com` covers first-level hostnames including:

```text
www.example.com
app1.example.com
netscaler-aigw.example.com
netscaler-mcpgw.example.com
```

It does **not** cover the apex hostname `example.com`, and it does not cover deeper names such as `server.lab.example.com`.

## Single-Host Certificates

Selecting option `2` causes the script to ask for the hostname portion:

```text
Enter hostname (example: app1): app1
```

The resulting certificate request is:

```text
app1.example.com
```

The certificate receives its own Certbot lineage:

```text
./etc/live/app1.example.com/
```

This keeps the single-host certificate separate from a wildcard certificate for the same base domain.

## Certificate Request Confirmation

Before starting Certbot, the script displays the planned request, including:

- Certificate type
- Certificate name
- Certbot storage name
- Email
- Certificate directory

The user must confirm before Certbot is started.

## DNS-01 Validation

The script invokes Certbot with manual DNS validation.

During issuance, Certbot displays the exact TXT record name and value that must be created at the DNS provider.

For example, a single-host certificate may require:

```text
_acme-challenge.app1.example.com
```

Create the TXT record using the exact value supplied by Certbot.

> **Do not continue Certbot until the requested TXT record is publicly resolvable.**

Depending on the DNS provider, the DNS management interface may expect a relative record name instead of the complete FQDN. Follow the DNS provider's conventions and the exact challenge information displayed by Certbot.

After successful validation and certificate issuance, temporary `_acme-challenge` TXT records can normally be removed.

## Certificate Storage

Certificates are stored under:

```text
./etc/live/<certbot-storage-name>/
```

Certbot commonly provides:

```text
README
cert.pem
chain.pem
fullchain.pem
privkey.pem
```

After issuance, the script dynamically reads the certificate directory and builds the file menu from what is actually present.

The PEM entries in Certbot's `live/` directory are normally symbolic links to versioned certificate material maintained elsewhere in the Certbot data tree.

## Interactive File Menu

After successful issuance, the script reads the certificate directory and creates a menu dynamically.

For example:

```text
========================================
 Certificate Files
========================================

Directory:
  /path/to/etc/live/app1.example.com

What would you like to print?

  1) README
  2) cert.pem
  3) chain.pem
  4) fullchain.pem
  5) privkey.pem
  6) Certificate details
  7) Exit
```

The exact numbered file list depends on what exists in the certificate directory.

After displaying a file or certificate details, the script returns to the menu so another item can be selected.

If `privkey.pem` is selected, the script displays an additional warning and requires confirmation before printing the private key.

## Certificate Details

The **Certificate details** menu option uses OpenSSL to display:

- Subject
- Issuer
- Serial number
- Valid-from date
- Expiration date
- SHA-256 fingerprint
- Subject Alternative Names (SANs)

This provides a convenient way to inspect an issued certificate before installing it on a TLS endpoint.

## Example Directory Layout

A working directory may eventually look similar to:

```text
letsencrypt-certbot-dns/
├── letsencrypt-certbot-dns.sh
├── etc/
│   ├── accounts/
│   ├── archive/
│   ├── live/
│   │   ├── example.com/
│   │   └── app1.example.com/
│   └── renewal/
└── lib/
```

The Certbot data directories should remain local and should not be committed to GitHub.

## Recommended `.gitignore`

If the repository itself is used as the script's working directory, create a `.gitignore` containing at least:

```gitignore
# Certbot / Let's Encrypt data
etc/
lib/

# Private keys and certificates
*.pem
*.key
*.p12
*.pfx

# Environment files
.env

# Editor / OS files
.DS_Store
*.swp
```

This reduces the risk of accidentally committing certificate private keys or Certbot account data.

## Security Notes

- Never upload `privkey.pem` to GitHub.
- Never commit `etc/` or `lib/`.
- Do not weaken Certbot's private-key permissions just to avoid using `sudo`.
- Be careful when using the option to display the private key in a terminal.
- Remove temporary DNS challenge records after successful validation when they are no longer needed.
- Review files before committing changes to a public repository.

## Renewal

The script currently uses Certbot's **manual DNS-01 challenge**.

Manual DNS validation requires user interaction to create the TXT record requested by Certbot. Therefore, this script does not provide fully unattended certificate renewal.

## Docker Behavior

The script uses the official `certbot/certbot` Docker image.

The container is started with `--rm`, so the temporary Certbot container is removed when Certbot exits.

Certificate and account data remain persistent because the host's `etc/` and `lib/` directories are mounted into `/etc/letsencrypt` and `/var/lib/letsencrypt`.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
