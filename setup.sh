#!/bin/bash
# Laravel Accounts Backend - Development Environment Setup Script
# Author: Development Team
# Description: Automated setup script for WSL Ubuntu environment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
SKIP_COMPOSER=false
HELP=false
PHP_VERSION="8.1"

# Function to print colored output
print_success() { echo -e "${GREEN}$1${NC}"; }
print_info() { echo -e "${CYAN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }

# Help function
show_help() {
    print_info "Laravel Accounts Backend - Development Environment Setup"
    print_info "Usage: ./setup.sh [options]"
    echo ""
    print_info "Options:"
    print_info "  --skip-composer         Skip Composer installation"
    print_info "  -h, --help              Show this help message"
    echo ""
    print_info "Examples:"
    print_info "  ./setup.sh                        # Setup local development environment"
    print_info "  ./setup.sh --skip-composer       # Skip Composer installation"
    echo ""
    print_info "This script sets up a local development environment for WSL Ubuntu."
    print_info "Features: SQLite databases, file-based caching, debug mode enabled"
    print_info "Automatically installs PHP 8.1 if not present or if wrong version detected"
    print_info "Configures PHP version management using update-alternatives for easy switching"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-composer)
            SKIP_COMPOSER=true
            shift
            ;;
        -h|--help)
            HELP=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [[ "$HELP" == true ]]; then
    show_help
    exit 0
fi

print_info "======================================"
print_info "Laravel Accounts Backend Setup Script"
print_info "Environment: Local Development"
print_info "Target: WSL Ubuntu"
print_info "======================================"

# Prevent running entire script as sudo
if [[ $EUID -eq 0 ]]; then
    print_error "❌ Do not run this script as sudo/root!"
    print_info "The script will prompt for sudo when needed for system operations."
    print_info "Running as root would cause file ownership issues."
    print_info ""
    print_info "Please run as your normal user:"
    print_info "  ./setup.sh"
    exit 1
fi

# Check if running in WSL
if ! grep -qi microsoft /proc/version 2>/dev/null; then
    print_warning "This script is optimized for WSL Ubuntu environment."
    print_warning "Detected environment: $(uname -a)"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Setup cancelled."
        exit 0
    fi
else
    print_info "✓ WSL environment detected"
fi

# Check sudo access and prompt for password early
check_sudo_access() {
    print_info "Checking sudo access..."
    if ! sudo -n true 2>/dev/null; then
        print_warning "This script requires sudo access to install packages and configure the system."
        print_info "You will be prompted for your password."
        echo ""
        if ! sudo -v; then
            print_error "✗ Unable to obtain sudo access. Exiting."
            print_info "Make sure your user is in the sudo group: sudo usermod -aG sudo $USER"
            exit 1
        fi
    fi
    print_success "✓ Sudo access confirmed"
    print_info "Note: You may be prompted for your password again during long operations."
    echo ""
}

# Keep sudo timestamp fresh during long operations
refresh_sudo() {
    # Only refresh if more than 5 minutes have passed
    if ! sudo -n true 2>/dev/null; then
        print_info "Refreshing sudo access..."
        sudo -v
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to ensure update-alternatives is available
ensure_update_alternatives() {
    print_info "Checking update-alternatives availability..."
    
    if command_exists update-alternatives; then
        print_success "✓ update-alternatives is available"
        return 0
    fi
    
    print_info "update-alternatives not found, installing..."
    refresh_sudo
    
    # Install update-alternatives (part of dpkg package on Ubuntu)
    if sudo apt-get install -y dpkg 2>/dev/null; then
        print_success "✓ update-alternatives installed"
    else
        print_error "✗ Failed to install update-alternatives"
        print_info "This may affect PHP version management"
        return 1
    fi
}

# Function to install package manager and update system
update_system() {
    print_info "Updating system packages..."
    print_info "This may take a few minutes depending on your system..."
    
    # Refresh sudo timestamp
    refresh_sudo
    
    sudo apt-get update -y
    print_info "Installing system upgrades..."
    sudo apt-get upgrade -y
    print_info "Installing essential tools..."
    sudo apt-get install -y software-properties-common curl wget unzip git
    print_success "✓ System updated and basic tools installed"
}

# Function to check PHP version and install if needed
install_php() {
    print_info "Checking PHP installation and version management..."

    # Ensure update-alternatives is available first
    ensure_update_alternatives

    # Check if PHP is installed and get version
    if command_exists php; then
        CURRENT_PHP_VERSION=$(php -v | head -n 1 | grep -oP 'PHP \K[0-9]+\.[0-9]+')
        print_info "Current active PHP version: $CURRENT_PHP_VERSION"
        
        # Check if it's the correct version
        if [[ "$CURRENT_PHP_VERSION" == "$PHP_VERSION" ]]; then
            print_success "✓ PHP $PHP_VERSION is already installed and active"
            
            # Ensure it's properly managed by update-alternatives
            configure_php_alternatives
            
            # Verify required extensions are installed
            check_php_extensions
            return
        else
            print_warning "PHP $CURRENT_PHP_VERSION is active, but we need PHP $PHP_VERSION"
            
            # Check if PHP 8.1 is already installed but not active
            if command_exists "php$PHP_VERSION"; then
                print_info "PHP $PHP_VERSION is installed but not active"
                print_info "Configuring PHP version management..."
                configure_php_alternatives
                verify_php_installation
                check_php_extensions
                return
            else
                print_info "Will install PHP $PHP_VERSION alongside existing version"
            fi
        fi
    else
        print_info "PHP not found. Installing PHP $PHP_VERSION..."
    fi

    # Install PHP 8.1
    setup_php_installation

    # Configure PHP alternatives
    configure_php_alternatives

    # Verify installation
    verify_php_installation

    # Check extensions
    check_php_extensions
}

# Function to setup PHP installation
setup_php_installation() {
    print_info "Setting up PHP $PHP_VERSION for Ubuntu..."

    # Refresh sudo timestamp
    refresh_sudo

    # Add Ondrej Sury's PHP PPA (the most reliable source for multiple PHP versions)
    if ! grep -q "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        print_info "Adding Ondrej PHP repository..."
        print_info "You may be prompted to press Enter to continue..."
        sudo add-apt-repository ppa:ondrej/php -y
        sudo apt-get update -y
    else
        print_info "Ondrej PHP repository already added"
    fi

    # Install PHP 8.1 and required extensions
    print_info "Installing PHP $PHP_VERSION and extensions..."
    print_info "This may take several minutes..."
    
    # Refresh sudo timestamp before long operation
    refresh_sudo
    
    sudo apt-get install -y \
        php$PHP_VERSION \
        php$PHP_VERSION-cli \
        php$PHP_VERSION-common \
        php$PHP_VERSION-curl \
        php$PHP_VERSION-mbstring \
        php$PHP_VERSION-mysql \
        php$PHP_VERSION-xml \
        php$PHP_VERSION-zip \
        php$PHP_VERSION-gd \
        php$PHP_VERSION-soap \
        php$PHP_VERSION-sqlite3 \
        php$PHP_VERSION-intl \
        php$PHP_VERSION-bcmath \
        php$PHP_VERSION-fpm \
        php$PHP_VERSION-dev
}

# Function to configure PHP alternatives
configure_php_alternatives() {
    print_info "Configuring PHP version management with update-alternatives..."
    
    if ! command_exists update-alternatives; then
        print_error "✗ update-alternatives not available. Cannot manage PHP versions."
        return 1
    fi
    
    # Refresh sudo access
    refresh_sudo
    
    # Find all installed PHP versions
    local php_versions=()
    for php_bin in /usr/bin/php*; do
        if [[ -x "$php_bin" && "$php_bin" =~ /usr/bin/php[0-9]+\.[0-9]+$ ]]; then
            php_version=$(basename "$php_bin" | sed 's/php//')
            php_versions+=("$php_version")
        fi
    done
    
    if [[ ${#php_versions[@]} -eq 0 ]]; then
        print_warning "No PHP versions found in /usr/bin/"
        return 1
    fi
    
    print_info "Found PHP versions: ${php_versions[*]}"
    
    # Remove existing PHP alternatives to start fresh
    if update-alternatives --query php >/dev/null 2>&1; then
        print_info "Removing existing PHP alternatives configuration..."
        sudo update-alternatives --remove-all php >/dev/null 2>&1 || true
    fi
    
    # Configure alternatives for all found PHP versions
    local priority=100
    for version in "${php_versions[@]}"; do
        if [[ -x "/usr/bin/php$version" ]]; then
            print_info "Adding PHP $version to alternatives (priority: $priority)"
            sudo update-alternatives --install /usr/bin/php php "/usr/bin/php$version" $priority
            
            # Give higher priority to our target version
            if [[ "$version" == "$PHP_VERSION" ]]; then
                priority=$((priority + 50))
            else
                priority=$((priority + 10))
            fi
        fi
    done
    
    # Set the target PHP version as default
    if [[ -x "/usr/bin/php$PHP_VERSION" ]]; then
        print_info "Setting PHP $PHP_VERSION as the default version..."
        sudo update-alternatives --set php "/usr/bin/php$PHP_VERSION"
        print_success "✓ PHP $PHP_VERSION configured as default"
        
        # Show current alternatives
        print_info "PHP version management configured. Available versions:"
        update-alternatives --list php | while read -r php_path; do
            version=$(basename "$php_path" | sed 's/php//')
            if [[ "$php_path" == "/usr/bin/php$PHP_VERSION" ]]; then
                print_info "  → PHP $version (active)"
            else
                print_info "    PHP $version"
            fi
        done
        
        print_info ""
        print_info "💡 To switch PHP versions later, use:"
        print_info "   sudo update-alternatives --config php"
        
    else
        print_error "✗ PHP $PHP_VERSION not found at /usr/bin/php$PHP_VERSION"
        return 1
    fi
}

# Function to verify PHP installation
verify_php_installation() {
    # Verify PHP installation
    if command_exists php; then
        PHP_VERSION_OUTPUT=$(php -v | head -n 1)
        print_success "✓ PHP installed: $PHP_VERSION_OUTPUT"
        
        # Check if it's the right version
        if php -v | grep -q "PHP $PHP_VERSION"; then
            print_success "✓ PHP $PHP_VERSION is active"
        else
            print_error "✗ PHP $PHP_VERSION installed but may not be the active version"
            print_info "Current active version: $(php -v | head -n 1)"
            print_info "You may need to manually switch versions or check your PATH"
            exit 1
        fi
    else
        print_error "✗ PHP installation failed"
        exit 1
    fi
}

# Function to check PHP extensions
check_php_extensions() {
    print_info "Checking required PHP extensions..."
    
    REQUIRED_EXTENSIONS=(
        "soap"
        "sqlite3"
        "curl"
        "mbstring"
        "mysql"
        "xml"
        "zip"
        "gd"
        "intl"
        "bcmath"
    )
    
    MISSING_EXTENSIONS=()
    
    for ext in "${REQUIRED_EXTENSIONS[@]}"; do
        if php -m | grep -q "^$ext$"; then
            echo "  ✓ $ext"
        else
            echo "  ✗ $ext (missing)"
            MISSING_EXTENSIONS+=("$ext")
        fi
    done
    
    if [[ ${#MISSING_EXTENSIONS[@]} -gt 0 ]]; then
        print_warning "Missing extensions detected. Installing..."
        refresh_sudo
        
        for ext in "${MISSING_EXTENSIONS[@]}"; do
            sudo apt-get install -y "php$PHP_VERSION-$ext"
        done
        
        print_success "✓ Missing extensions installed"
    else
        print_success "✓ All required PHP extensions are installed"
    fi
}

# Function to install Composer
install_composer() {
    if [[ "$SKIP_COMPOSER" == true ]]; then
        print_warning "Skipping Composer installation"
        return
    fi

    if ! command_exists composer; then
        print_info "Installing Composer..."
        
        # Download and verify Composer installer
        print_info "Downloading Composer installer..."
        cd /tmp
        curl -sS https://getcomposer.org/installer -o composer-setup.php
        
        # Verify installer (optional but recommended)
        print_info "Verifying Composer installer..."
        HASH="$(curl -sS https://composer.github.io/installer.sig)"
        php -r "if (hash_file('SHA384', 'composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
        
        # Install Composer globally
        print_info "Installing Composer globally (requires sudo)..."
        sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
        rm composer-setup.php
        
        # Return to project directory
        cd - > /dev/null
        
        if command_exists composer; then
            print_success "✓ Composer installed successfully"
            composer --version
        else
            print_error "✗ Composer installation failed"
            exit 1
        fi
    else
        print_success "✓ Composer already installed"
        composer --version
    fi
}

# Function to setup environment file
setup_environment() {
    print_info "Setting up local development environment configuration..."
    
    # Create environment indicator file
    echo "local" > .env.environment
    print_success "✓ Environment set to local development"
    
    # Create .env file with "local" if it doesn't exist
    if [[ ! -f ".env" ]]; then
        echo "local" > .env
        print_success "✓ Created .env file with local environment"
    else
        print_warning "Existing .env file found"
        read -p "Overwrite existing .env file? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "local" > .env
            print_success "✓ Overwritten .env file with local environment"
        else
            print_info "Keeping existing .env file"
        fi
    fi
}

# Function to create SQLite databases
setup_sqlite() {
    print_info "Setting up SQLite databases..."
    
    mkdir -p database
    
    DATABASES=(
        "database/primary_database.sqlite"
        "database/myaccount_database.sqlite"
        "database/mycircle_database.sqlite"
    )
    
    for db in "${DATABASES[@]}"; do
        if [[ ! -f "$db" ]]; then
            touch "$db"
            print_success "✓ Created SQLite database: $db"
        else
            print_info "SQLite database already exists: $db"
        fi
    done
}

# Function to install Composer dependencies
install_dependencies() {
    print_info "Installing Composer dependencies..."
    
    # Check if composer.json exists
    if [[ ! -f "composer.json" ]]; then
        print_error "composer.json not found in current directory"
        exit 1
    fi
    
    # Set Composer to use more memory (helpful for large projects)
    export COMPOSER_MEMORY_LIMIT=-1
    
    # Install or update dependencies
    if [[ -f "composer.lock" ]]; then
        print_info "composer.lock found, running 'composer install'..."
        composer install --no-interaction --optimize-autoloader
    else
        print_info "No composer.lock found, running 'composer update'..."
        composer update --no-interaction --optimize-autoloader
    fi
    
    if [[ $? -eq 0 ]]; then
        print_success "✓ Composer dependencies installed successfully"
    else
        print_error "✗ Failed to install Composer dependencies"
        print_info "This might be due to:"
        print_info "  - Missing authentication for private repositories"
        print_info "  - Network connectivity issues"
        print_info "  - Memory limits"
        print_info ""
        print_info "You may need to:"
        print_info "  - Configure Git/GitLab SSH keys"
        print_info "  - Set up Composer authentication tokens"
        print_info "  - Run 'composer install' manually with verbose output"
        
        read -p "Continue with setup anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to setup Laravel
setup_laravel() {
    print_info "Setting up Laravel application..."
    
    # Generate application key if not exists
    if ! grep -q "APP_KEY=base64:" .env 2>/dev/null; then
        php artisan key:generate --force
        print_success "✓ Application key generated"
    fi
    
    # Create storage and bootstrap/cache directories
    DIRS=(
        "storage/app/public"
        "storage/framework/cache"
        "storage/framework/sessions"
        "storage/framework/views"
        "storage/logs"
        "bootstrap/cache"
    )
    
    for dir in "${DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            print_info "Created directory: $dir"
        fi
    done
    
    # Set proper permissions
    chmod -R 775 storage bootstrap/cache
    
    # Create symbolic link for storage
    php artisan storage:link
    
    print_success "✓ Laravel application configured"
}

# Function to run database migrations
run_migrations() {
    print_info "Running database migrations..."
    
    if php artisan migrate --force 2>/dev/null; then
        print_success "✓ Database migrations completed"
    else
        print_warning "Database migrations failed - you may need to configure database connections"
    fi
}

# Main execution
main() {
    # Check sudo access first
    check_sudo_access
    
    # Update system and ensure update-alternatives is available
    update_system
    ensure_update_alternatives
    
    install_php
    install_composer
    setup_environment
    setup_sqlite
    install_dependencies
    setup_laravel
    run_migrations
    
    print_success ""
    print_success "======================================"
    print_success "🎉 Setup completed successfully!"
    print_success "======================================"
    print_info "Environment: Local Development"
    print_info "PHP Version: $(php -v | head -n 1)"
    print_info "Composer Version: $(composer --version)"
    echo ""
    print_info "📁 Project structure:"
    print_info "  └── .env.environment  (contains: local)"
    print_info "  └── .env              (local development configuration)"
    print_info "  └── database/         (SQLite databases for local development)"
    echo ""
    print_info "🔧 PHP Version Management:"
    print_info "  Current active: PHP $(php -v | head -n 1 | grep -oP 'PHP \K[0-9]+\.[0-9]+')"
    print_info "  Switch versions: sudo update-alternatives --config php"
    print_info "  List available: update-alternatives --list php"
    echo ""
    print_info "🚀 Next steps:"
    print_info "1. Review your .env file (configured for local development):"
    print_info "   nano .env"
    print_info ""
    print_info "2. Start the development server:"
    print_info "   php artisan serve"
    print_info ""
    print_info "3. Access your application:"
    print_info "   📱 Web: http://localhost:8000"
    print_info "   🔍 GraphQL: http://localhost:8000/graphql-playground"
    echo ""
    print_info "💡 Local Development Features:"
    print_info "  - SQLite databases (no MySQL setup required)"
    print_info "  - File-based caching and sessions"
    print_info "  - Mail logging (check storage/logs/laravel.log)"
    print_info "  - Debug mode enabled for development"
    print_info "  - PHP version management with update-alternatives"
}

# Run main function
main "$@"
