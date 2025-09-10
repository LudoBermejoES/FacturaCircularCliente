# syntax = docker/dockerfile:1

# Use the official Ruby 3.4.5 image
FROM ruby:3.4.5-slim

# Rails app lives here
WORKDIR /rails

# Set development environment
ENV RAILS_ENV="development" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT=""

# Install packages needed for Rails
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    git \
    libvips \
    libyaml-dev && \
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
