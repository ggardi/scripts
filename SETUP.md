# Laravel Accounts Backend - Development Environment Setup

This repository includes an automated setup script to help new developers quickly get their development environment configured for **WSL Ubuntu** on Windows.

## Quick Start

### WSL Ubuntu (Windows Subsystem for Linux)
```bash
# Make script executable (run this once)
chmod +x setup.sh

# Run the setup script
./setup.sh
```

## Setup Options

The script supports the following options:

### Skip Options
```bash
# Skip Composer installation (if already installed)
./setup.sh --skip-composer
```

### Help
```bash
./setup.sh --help
```

**Note:** This script only sets up a local development environment using SQLite databases and file-based caching for simplicity.

## What the Setup Script Does

1. **System Update**
   - Updates Ubuntu package repositories
   - Installs essential tools (curl, wget, unzip, git)

2. **PHP 8.1 Installation**
   - Checks if PHP 8.1 is already installed
   - If not present or wrong version, adds Ondrej Sury's PHP PPA (reliable PHP repository)
   - Installs PHP 8.1 with required extensions:
     - curl, mbstring, mysql, xml, zip, gd
     - soap, sqlite3, intl, bcmath, fpm, dev
   - Sets PHP 8.1 as the default version

3. **Composer Installation**
   - Checks if Composer is already installed
   - Downloads and verifies Composer installer if not present
   - Installs Composer globally

4. **Environment Configuration**
   - Creates `.env.environment` file with "local" environment
   - Creates `.env` file containing "local" if it doesn't already exist
   - If `.env` exists, prompts whether to overwrite it

5. **SQLite Database Setup**
   - Creates `database/` directory
   - Creates local SQLite database files:
     - `database/primary_database.sqlite`
     - `database/myaccount_database.sqlite`
     - `database/mycircle_database.sqlite`

6. **Dependency Installation**
   - Runs `composer install` (or `composer update` if no lock file)
   - Optimizes autoloader for better performance

7. **Laravel Configuration**
   - Generates application key
   - Creates required directories with proper permissions
   - Creates storage symbolic link
   - Runs database migrations (if possible)

## Post-Setup Configuration

After running the setup script:

1. **Review and Configure Environment**
   - Edit your `.env` file to add proper Laravel configuration
   - The script creates a minimal `.env` file with just "local" - you'll need to add:
     - APP_KEY (generated automatically by the script)
     - Database settings (SQLite paths are set up automatically)
     - API keys and secrets as needed

2. **Start Development Server**
   ```bash
   php artisan serve
   ```

3. **Access Your Application**
   - Web: http://localhost:8000
   - GraphQL Playground: http://localhost:8000/graphql-playground

## Manual Setup (Alternative)

If you prefer to set up manually or the automated script doesn't work in your WSL environment:

### 1. Install PHP 8.1
```bash
# Add Ondrej PHP repository
sudo add-apt-repository ppa:ondrej/php
sudo apt update

# Install PHP 8.1 and extensions
sudo apt install php8.1 php8.1-cli php8.1-common php8.1-curl php8.1-mbstring php8.1-mysql php8.1-xml php8.1-zip php8.1-gd php8.1-soap php8.1-sqlite3 php8.1-intl php8.1-bcmath php8.1-fpm php8.1-dev

# Set as default (if multiple PHP versions)
sudo update-alternatives --set php /usr/bin/php8.1
```

### 2. Install Composer
```bash
cd /tmp
curl -sS https://getcomposer.org/installer -o composer-setup.php
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php
```

### 3. Setup Project (if manually cloned)
```bash
# If you cloned the project manually, navigate to it
cd accounts-backend

# Install dependencies
composer install

# Setup environment
echo "local" > .env.environment
echo "local" > .env

# Generate app key
php artisan key:generate

# Create SQLite databases
mkdir -p database
touch database/primary_database.sqlite
touch database/myaccount_database.sqlite
touch database/mycircle_database.sqlite

# Setup Laravel
php artisan storage:link
php artisan migrate
```

## Environment Files

The project is configured for local development with minimal setup:

- `.env.environment` - Contains the environment indicator ("local")
- `.env` - Contains the environment configuration ("local")

The setup script will:
1. Create `.env.environment` with "local"
2. Create `.env` with "local" if it doesn't exist, or prompt to overwrite if it does

## Troubleshooting

### PHP Extensions Missing
If you get errors about missing PHP extensions:

```bash
# Install missing extensions for PHP 8.1
sudo apt install php8.1-[extension-name]

# Example:
sudo apt install php8.1-soap php8.1-sqlite3
```

### Composer Authentication
For private repositories, you may need to configure authentication:

```bash
# For GitLab (if using SSH keys)
composer config --global gitlab-token.gitlab.com [your-token]

# For GitHub
composer config --global github-oauth.github.com [your-token]
```

### Permission Issues
```bash
# Fix storage and cache permissions
sudo chmod -R 775 storage bootstrap/cache
sudo chown -R $USER:$USER storage bootstrap/cache
```

### Database Connection Issues
1. Verify database credentials in `.env`
2. Ensure database servers are running
3. Test connection: `php artisan tinker` then `DB::connection()->getPdo()`

## Development Workflow

1. **Start Development Server**
   ```bash
   php artisan serve
   ```

2. **Run Tests**
   ```bash
   vendor/bin/phpunit
   ```

3. **Code Quality**
   ```bash
   # Run PHPStan
   vendor/bin/phpstan analyse

   # Run PHP CS Fixer
   vendor/bin/php-cs-fixer fix
   ```

4. **Queue Processing** (if needed)
   ```bash
   php artisan horizon
   ```

## Additional Tools

### Laravel Horizon
For queue monitoring: http://localhost:8000/horizon

### GraphQL Playground
Interactive GraphQL IDE: http://localhost:8000/graphql-playground

### API Documentation
Check `graphql_readme.md` for GraphQL schema documentation.

## Getting Help

If you encounter issues:

1. Check the troubleshooting section above
2. Verify all prerequisites are installed
3. Check the Laravel logs: `storage/logs/laravel.log`
4. Contact the development team

## Contributing

When adding new dependencies or environment variables:

1. Update the setup scripts
2. Update this README
3. Update environment example files
4. Test the setup on a clean environment
