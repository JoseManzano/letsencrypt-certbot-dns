#!/bin/bash

# Let's Encrypt Certbot DNS Certificate Generator
#
# Generates Let's Encrypt wildcard or single-host certificates
# using Certbot in Docker with manual DNS-01 validation.
#
# Certificate data is stored locally in:
#   ./etc
#   ./lib
#
# IMPORTANT:
# Never commit the etc/ or lib/ directories to source control.

set -e

# =========================================================
# Configuration
# =========================================================

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

ETC_DIR="$BASE_DIR/etc"
LIB_DIR="$BASE_DIR/lib"
LIVE_DIR="$ETC_DIR/live"

echo "========================================"
echo " Let's Encrypt Certificate Generator"
echo "========================================"
echo


# =========================================================
# Check Certbot directories
# =========================================================

echo "Checking Certbot directories..."
echo

if [[ -d "$ETC_DIR" ]]; then
    echo "  [OK] etc directory exists"
else
    echo "  [CREATE] etc directory does not exist. Creating..."
    mkdir -p "$ETC_DIR"
fi

if [[ -d "$LIB_DIR" ]]; then
    echo "  [OK] lib directory exists"
else
    echo "  [CREATE] lib directory does not exist. Creating..."
    mkdir -p "$LIB_DIR"
fi

echo


# =========================================================
# Show existing certificate directories
# =========================================================

echo "Existing certificate directories:"
echo

FOUND_CERTS=false

if [[ -d "$LIVE_DIR" ]]; then

    for CERT_PATH in "$LIVE_DIR"/*/; do

        if [[ -d "$CERT_PATH" ]]; then

            CERT_NAME_EXISTING="$(basename "$CERT_PATH")"

            echo "  - $CERT_NAME_EXISTING"

            FOUND_CERTS=true
        fi

    done

fi

if [[ "$FOUND_CERTS" == false ]]; then
    echo "  No existing certificates found."
fi

echo


# =========================================================
# Get base domain and email
# =========================================================

read -rp "Enter base domain (example: example.com): " DOMAIN

read -rp "Enter email address: " EMAIL


# Remove accidental protocol, wildcard, or trailing slash

DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN#\*.}"
DOMAIN="${DOMAIN%/}"


if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then

    echo
    echo "ERROR: Domain and email are required."

    exit 1

fi


# =========================================================
# Select certificate type
# =========================================================

echo
echo "Select certificate type:"
echo
echo "  1) Wildcard Certificate (*.$DOMAIN)"
echo "  2) Single Host Certificate (e.g. app1.$DOMAIN)"
echo

read -rp "Selection [1-2]: " CERT_TYPE


case "$CERT_TYPE" in

    1)

        CERT_DOMAIN="*.$DOMAIN"

        # Wildcard certificate lineage is stored
        # under the base domain.

        CERT_NAME="$DOMAIN"

        CERT_DESCRIPTION="Wildcard"

        ;;


    2)

        echo

        read -rp "Enter hostname (example: app1): " HOSTNAME


        # Remove accidental spaces and dots

        HOSTNAME="${HOSTNAME// /}"
        HOSTNAME="${HOSTNAME#.}"
        HOSTNAME="${HOSTNAME%.}"


        if [[ -z "$HOSTNAME" ]]; then

            echo
            echo "ERROR: Hostname is required."

            exit 1

        fi


        CERT_DOMAIN="$HOSTNAME.$DOMAIN"

        # Give single-host certificates their own
        # Certbot lineage/directory.

        CERT_NAME="$CERT_DOMAIN"

        CERT_DESCRIPTION="Single Host"

        ;;


    *)

        echo
        echo "ERROR: Invalid selection."

        exit 1

        ;;

esac


# =========================================================
# Confirm certificate request
# =========================================================

echo
echo "========================================"
echo " Certificate Request"
echo "========================================"
echo

echo "Certificate type:"
echo "  $CERT_DESCRIPTION"
echo

echo "Certificate name:"
echo "  $CERT_DOMAIN"
echo

echo "Certbot storage name:"
echo "  $CERT_NAME"
echo

echo "Email:"
echo "  $EMAIL"
echo

echo "Certificate directory:"
echo "  $LIVE_DIR/$CERT_NAME/"
echo

echo "Certbot will provide the DNS TXT record that must be"
echo "created at your DNS provider."
echo


read -rp "Continue? [y/N]: " CONFIRM


if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then

    echo
    echo "Cancelled."

    exit 0

fi


# =========================================================
# DNS challenge information
# =========================================================

echo
echo "Starting Certbot..."
echo

echo "========================================"
echo " DNS VALIDATION"
echo "========================================"
echo

echo "Certbot will provide the exact DNS TXT record"
echo "that must be created."
echo

echo "DO NOT continue Certbot until the TXT record"
echo "has been created and is publicly resolvable."
echo


# =========================================================
# Run Certbot
# =========================================================

docker run --rm -it \
  -v "$ETC_DIR:/etc/letsencrypt" \
  -v "$LIB_DIR:/var/lib/letsencrypt" \
  certbot/certbot certonly \
  --manual \
  --preferred-challenges dns \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  --cert-name "$CERT_NAME" \
  -d "$CERT_DOMAIN"


# =========================================================
# Certificate directory
# =========================================================

CERT_DIR="$LIVE_DIR/$CERT_NAME"


echo
echo "========================================"
echo " Certificate Request Completed"
echo "========================================"
echo

echo "Certificate:"
echo "  $CERT_DOMAIN"
echo

echo "Certificate directory:"
echo "  $CERT_DIR/"
echo


# =========================================================
# Dynamic certificate file menu
# =========================================================

while true; do

    echo
    echo "========================================"
    echo " Certificate Files"
    echo "========================================"
    echo

    echo "Directory:"
    echo "  $CERT_DIR"
    echo


    # -----------------------------------------------------
    # Read files and symbolic links dynamically
    # -----------------------------------------------------

    mapfile -t CERT_FILES < <(
        sudo find "$CERT_DIR" \
          -maxdepth 1 \
          \( -type f -o -type l \) \
          -printf '%f\n' 2>/dev/null |
        sort
    )


    if [[ ${#CERT_FILES[@]} -eq 0 ]]; then

        echo "No certificate files found."
        echo

        break

    fi


    echo "What would you like to print?"
    echo


    # -----------------------------------------------------
    # Dynamically build menu
    # -----------------------------------------------------

    for i in "${!CERT_FILES[@]}"; do

        printf "  %d) %s\n" \
          "$((i + 1))" \
          "${CERT_FILES[$i]}"

    done


    DETAILS_OPTION=$((${#CERT_FILES[@]} + 1))

    EXIT_OPTION=$((${#CERT_FILES[@]} + 2))


    echo "  $DETAILS_OPTION) Certificate details"
    echo "  $EXIT_OPTION) Exit"
    echo


    read -rp "Selection [1-$EXIT_OPTION]: " PRINT_OPTION


    # -----------------------------------------------------
    # Exit
    # -----------------------------------------------------

    if [[ "$PRINT_OPTION" == "$EXIT_OPTION" ]]; then

        echo
        echo "Exiting certificate menu."

        break

    fi


    # -----------------------------------------------------
    # Certificate details
    # -----------------------------------------------------

    if [[ "$PRINT_OPTION" == "$DETAILS_OPTION" ]]; then

        echo
        echo "========================================"
        echo " Certificate Details"
        echo "========================================"
        echo


        if [[ -f "$CERT_DIR/cert.pem" ]]; then

            sudo openssl x509 \
              -in "$CERT_DIR/cert.pem" \
              -noout \
              -subject \
              -issuer \
              -serial \
              -dates \
              -fingerprint \
              -sha256 \
              -ext subjectAltName

        else

            echo "ERROR: cert.pem was not found."

        fi


        echo

        continue

    fi


    # -----------------------------------------------------
    # Validate selection
    # -----------------------------------------------------

    if ! [[ "$PRINT_OPTION" =~ ^[0-9]+$ ]]; then

        echo
        echo "ERROR: Invalid selection."

        continue

    fi


    FILE_INDEX=$((PRINT_OPTION - 1))


    if (( FILE_INDEX < 0 || FILE_INDEX >= ${#CERT_FILES[@]} )); then

        echo
        echo "ERROR: Invalid selection."

        continue

    fi


    SELECTED_FILE="${CERT_FILES[$FILE_INDEX]}"


    # -----------------------------------------------------
    # Protect private key
    # -----------------------------------------------------

    if [[ "$SELECTED_FILE" == "privkey.pem" ]]; then

        echo
        echo "========================================"
        echo " WARNING: PRIVATE KEY"
        echo "========================================"
        echo

        echo "Anyone with this private key can impersonate"
        echo "the certificate."
        echo

        read -rp \
          "Are you sure you want to display it? [y/N]: " \
          KEY_CONFIRM


        if [[ ! "$KEY_CONFIRM" =~ ^[Yy]$ ]]; then

            echo
            echo "Private key not displayed."

            continue

        fi

    fi


    # -----------------------------------------------------
    # Print selected file
    # -----------------------------------------------------

    echo
    echo "========================================"
    echo " $SELECTED_FILE"
    echo "========================================"
    echo


    sudo cat "$CERT_DIR/$SELECTED_FILE"


    echo

done


# =========================================================
# Finished
# =========================================================

echo
echo "========================================"
echo " Done"
echo "========================================"
