#!/bin/bash

# Define variables
VAULT_NAME="Grubpass"
SECRET_NAME="GrubPassword"
CLIENT_ID="b0415457-3633-4446-aae0-cf236a54d1a2"
CLIENT_SECRET="660bea69-940b-4f53-92f8-74c5d31e423b"
TENANT_ID="c88fe011-1411-4e3a-a2cf-3859b305642c"

# Detect OS type
OS_TYPE=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')

# Install dependencies based on OS
case "$OS_TYPE" in
    ubuntu)
        sudo apt update && sudo apt install -y jq grub-pc
        ;;
    rhel | centos)
        sudo yum install -y jq grub2-pc
        ;;
    amzn)
        sudo amazon-linux-extras enable epel -y
        sudo yum install -y jq grub2
        ;;
    *)
        echo "Unsupported OS: $OS_TYPE"
        exit 1
        ;;
esac

# Get access token
ACCESS_TOKEN=$(curl -s -X POST -d "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&scope=https://vault.azure.net/.default&grant_type=client_credentials" https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token | jq -r .access_token)

# Retrieve password from Azure Key Vault
GRUB_PASSWORD=$(curl -s -X GET -H "Authorization: Bearer $ACCESS_TOKEN" "https://$VAULT_NAME.vault.azure.net/secrets/$SECRET_NAME?api-version=7.3" | jq -r .value)

# Generate hashed password
HASHED_PASSWORD=$(echo -e "$GRUB_PASSWORD\n$GRUB_PASSWORD" | grub-mkpasswd-pbkdf2 | awk '/PBKDF2 hash of your password is/{print $NF}')

# Update GRUB configuration based on OS
case "$OS_TYPE" in
    ubuntu)
        echo 'set superusers="root"' | sudo tee -a /etc/grub.d/40_custom
        echo "password_pbkdf2 root $HASHED_PASSWORD" | sudo tee -a /etc/grub.d/40_custom
        sudo update-grub
        ;;
    centos|amzn)
        echo 'set superusers="root"' | sudo tee -a /etc/grub.d/01_custom
        echo "password_pbkdf2 root $HASHED_PASSWORD" | sudo tee -a /etc/grub.d/01_custom
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
        ;;
esac

echo "GRUB password set successfully on $OS_TYPE!"

