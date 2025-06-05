# RebootEssentials

Hey there! This is my project to make setting up a new macOS environment way less painful. It's a simple repo that manages `.env` files and Homebrew package lists to automate the setup process.

## What's the point of this?

Setting up a new macOS environment can be a real drag. I used to spend hours getting all my tools and scripts just right. That's where RebootEssentials comes in. I've curated a collection of `.env` files and `brew install` scripts to make this process a breeze.

## Features

- **Environment Configuration**: Easily manage your environment variables with `.env` files.
- **Homebrew Automation**: Automate the installation of essential software with `brew install` scripts.
- **Easy Setup**: Quickly set up a new macOS environment with minimal effort (I hear myself say this a lot when setting up a new machine).

## Getting Started

So, wanna give it a try? Here's what you need to do:

1. **Clone the Repository**
   ```sh
   git clone https://github.com/yourusername/RebootEssentials.git
   ```
2. **Change into the directory**
   ```sh
   cd RebootEssentials
   ```
3. **Install Homebrew** (if it's not already installed)
   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
4. **Set up your environment variables**

   Copy `.env.example` to `.env` and edit it with your own values:
   ```sh
   cp .env.example .env
   # open .env in your favorite editor and customize it
   ```
   Load these variables whenever you open a new terminal session:
   ```sh
   source .env
   ```

5. **Install the saved software**

   Run the helper script and choose **Restore Homebrew** when prompted. This installs everything listed in `brew_installs/*.txt`.
   ```sh
   chmod +x backup_brew.sh
   ./backup_brew.sh
   ```

That's it! The script will take care of installing your packages and you'll be ready to go.
