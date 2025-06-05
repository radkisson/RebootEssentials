#!/usr/bin/env bash

BACKUP_DIR="brew_installs"
BACKUP_FORMULAE_FILE="$BACKUP_DIR/brew_formulae_backup.txt"
BACKUP_CASKS_FILE="$BACKUP_DIR/brew_casks_backup.txt"
CATEGORIZED_CASKS_CSV="$BACKUP_DIR/categorized_casks.csv"

# File used to persist Azure OpenAI configuration between runs
AZURE_CONFIG_FILE="$HOME/.azure_openai_env"

# Load persisted Azure configuration if available
if [ -f "$AZURE_CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    . "$AZURE_CONFIG_FILE"
fi


# Azure OpenAI configuration. If these variables are set the script will use
# Azure's API instead of the default OpenAI endpoint used by Fabric.
AZURE_OPENAI_ENDPOINT="${AZURE_OPENAI_ENDPOINT:-}"
AZURE_OPENAI_DEPLOYMENT="${AZURE_OPENAI_DEPLOYMENT:-}"
AZURE_OPENAI_API_KEY="${AZURE_OPENAI_API_KEY:-}"
AZURE_OPENAI_API_VERSION="${AZURE_OPENAI_API_VERSION:-2024-05-15}"

# Model used when calling Fabric (OpenAI). Can be overridden with FABRIC_MODEL
# environment variable.
FABRIC_MODEL="${FABRIC_MODEL:-openai/gpt-4o-mini-2024-07-18}"

# Ensure the backup directory exists
mkdir -p "$BACKUP_DIR"

# Remove existing CSV file
rm -f "$CATEGORIZED_CASKS_CSV"

# Check if Homebrew is installed, if not, install it
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo "Homebrew installed successfully."
fi

# Check if Fabric is installed, if not, prompt to install it
if ! command -v fabric &> /dev/null; then
    echo "Fabric not found. Please install Fabric."
    exit 1
fi

# If Azure OpenAI variables are set, ensure curl is available
if [ -n "$AZURE_OPENAI_ENDPOINT" ] && [ -n "$AZURE_OPENAI_DEPLOYMENT" ] && [ -n "$AZURE_OPENAI_API_KEY" ]; then
    if ! command -v curl &> /dev/null; then
        echo "curl is required for Azure OpenAI support." >&2
        exit 1
    fi
    if [ ! -f "$AZURE_CONFIG_FILE" ]; then
        persist_azure_config
    fi
fi

# Helper to send a prompt to Azure OpenAI if configured
azure_openai_complete() {
    local prompt="$1"
    local payload
    payload=$(printf '{"messages":[{"role":"user","content":"%s"}],"max_tokens":200,"temperature":0.0}' "$prompt")
    curl -sS -H "Content-Type: application/json" \
        -H "api-key: $AZURE_OPENAI_API_KEY" \
        -d "$payload" \
        "$AZURE_OPENAI_ENDPOINT/openai/deployments/$AZURE_OPENAI_DEPLOYMENT/chat/completions?api-version=$AZURE_OPENAI_API_VERSION" |
        python3 -c "import sys, json; print(json.load(sys.stdin)['choices'][0]['message']['content'].strip())"
}

# Persist Azure configuration to $AZURE_CONFIG_FILE if variables are provided
persist_azure_config() {
    cat > "$AZURE_CONFIG_FILE" <<EOF
export AZURE_OPENAI_ENDPOINT="$AZURE_OPENAI_ENDPOINT"
export AZURE_OPENAI_DEPLOYMENT="$AZURE_OPENAI_DEPLOYMENT"
export AZURE_OPENAI_API_KEY="$AZURE_OPENAI_API_KEY"
export AZURE_OPENAI_API_VERSION="$AZURE_OPENAI_API_VERSION"
EOF
    echo "Saved Azure OpenAI configuration to $AZURE_CONFIG_FILE."
    echo "Add 'source $AZURE_CONFIG_FILE' to your shell startup file to load it automatically."
}

backup_brew() {
    echo "Backing up Homebrew packages and casks..."

    # Backup formulae
    echo "Backing up Homebrew formulae..."
    brew list --formula > "$BACKUP_FORMULAE_FILE"
    echo "Homebrew formulae backed up to $BACKUP_FORMULAE_FILE."

    # Backup casks
    echo "Backing up Homebrew casks..."
    brew list --cask > "$BACKUP_CASKS_FILE"
    echo "Homebrew casks backed up to $BACKUP_CASKS_FILE."
}

# Function to categorize casks using Fabric
categorize_casks() {
    echo "Categorizing Homebrew casks using Fabric..."

    # Read casks in chunks of 25
    chunk=()
    while read -r cask; do
        chunk+=("$cask")
        if [ ${#chunk[@]} -eq 25 ]; then
            process_chunk "${chunk[@]}"
            chunk=()
        fi
    done < "$BACKUP_CASKS_FILE"

    # Process any remaining casks
    if [ ${#chunk[@]} -gt 0 ]; then
        process_chunk "${chunk[@]}"
    fi

    echo "Categorized casks saved to $CATEGORIZED_CASKS_CSV."
}

process_chunk() {
    local casks=("$@")

    # Join casks into a single string
    local casks_str=$(IFS=,; echo "${casks[*]}")

    # echo "Processing chunk: $casks_str"  # Debugging line

    # Use Fabric to classify the casks with a more robust prompt
    local prompt="You are an expert in software categorization. Please classify the following Homebrew casks into one of the following CATEGORIES: Development Tools, Media and Graphics, Fonts, Utilities and System Tools, Productivity, Web Browsers, Games and Recreation, Networking and Security, Miscellaneous. For each cask, provide the category in the same row, separated by commas, in the next line the following cask, just as in a CSV file as in a pair (cask, CATEGORY). Example: git-credential-manager , Development Tools \\n. Here are the casks you have to classify into the CATEGORIES I named: $casks_str. ONLY ONE CATEGORY PER CASK. If you are unsure, the category is Miscellaneous. Don't add any other text not requested. Just the categorization. No politeness needed."

    if [ -n "$AZURE_OPENAI_ENDPOINT" ] && [ -n "$AZURE_OPENAI_DEPLOYMENT" ] && [ -n "$AZURE_OPENAI_API_KEY" ]; then
        selected_categories=$(azure_openai_complete "$prompt")
    else
        selected_categories=$(fabric -m "$FABRIC_MODEL" -t "$prompt" --temp=0.0 2>/dev/null)
    fi

    echo "$selected_categories"  # Debugging line

    # Split the response into an array
    IFS=',' read -r -a categories_array <<< "$selected_categories"

    # Append casks to the categorized casks CSV file
    for i in "${!casks[@]}"; do
        echo "${casks[$i]},${categories_array[$i]}" >> "$CATEGORIZED_CASKS_CSV"
    done
}

restore_brew() {
    echo "Choose what you want to restore:"
    options=("Formulae" "Casks" "Both" "Cancel")
    select opt in "${options[@]}"; do
        case $opt in
            "Formulae")
                echo "Reinstalling Homebrew formulae..."
                while read -r formula; do
                    echo "Installing $formula..."
                    brew install "$formula" && echo "$formula installed successfully." || echo "Failed to install $formula."
                done < "$BACKUP_FORMULAE_FILE"
                break
                ;;
            "Casks")
                echo "Reinstalling Homebrew casks..."
                while read -r cask; do
                    echo "Installing $cask..."
                    brew install --cask "$cask" && echo "$cask installed successfully." || echo "Failed to install $cask."
                done < "$BACKUP_CASKS_FILE"
                break
                ;;
            "Both")
                echo "Reinstalling Homebrew formulae..."
                while read -r formula; do
                    echo "Installing $formula..."
                    brew install "$formula" && echo "$formula installed successfully." || echo "Failed to install $formula."
                done < "$BACKUP_FORMULAE_FILE"

                echo "Reinstalling Homebrew casks..."
                while read -r cask; do
                    echo "Installing $cask..."
                    brew install --cask "$cask" && echo "$cask installed successfully." || echo "Failed to install $cask."
                done < "$BACKUP_CASKS_FILE"
                break
                ;;
            "Cancel")
                echo "Restore cancelled."
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
}

# Main menu
PS3='Please enter your choice: '
options=("Backup Homebrew" "Restore Homebrew" "Categorize Casks" "Exit")

select opt in "${options[@]}"; do
    case $opt in
        "Backup Homebrew")
            backup_brew
            break
            ;;
        "Restore Homebrew")
            restore_brew
            break
            ;;
        "Categorize Casks")
            categorize_casks
            break
            ;;
        "Exit")
            echo "Exiting."
            break
            ;;
        *)
            echo "Invalid option $REPLY"
            ;;
    esac
done
