# syntax = docker/dockerfile:1

# Use the official Ruby 3.4.5 image
FROM ruby:3.4.5-slim

# Rails app lives here
WORKDIR /rails

# Set development environment
ENV RAILS_ENV="development" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT=""

# Install packages needed for Rails and Chrome for testing
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    git \
    libvips \
    libyaml-dev \
    wget \
    gnupg \
    unzip \
    xvfb \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libexpat1 \
    libgbm1 \
    libgcc-s1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libvulkan1 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    lsb-release && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Chromium browser for Selenium tests (more compatible than Chrome)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    chromium \
    chromium-driver && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Node.js and Yarn for Rails asset pipeline
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Update gems and bundler
RUN gem update --system --no-document && \
    gem install -N bundler

# Copy Gemfile first if it exists
COPY Gemfile* ./

# Install gems if Gemfile exists
RUN if [ -f Gemfile ]; then bundle install; fi

# Copy package files if they exist
COPY package*.json yarn.lock* ./

# Install node modules if package.json exists
RUN if [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
    elif [ -f package-lock.json ]; then npm ci; \
    elif [ -f package.json ]; then npm install; fi

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p tmp/pids log storage

# Expose port
EXPOSE 3000

# Default command
CMD ["bash"]
