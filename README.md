# FacturaCircular Cliente

A modern Rails 8 web application for FacturaCircular client interface.

## Features

- **Rails 8.0.2.1** - Latest Rails framework with modern conventions
- **Tailwind CSS v4** - Modern utility-first CSS framework
- **Hotwire Stack** - Turbo and Stimulus for SPA-like interactions
- **Import Maps** - Modern JavaScript without bundling complexity
- **Docker Support** - Containerized development environment

## Development Setup

### Prerequisites

- Docker and Docker Compose
- Ruby 3.4.5 (if running locally)

### Quick Start with Docker

1. Clone the repository and navigate to the project:
   ```bash
   cd /Users/ludo/code/facturaCircularCliente
   ```

2. Start the application:
   ```bash
   docker-compose up -d
   ```

3. Visit the application:
   ```
   http://localhost:3002
   ```

### Development Commands

```bash
# Start the application
docker-compose up -d

# View logs
docker-compose logs -f web

# Open Rails console
docker-compose exec web bundle exec rails console

# Run commands inside container
docker-compose exec web bash

# Stop the application
docker-compose down
```

### Frontend Development

The application uses modern Rails 8 conventions:

- **Tailwind CSS**: Configure in `app/assets/tailwind/application.css`
- **Stimulus Controllers**: Add in `app/javascript/controllers/`
- **Import Maps**: Configure in `config/importmap.rb`

### Project Structure

```
├── app/
│   ├── javascript/          # Stimulus controllers and application.js
│   ├── assets/
│   │   └── tailwind/        # Tailwind CSS configuration
│   └── views/               # ERB templates
├── config/
│   └── importmap.rb         # JavaScript import configuration
├── docker-compose.yml       # Docker services
├── Dockerfile              # Container configuration
└── Procfile.dev            # Development process management
```

## Technology Stack

- **Backend**: Rails 8.0.2.1, Ruby 3.4.5
- **Frontend**: Tailwind CSS v4, Hotwire (Turbo + Stimulus)
- **JavaScript**: Import Maps (no bundling required)
- **Container**: Docker with development-optimized configuration

---
*Generated with Claude Code*
