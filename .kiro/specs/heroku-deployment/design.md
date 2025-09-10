# Diseño: Deploy de mydialogform en Heroku

## Resumen

Este diseño establece la arquitectura y configuración necesaria para desplegar mydialogform en Heroku, considerando las especificidades de Rails 8, la arquitectura SuperAgent, y los requisitos de producción para una aplicación de formularios inteligentes.

## Arquitectura de Deployment

### Stack Tecnológico en Heroku
```
┌─────────────────────────────────────────────────────────────┐
│                    HEROKU PLATFORM                         │
├─────────────────────────────────────────────────────────────┤
│ Web Dynos (Rails App)                                       │
│ ├── Rails 8.0.2.1                                          │
│ ├── Ruby 3.3.0                                             │
│ ├── Puma Web Server                                         │
│ └── mydialogform Application                                │
├─────────────────────────────────────────────────────────────┤
│ Worker Dynos (Background Jobs)                              │
│ ├── Sidekiq Workers                                         │
│ ├── SuperAgent Workflows                                    │
│ └── Scheduled Jobs                                          │
├─────────────────────────────────────────────────────────────┤
│ Add-ons                                                     │
│ ├── Heroku Postgres (Database)                             │
│ ├── Heroku Redis (Cache & Jobs)                            │
│ ├── Heroku Scheduler (Cron Jobs)                           │
│ └── Papertrail (Logging - Optional)                        │
└─────────────────────────────────────────────────────────────┘
```

## Configuración de Heroku

### 1. Aplicación Base
```bash
# Crear aplicación
heroku create mydialogform-production

# Configurar buildpacks
heroku buildpacks:add heroku/nodejs
heroku buildpacks:add heroku/ruby
```

### 2. Add-ons Requeridos
```bash
# PostgreSQL (Base de datos)
heroku addons:create heroku-postgresql:essential-0

# Redis (Cache y Sidekiq)
heroku addons:create heroku-redis:mini

# Scheduler (Jobs recurrentes)
heroku addons:create scheduler:standard

# Logs centralizados (opcional)
heroku addons:create papertrail:choklad
```

### 3. Variables de Entorno

#### Variables Críticas de Rails
```bash
# Generar y configurar secret key
heroku config:set SECRET_KEY_BASE=$(rails secret)

# Configurar Rails para producción
heroku config:set RAILS_ENV=production
heroku config:set RAILS_SERVE_STATIC_FILES=true
heroku config:set RAILS_LOG_TO_STDOUT=true

# Master key para credentials
heroku config:set RAILS_MASTER_KEY=<contenido_de_config/master.key>
```

#### Variables de Aplicación
```bash
# Configuración de dominio
heroku config:set APP_DOMAIN=mydialogform-production.herokuapp.com

# Configuración de email (usando SendGrid)
heroku config:set SENDGRID_API_KEY=<api_key>
heroku config:set SMTP_ADDRESS=smtp.sendgrid.net
heroku config:set SMTP_PORT=587
heroku config:set SMTP_USERNAME=apikey

# Configuración de storage (AWS S3)
heroku config:set AWS_ACCESS_KEY_ID=<access_key>
heroku config:set AWS_SECRET_ACCESS_KEY=<secret_key>
heroku config:set AWS_REGION=us-east-1
heroku config:set AWS_BUCKET=mydialogform-uploads

# SuperAgent AI Configuration
heroku config:set OPENAI_API_KEY=<openai_key>
heroku config:set ANTHROPIC_API_KEY=<anthropic_key>
```

## Configuración de Archivos

### 1. Procfile
```ruby
# Procfile
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
release: bundle exec rails db:migrate
```

### 2. Configuración de Puma
```ruby
# config/puma.rb (ajustes para Heroku)
workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RAILS_ENV'] || 'development'

on_worker_boot do
  # Worker specific setup for Rails 4.1+
  ActiveRecord::Base.establish_connection
end
```

### 3. Configuración de Base de Datos
```yaml
# config/database.yml
production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

### 4. Configuración de Redis
```ruby
# config/initializers/redis.rb
if Rails.env.production?
  $redis = Redis.new(url: ENV['REDIS_URL'])
else
  $redis = Redis.new(host: 'localhost', port: 6379, db: 0)
end
```

### 5. Configuración de Sidekiq
```yaml
# config/sidekiq.yml
:concurrency: 3
:timeout: 25
:verbose: false
:queues:
  - critical
  - default
  - ai_processing
  - integrations
  - analytics

production:
  :concurrency: 5
```

## Configuración de Assets

### 1. Tailwind CSS en Producción
```ruby
# config/environments/production.rb
config.assets.css_compressor = nil # Tailwind maneja la compresión
config.assets.compile = false
config.assets.digest = true
```

### 2. Precompilación de Assets
```json
// package.json
{
  "scripts": {
    "build": "tailwindcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/tailwind.css --minify",
    "build:css": "tailwindcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/tailwind.css --minify"
  }
}
```

## Configuración de Seguridad

### 1. Configuración HTTPS
```ruby
# config/environments/production.rb
config.force_ssl = true
config.ssl_options = { redirect: { exclude: ->(request) { request.path =~ /health/ } } }
```

### 2. Configuración de CORS
```ruby
# config/application.rb
config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV['APP_DOMAIN']
    resource '*', headers: :any, methods: [:get, :post, :patch, :put, :delete, :options]
  end
end
```

### 3. Content Security Policy
```ruby
# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data, 'fonts.googleapis.com', 'fonts.gstatic.com'
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https, 'cdn.tailwindcss.com'
    policy.style_src   :self, :https, :unsafe_inline, 'fonts.googleapis.com'
  end
end
```

## Configuración de Monitoreo

### 1. Health Check Endpoint
```ruby
# config/routes.rb
get '/health', to: 'health#check'

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def check
    render json: { 
      status: 'ok', 
      timestamp: Time.current,
      version: Rails.application.class.module_parent_name
    }
  end
end
```

### 2. Logging Configuration
```ruby
# config/environments/production.rb
config.log_level = :info
config.log_tags = [ :request_id ]
config.logger = ActiveSupport::Logger.new(STDOUT)
```

## Configuración de Jobs y Scheduler

### 1. Sidekiq Web UI
```ruby
# config/routes.rb
require 'sidekiq/web'

Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq' if Rails.env.production?
end
```

### 2. Heroku Scheduler Jobs
```bash
# Configurar en Heroku Scheduler
# Job: bundle exec rails runner "ResponseVolumeCheckJob.perform_now"
# Frequency: Daily at 9:00 AM UTC
```

## Estrategia de Deployment

### 1. Preparación Pre-Deploy
1. **Verificar tests**: Ejecutar suite completa de tests
2. **Compilar assets**: Precompilar assets localmente para verificar
3. **Verificar credentials**: Asegurar que todas las keys estén configuradas
4. **Backup de datos**: Si hay datos existentes

### 2. Proceso de Deploy
1. **Push a Heroku**: `git push heroku main`
2. **Ejecutar migraciones**: Automático con `release` en Procfile
3. **Verificar dynos**: Confirmar que web y worker dynos están corriendo
4. **Smoke tests**: Verificar endpoints críticos

### 3. Post-Deploy Verification
1. **Health check**: Verificar `/health` endpoint
2. **Funcionalidad básica**: Login, registro, creación de formularios
3. **Background jobs**: Verificar que Sidekiq procesa jobs
4. **Integraciones**: Probar Google Sheets, email, etc.

## Configuración de Dominios

### 1. Dominio Personalizado (Opcional)
```bash
# Agregar dominio personalizado
heroku domains:add mydialogform.com
heroku domains:add www.mydialogform.com

# Configurar SSL
heroku certs:auto:enable
```

### 2. Configuración DNS
```
# Configurar en tu proveedor DNS
CNAME www mydialogform-production.herokuapp.com
ALIAS @ mydialogform-production.herokuapp.com
```

## Costos Estimados (USD/mes)

### Configuración Básica
- **Dyno Web (Basic)**: $7/mes
- **Dyno Worker (Basic)**: $7/mes  
- **Postgres (Essential-0)**: $5/mes
- **Redis (Mini)**: $3/mes
- **Scheduler**: Gratis
- **Total**: ~$22/mes

### Configuración Escalada
- **Dyno Web (Standard-1X)**: $25/mes
- **Dyno Worker (Standard-1X)**: $25/mes
- **Postgres (Standard-0)**: $50/mes
- **Redis (Premium-0)**: $15/mes
- **Total**: ~$115/mes

## Métricas de Éxito

### Performance
- Response time < 500ms para landing page
- Response time < 1s para dashboard
- Uptime > 99.5%

### Funcionalidad
- Todos los endpoints críticos funcionando
- Background jobs procesándose
- Integraciones operativas

### Monitoreo
- Logs accesibles y útiles
- Métricas de performance visibles
- Alertas configuradas para errores críticos