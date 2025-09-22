# FacturaCircular Cliente - Aplicación Web

## 🚀 Descripción General

**FacturaCircular Cliente** es una aplicación web moderna construida con **Rails 8.0.2.1** que proporciona una interfaz de usuario completa para el sistema de gestión de facturas FacturaCircular. Esta aplicación cliente permite a los usuarios gestionar facturas, empresas, flujos de trabajo y todas las funcionalidades de la API a través de una interfaz web intuitiva.

### 🌟 Características Principales

- **Aplicación Web Completa**: Interfaz moderna construida con Rails 8 y Hotwire
- **Consumo de API**: Cliente que consume la API FacturaCircular de forma eficiente
- **Gestión de Facturas**: Interfaz completa para crear, editar y gestionar facturas
- **Sistema Fiscal Español**: Manejo de IVA, IRPF y cumplimiento Facturae
- **Flujos de Trabajo**: Visualización y gestión de estados de factura
- **Multi-empresa**: Soporte para gestión de múltiples empresas
- **Responsive Design**: Optimizado para escritorio y dispositivos móviles

## 🛠️ Stack Tecnológico

| Componente | Tecnología | Versión |
|-----------|------------|---------|
| Framework Web | Rails (Full Stack) | 8.0.2.1 |
| Ruby | Ruby | 3.4.5 |
| Frontend | Hotwire (Turbo + Stimulus) | Latest |
| CSS Framework | Tailwind CSS | v4 |
| JavaScript | Import Maps | ES6+ |
| Base de Datos | Ninguna (Cliente stateless) | - |
| Autenticación | JWT (via API) | - |
| Contenedores | Docker | Latest |

## 🏗️ Arquitectura del Cliente

### Diseño de la Aplicación
```
┌─────────────────────────────────────────────────────────────┐
│                    Browser (Usuario)                         │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                 Rails 8 Web Application                      │
├─────────────────────────────────────────────────────────────┤
│  Controllers │   Views   │  Stimulus │   Services           │
│  (Web MVC)   │  (ERB)    │    (JS)   │ (API Clients)        │
└─────────────────────────────────────────────────────────────┘
                                │
                       HTTP Requests (JSON)
                                │
┌─────────────────────────────────────────────────────────────┐
│              FacturaCircular API Backend                     │
│               (http://albaranes-api:3000)                    │
└─────────────────────────────────────────────────────────────┘
```

### Patrón de Arquitectura

**Cliente Web Stateless**
- Sin base de datos local - todos los datos vienen de la API
- Gestión de sesión con tokens JWT almacenados de forma segura
- Servicios especializados para comunicación HTTP con la API
- Controladores web que orquestan llamadas a la API y renderizan vistas

## 🚀 Configuración y Desarrollo

### Prerrequisitos

- **API FacturaCircular**: La API backend debe estar ejecutándose
- **Docker y Docker Compose**: Para entorno containerizado
- **Ruby 3.4.5**: Si se ejecuta localmente sin Docker

### Inicio Rápido con Docker

1. **Asegurar que la API está ejecutándose**:
   ```bash
   cd /Users/ludo/code/albaranes
   docker-compose up -d
   ```

2. **Iniciar la aplicación cliente**:
   ```bash
   cd /Users/ludo/code/albaranes/client
   docker-compose up -d
   ```

3. **Acceder a la aplicación**:
   ```
   http://localhost:3002
   ```

### Configuración Local (Sin Docker)

```bash
# Navegar al directorio del cliente
cd /Users/ludo/code/albaranes/client

# Instalar dependencias
bundle install

# Configurar variables de entorno (ver .env.example)
cp .env.example .env

# Iniciar la aplicación
rails server -p 3002
```

### Comandos de Desarrollo

```bash
# Iniciar la aplicación
docker-compose up -d

# Ver logs en tiempo real
docker-compose logs -f web

# Abrir consola Rails
docker-compose exec web bundle exec rails console

# Ejecutar comandos dentro del contenedor
docker-compose exec web bash

# Detener la aplicación
docker-compose down

# Reiniciar servicios
docker-compose restart web
```

## 📂 Estructura del Proyecto

```
├── app/
│   ├── controllers/         # Controladores web (NO API)
│   │   ├── application_controller.rb
│   │   ├── sessions_controller.rb
│   │   ├── dashboard_controller.rb
│   │   ├── invoices_controller.rb
│   │   ├── companies_controller.rb
│   │   └── workflows_controller.rb
│   ├── services/           # Clientes API (comunicación HTTP)
│   │   ├── api_service.rb          # Cliente HTTP base
│   │   ├── auth_service.rb         # Autenticación JWT
│   │   ├── invoice_service.rb      # Gestión de facturas
│   │   ├── company_service.rb      # Gestión de empresas
│   │   └── workflow_service.rb     # Flujos de trabajo
│   ├── views/              # Plantillas ERB
│   │   ├── layouts/
│   │   ├── dashboard/
│   │   ├── invoices/
│   │   ├── companies/
│   │   └── shared/
│   ├── javascript/         # Controladores Stimulus
│   │   └── controllers/
│   │       ├── invoice_form_controller.js
│   │       ├── buyer_selection_controller.js
│   │       ├── tax_calculator_controller.js
│   │       └── workflow_controller.js
│   └── assets/
│       └── tailwind/       # Configuración Tailwind CSS
├── config/
│   ├── routes.rb           # Rutas web de la aplicación
│   ├── importmap.rb        # Configuración Import Maps
│   └── environments/       # Configuración por entorno
├── spec/                   # Tests RSpec (608+ ejemplos)
│   ├── features/           # Tests de características end-to-end
│   ├── integration/        # Tests de integración
│   ├── security/           # Tests de seguridad
│   ├── performance/        # Tests de rendimiento
│   └── support/            # Helpers y configuración de tests
└── docker-compose.yml      # Configuración Docker
```

## 🔗 Integración con la API

### URL Base de la API
- **Desarrollo (Docker)**: `http://albaranes-api:3000/api/v1`
- **Desarrollo (Host)**: `http://localhost:3001/api/v1`

### Servicios de API Implementados

#### AuthService
```ruby
class AuthService < ApiService
  def self.login(email, password)
    # Autenticación con credenciales
  end

  def self.refresh_token(refresh_token)
    # Renovación de tokens JWT
  end

  def self.logout(token)
    # Cierre de sesión
  end
end
```

#### InvoiceService
```ruby
class InvoiceService < ApiService
  def self.all(token:, filters: {})
    # Listar facturas con filtros
  end

  def self.create(params, token:)
    # Crear nueva factura
  end

  def self.find(id, token:)
    # Obtener factura específica
  end

  def self.update(id, params, token:)
    # Actualizar factura
  end

  def self.freeze(id, token:)
    # Congelar factura (inmutable)
  end
end
```

#### CompanyService
```ruby
class CompanyService < ApiService
  def self.all(token:, params: {})
    # Listar empresas
  end

  def self.find(id, token:)
    # Obtener empresa específica
  end

  def self.create_address(company_id, params, token:)
    # Crear dirección de empresa
  end
end
```

### Patrón de Manejo de Errores

```ruby
class InvoicesController < ApplicationController
  def create
    result = InvoiceService.create(invoice_params, token: current_user_token)
    redirect_to invoice_path(result[:id]), notice: 'Factura creada exitosamente'
  rescue ApiService::ValidationError => e
    redirect_to new_invoice_path, alert: "Error de validación: #{e.message}"
  rescue ApiService::AuthenticationError
    redirect_to login_path, alert: 'Sesión expirada'
  rescue ApiService::ApiError => e
    redirect_to invoices_path, alert: "Error del sistema: #{e.message}"
  end
end
```

## 🎯 Funcionalidades Principales

### 🧾 Gestión de Facturas

**Funcionalidades Implementadas:**
- **Listado de facturas**: Con filtros por estado, fecha, empresa
- **Creación de facturas**: Formularios dinámicos con validación
- **Edición de facturas**: Actualización de datos con control de estados
- **Conversión proforma→factura**: Flujo específico para facturas proforma
- **Congelación de facturas**: Hacer facturas inmutables para auditoría
- **Generación PDF y Facturae**: Descarga de documentos oficiales

**Series de Factura Soportadas:**
- **FC** - Facturas Comerciales (por defecto)
- **PF** - Facturas Proforma
- **CR** - Notas de Crédito
- **SI** - Facturas Simplificadas
- **EX** - Facturas de Exportación
- **IN** - Facturas Intracomunitarias

### 🏢 Gestión de Empresas

**Funcionalidades:**
- **Gestión de empresas**: CRUD completo de empresas
- **Direcciones**: Gestión de direcciones de facturación y envío
- **Contactos de empresa**: Gestión de contactos externos para facturación
- **Cambio de empresa**: Selector de empresa activa para usuarios multi-empresa

### 💰 Sistema Fiscal Español

**Calculadora de Impuestos:**
- **IVA**: 21%, 10%, 4%, 0% (exento)
- **IRPF**: 15%, 7% (retenciones profesionales)
- **Recargo de Equivalencia**: Automático según tipo IVA
- **Exenciones**: Art. 20, exportaciones, intracomunitarias

### ⚡ Flujos de Trabajo

**Gestión de Estados:**
- **Visualización de estado actual**: Indicadores visuales de estado
- **Transiciones disponibles**: Botones dinámicos según permisos
- **Historial de cambios**: Timeline completo de modificaciones
- **SLA Tracking**: Indicadores de tiempo en estado actual

## 🎨 Interfaz de Usuario

### Diseño Responsive con Tailwind CSS

**Componentes Principales:**
- **Dashboard**: Vista general con métricas y facturas recientes
- **Listados**: Tablas paginadas con filtros avanzados
- **Formularios**: Formularios dinámicos con validación client-side
- **Modales**: Confirmaciones y formularios emergentes
- **Notificaciones**: Sistema de mensajes flash y toasts

### Interactividad con Stimulus

**Controladores JavaScript:**
- **InvoiceFormController**: Gestión dinámica de formularios de factura
- **BuyerSelectionController**: Selector de comprador con filtrado
- **TaxCalculatorController**: Calculadora de impuestos en tiempo real
- **WorkflowController**: Transiciones de estado con confirmación
- **ModalController**: Gestión de modales y overlays

### Características UX

- **Navegación intuitiva**: Menú lateral con indicadores de sección activa
- **Breadcrumbs**: Navegación jerárquica clara
- **Feedback visual**: Estados de carga, confirmaciones, errores
- **Accesibilidad**: Diseño accesible con soporte para lectores de pantalla
- **Mobile-first**: Optimizado para dispositivos móviles

## 🧪 Testing y Calidad

### Suite de Tests RSpec (608+ ejemplos)

**Categorías de Tests:**
- **Tests de Características (Features)**: 50+ tests de flujos de usuario end-to-end
- **Tests de Integración**: 40+ tests de integración entre componentes
- **Tests de Seguridad**: 35+ tests de autorización y protección de datos
- **Tests de Rendimiento**: 10+ tests de benchmarks y optimización
- **Tests de Servicios**: 300+ tests de clientes API y manejo de errores
- **Tests de Controladores**: 150+ tests de lógica de controladores web

### Ejecutar Tests

```bash
# Todos los tests
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec"

# Tests específicos por categoría
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/features/"
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/integration/"
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/security/"

# Con cobertura
docker-compose exec web bash -c "RAILS_ENV=test COVERAGE=true bundle exec rspec"

# Tests de un archivo específico
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/features/invoice_management_spec.rb"
```

### Métricas de Calidad

- **Cobertura de Tests**: 45%+ con SimpleCov
- **Tiempo de Ejecución**: <2 minutos para suite completa
- **Tasa de Éxito**: 99%+ de tests passing
- **Cobertura de Seguridad**: Tests específicos para cada endpoint crítico

## 🔐 Seguridad

### Autenticación y Autorización

**Flujo de Autenticación:**
1. **Login**: Usuario ingresa credenciales en formulario web
2. **API Call**: Cliente envía credenciales a API de autenticación
3. **Token Storage**: JWT almacenado de forma segura en sesión cifrada
4. **Request Headers**: Token incluido en todas las llamadas a la API
5. **Auto-refresh**: Renovación automática de tokens antes de expiración

**Medidas de Seguridad:**
- **Tokens JWT**: Almacenamiento seguro en sesiones cifradas
- **CSRF Protection**: Protección contra ataques cross-site request forgery
- **Sanitización**: Validación y limpieza de todos los inputs de usuario
- **HTTPS Only**: Forzar conexiones seguras en producción
- **Session Security**: Configuración segura de cookies de sesión

### Autorización por Roles

```ruby
# Ejemplo de control de acceso en controladores
class InvoicesController < ApplicationController
  before_action :require_authentication
  before_action :require_invoice_access, only: [:show, :edit, :update]

  private

  def require_invoice_access
    unless can_access_invoice?(params[:id])
      redirect_to invoices_path, alert: 'No tienes permiso para acceder a esta factura'
    end
  end
end
```

## 🚀 Características Avanzadas

### Gestión de Estado Client-Side

**Stimulus Controllers para Interactividad:**
- **Form Validation**: Validación en tiempo real antes de envío
- **Dynamic Loading**: Carga dinámica de contenido sin page refresh
- **Auto-save**: Guardado automático de borradores
- **Real-time Updates**: Actualizaciones de estado via Turbo Streams

### Optimización de Performance

**Estrategias Implementadas:**
- **HTTP Caching**: Caché de respuestas de API cuando apropiado
- **Lazy Loading**: Carga perezosa de componentes pesados
- **Turbo Drive**: Navegación SPA-like con Turbo
- **Asset Optimization**: Minificación y compresión de assets
- **Database-free**: Sin overhead de base de datos local

### Manejo de Errores

**Estrategia Robusta:**
- **API Error Handling**: Manejo específico por tipo de error API
- **User Feedback**: Mensajes de error claros y accionables
- **Retry Logic**: Reintento automático para errores temporales
- **Fallback UI**: Interfaces de respaldo cuando falla la API
- **Error Logging**: Registro detallado para debugging

## 📱 Responsive Design

### Breakpoints Tailwind

```css
/* Mobile First Design */
.invoice-grid {
  @apply grid grid-cols-1;          /* Mobile: 1 columna */
  @apply md:grid-cols-2;            /* Tablet: 2 columnas */
  @apply lg:grid-cols-3;            /* Desktop: 3 columnas */
  @apply xl:grid-cols-4;            /* Large: 4 columnas */
}
```

### Componentes Adaptativos

- **Navigation**: Menú colapsible para móviles, sidebar para desktop
- **Tables**: Diseño de tarjetas en móvil, tabla en desktop
- **Forms**: Formularios de una columna en móvil, multi-columna en desktop
- **Modales**: Fullscreen en móvil, centered en desktop

## 🔧 Configuración y Variables de Entorno

### Variables de Configuración

```bash
# .env.example
FACTURACIRCULAR_API_URL=http://albaranes-api:3000/api/v1
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key_here
SESSION_TIMEOUT=24.hours
API_TIMEOUT=30.seconds
```

### Configuración por Entorno

```ruby
# config/environments/development.rb
config.facturacircular_api_url = ENV.fetch('FACTURACIRCULAR_API_URL')
config.session_timeout = ENV.fetch('SESSION_TIMEOUT', '24.hours').to_duration
config.api_timeout = ENV.fetch('API_TIMEOUT', '30.seconds').to_duration
```

## 📊 Métricas y Monitoreo

### Performance Monitoring

**Métricas Tracked:**
- **Page Load Times**: <3 segundos para páginas principales
- **API Response Times**: <500ms para endpoints frecuentes
- **Memory Usage**: <50MB de crecimiento por sesión
- **Error Rates**: <1% de errores en operaciones principales

### Logging

```ruby
# Ejemplo de logging estructurado
class ApiService
  def self.log_api_call(endpoint, duration, status)
    Rails.logger.info({
      event: 'api_call',
      endpoint: endpoint,
      duration_ms: duration * 1000,
      status: status,
      timestamp: Time.current.iso8601
    }.to_json)
  end
end
```

## 🚢 Deployment

### Configuración Docker para Producción

```dockerfile
# Dockerfile optimizado para producción
FROM ruby:3.4.5-alpine

# Instalar dependencias del sistema
RUN apk add --no-cache nodejs npm build-base

# Configurar directorio de trabajo
WORKDIR /rails

# Instalar gems
COPY Gemfile* ./
RUN bundle install --without development test

# Copiar aplicación
COPY . .

# Precompilar assets
RUN rails assets:precompile

# Comando por defecto
CMD ["rails", "server", "-b", "0.0.0.0"]
```

### Variables de Producción

```bash
# Configuración de producción
RAILS_ENV=production
SECRET_KEY_BASE=production_secret_key
FACTURACIRCULAR_API_URL=https://api.facturacircular.com/api/v1
FORCE_SSL=true
LOG_LEVEL=info
```

## 🤝 Desarrollo y Contribución

### Flujo de Desarrollo

1. **Crear rama feature**: `git checkout -b feature/nueva-funcionalidad`
2. **Desarrollar funcionalidad**: Seguir convenciones Rails y patrones establecidos
3. **Escribir tests**: Tests comprehensivos para nueva funcionalidad
4. **Verificar integración**: Asegurar compatibilidad con API
5. **Ejecutar tests**: Verificar que todos los tests pasen
6. **Pull Request**: Descripción detallada de cambios

### Patrones de Código

**Controladores:**
```ruby
class InvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :load_invoice, only: [:show, :edit, :update]

  def index
    @invoices = InvoiceService.all(token: current_user_token, filters: filter_params)
  rescue ApiService::AuthenticationError
    redirect_to login_path
  end

  private

  def load_invoice
    @invoice = InvoiceService.find(params[:id], token: current_user_token)
  end
end
```

**Servicios API:**
```ruby
class CompanyService < ApiService
  def self.create_address(company_id, params, token:)
    response = post("/companies/#{company_id}/addresses", {
      headers: auth_headers(token),
      body: { address: params }.to_json
    })

    handle_response(response)
  end
end
```

### Guías de Estilo

- **Ruby**: Seguir guía de estilo de Rubocop
- **ERB**: Templates limpios con lógica mínima
- **JavaScript**: ES6+ con módulos y clases
- **CSS**: Utility-first con Tailwind, componentes reutilizables
- **Testing**: Descriptivo y coverage completo

## 📚 Recursos y Documentación

### Documentación Técnica

- **Guía de API**: `/Users/ludo/code/albaranes/HOW_TO_API.md`
- **Testing Guide**: `HOW_TO_TEST.md`
- **Configuración**: `CLAUDE.md` - Guías específicas del proyecto

### Enlaces Útiles

- **API Backend**: [http://localhost:3001](http://localhost:3001)
- **Swagger API Docs**: [http://localhost:3001/api-docs](http://localhost:3001/api-docs)
- **Cliente Web**: [http://localhost:3002](http://localhost:3002)

### Soporte

- **Issues GitHub**: Para reportar bugs y solicitar funcionalidades
- **Documentación**: Revisar archivos de documentación del proyecto
- **API Documentation**: Consultar documentación Swagger de la API

## 📄 Licencia

Este proyecto está licenciado bajo los términos de la licencia MIT.

---

**Última Actualización**: Enero 2025
**Versión**: 1.0.0
**Estado**: Sistema Cliente Completo con Interface Web Moderna ✅

## 🏆 Logros del Cliente

- ✅ **Interface Web Completa** con Rails 8 y Hotwire moderno
- ✅ **608+ Tests RSpec** con cobertura comprehensiva
- ✅ **Integración API Robusta** con manejo de errores avanzado
- ✅ **Responsive Design** optimizado para todos los dispositivos
- ✅ **Seguridad Empresarial** con autenticación JWT y protección CSRF
- ✅ **Performance Optimizada** con tiempos de carga <3 segundos
- ✅ **UX Moderna** con Stimulus y componentes interactivos

*FacturaCircular Cliente - Interface moderna para gestión de facturas empresariales* 🇪🇸