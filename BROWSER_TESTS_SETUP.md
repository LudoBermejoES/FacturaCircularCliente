# Browser Tests Setup - Selenium Grid Solution

## Overview
This document describes the Selenium Grid setup for running browser tests in the Docker environment for the FacturaCircular client application.

## Architecture
- **Selenium Grid Container**: Separate container running Chromium browser
- **Web Application Container**: Rails app configured to connect to Selenium
- **Network Communication**: Containers communicate via Docker network

## Configuration Details

### 1. Docker Compose Configuration
The `docker-compose.yml` includes a Selenium service:

```yaml
selenium:
  container_name: factura-circular-selenium
  image: seleniarm/standalone-chromium:latest  # ARM64 compatible (Apple Silicon)
  shm_size: 2gb
  ports:
    - "4444:4444"  # Selenium Grid
    - "7900:7900"  # noVNC for debugging
  environment:
    - SE_NODE_MAX_SESSIONS=5
    - SE_NODE_SESSION_TIMEOUT=300
    - SE_VNC_NO_PASSWORD=1
    - SE_SCREEN_WIDTH=1920
    - SE_SCREEN_HEIGHT=1080
  networks:
    - factura-shared
```

### 2. Capybara Configuration
Located in `spec/support/capybara.rb`:
- Configured for remote Selenium driver
- Headless Chrome with proper arguments
- Automatic connection to Selenium Grid via HUB_URL

### 3. Rails Test Environment
Updated `config/environments/test.rb`:
- Added allowed hosts: `0.0.0.0` and `web`
- Enables proper host authorization for Docker networking

### 4. WebMock Configuration
Updated `spec/rails_helper.rb`:
- Allows connections to Selenium container
- Permits Capybara's internal endpoints

## Running Browser Tests

### Start Services
```bash
# Start all containers
docker-compose up -d

# Verify Selenium is ready
docker-compose exec web curl -s http://selenium:4444/wd/hub/status | grep ready
```

### Run Tests
```bash
# Run all feature tests (currently skipped)
docker-compose exec -e RAILS_ENV=test web bundle exec rspec spec/features

# Run specific feature test
docker-compose exec -e RAILS_ENV=test web bundle exec rspec spec/features/invoice_form_spec.rb
```

### Debug Browser Sessions
1. Open browser to http://localhost:7900
2. No password required (VNC_NO_PASSWORD=1)
3. Watch tests execute in real-time

## Test Status

### Current State
- ✅ **Infrastructure**: Selenium Grid fully configured and operational
- ✅ **Connection**: Tests can connect to Selenium and execute
- ⏸️ **Feature Tests**: Intentionally skipped (13 tests)
- ❌ **UI Elements**: Tests fail on missing forms (UI not yet implemented)

### Why Tests Are Skipped
Per user request, feature tests remain skipped with message:
"Feature tests require browser environment - run manually in development"

The infrastructure is ready but tests are skipped until:
1. UI forms are fully implemented
2. User explicitly requests to enable them

## Platform Notes

### Apple Silicon (M1/M2/M3)
Using `seleniarm/standalone-chromium:latest` for ARM64 compatibility

### Intel/AMD Processors
Can switch to `selenium/standalone-chrome:latest` if needed

## Troubleshooting

### Connection Issues
```bash
# Check Selenium status
docker-compose exec web curl http://selenium:4444/wd/hub/status

# Check container logs
docker-compose logs selenium

# Verify network connectivity
docker-compose exec web ping selenium
```

### Test Failures
- Screenshot saved in container at: `tmp/screenshots/`
- Access screenshots: `docker-compose exec web ls tmp/screenshots/`
- View browser session: http://localhost:7900

### Common Issues
1. **Host Authorization Error**: Fixed by adding hosts to test.rb
2. **WebMock Blocking**: Fixed by allowing Selenium in rails_helper.rb
3. **ARM64 Compatibility**: Fixed by using seleniarm image

## Next Steps
1. Implement UI forms (invoices, companies, etc.)
2. Remove skip statements when UI is ready
3. Add more comprehensive feature tests
4. Set up CI/CD pipeline with same configuration

## Success Metrics
- Selenium Grid container starts successfully ✅
- Tests can connect to remote browser ✅
- Browser sessions are stable ✅
- Screenshots can be captured on failure ✅
- noVNC debugging works ✅

---
*Last Updated: January 2025*
*Selenium Grid Version: 4.20.0*
*Chromium Version: 124.0*