#!/usr/bin/env bash

BACKUP_DIR="brew_installs"
BACKUP_FORMULAE_FILE="$BACKUP_DIR/brew_formulae_backup.txt"
BACKUP_CASKS_FILE="$BACKUP_DIR/brew_casks_backup.txt"
CATEGORIZED_CASKS_CSV="$BACKUP_DIR/categorized_casks.csv"

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

    selected_categories=$(fabric -m "openai/gpt-4o-mini-2024-07-18" -t "$prompt" --temp=0.0 2>/dev/null)

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