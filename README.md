# RebootEssentials

Hey there! This is my project to make setting up a new macOS environment way less painful. It's a simple repo that manages `.env` files and `brew install` text files to automate the setup process.

## What's the point of this?

Setting up a new macOS environment can be a real drag. I used to spend hours trying to get all my tools and scripts just right. That's where RebootEssentials comes in. I've curated a collection of `.env` files and `brew install` scripts to make this process a breeze.

## Features

- **Environment Configuration**: Easily manage your environment variables with `.env` files.
- **Homebrew Automation**: Automate the installation of essential software with `brew install` scripts.
- **Easy Setup**: Quickly set up a new macOS environment with minimal effort (I hear me say this a lot when setting up a new machine).

## Getting Started

So, wanna give it a try? Here's what you need to do:

1. **Clone the Repository**:
    ```sh
    git clone https://github.com/yourusername/RebootEssentials.git
    ```

2. **cd into the directory**:
    ```sh
    cd RebootEssentials
    ```

3. **Install Homebrew** (if it's not already installed):
    ```sh
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```

4. **Run the helper script**:
    ```sh
    ./backup_brew.sh
    ```

This script lets you back up and restore your Homebrew packages and categorize installed casks. By default it uses the `fabric` CLI with OpenAI models for categorization. If you'd rather use Azure OpenAI, set these variables before running the script:

```sh
export AZURE_OPENAI_ENDPOINT="https://your-resource.openai.azure.com"
export AZURE_OPENAI_DEPLOYMENT="your-deployment-name"
export AZURE_OPENAI_API_KEY="your-api-key"
export AZURE_OPENAI_API_VERSION="2024-05-15"
```

When these variables are set the script will call Azure OpenAI directly. The
values are saved to `~/.azure_openai_env` so you can reuse them later. Add

```sh
source ~/.azure_openai_env
```

to your `~/.bashrc` or `~/.zshrc` to automatically load the settings in every
terminal. Otherwise the script uses the model defined in `FABRIC_MODEL` (default
`openai/gpt-4o-mini-2024-07-18`) via Fabric.
