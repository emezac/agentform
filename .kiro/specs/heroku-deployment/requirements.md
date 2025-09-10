# Deploy de mydialogform en Heroku

## Introducción

Necesitamos hacer deploy de la aplicación mydialogform en Heroku para que esté disponible públicamente. La aplicación es una plataforma de formularios inteligentes construida con Rails 8, PostgreSQL, Redis, y Sidekiq, que requiere una configuración específica para funcionar correctamente en producción.

## Requisitos

### Requisito 1: Configuración de Heroku

**Historia de Usuario:** Como desarrollador, quiero configurar correctamente la aplicación en Heroku para que funcione en producción.

**Criterios de Aceptación:**
1. CUANDO configure la aplicación en Heroku ENTONCES DEBE tener todos los addons necesarios
2. CUANDO configure las variables de entorno ENTONCES DEBEN incluir todas las claves necesarias
3. CUANDO configure el buildpack ENTONCES DEBE ser compatible con Rails 8 y Ruby 3.3

### Requisito 2: Base de Datos y Redis

**Historia de Usuario:** Como usuario de la aplicación, quiero que la base de datos y cache funcionen correctamente en producción.

**Criterios de Aceptación:**
1. CUANDO la aplicación se ejecute ENTONCES PostgreSQL DEBE estar configurado y funcionando
2. CUANDO se ejecuten jobs en background ENTONCES Redis DEBE estar disponible para Sidekiq
3. CUANDO se ejecuten migraciones ENTONCES DEBEN completarse sin errores

### Requisito 3: Variables de Entorno y Secretos

**Historia de Usuario:** Como administrador del sistema, quiero que todos los secretos y configuraciones estén seguros.

**Criterios de Aceptación:**
1. CUANDO se configure la aplicación ENTONCES todas las API keys DEBEN estar en variables de entorno
2. CUANDO se generen secretos ENTONCES DEBEN ser únicos y seguros
3. CUANDO se configure el dominio ENTONCES DEBE permitir el dominio de Heroku

### Requisito 4: Assets y Archivos Estáticos

**Historia de Usuario:** Como usuario final, quiero que la aplicación se vea y funcione correctamente.

**Criterios de Aceptación:**
1. CUANDO se cargue la aplicación ENTONCES todos los CSS y JS DEBEN funcionar
2. CUANDO se suban archivos ENTONCES DEBEN almacenarse correctamente
3. CUANDO se acceda a imágenes ENTONCES DEBEN cargarse sin problemas

### Requisito 5: Monitoreo y Logs

**Historia de Usuario:** Como desarrollador, quiero poder monitorear y debuggear la aplicación en producción.

**Criterios de Aceptación:**
1. CUANDO ocurran errores ENTONCES DEBEN aparecer en los logs de Heroku
2. CUANDO la aplicación tenga problemas ENTONCES DEBE ser fácil diagnosticar
3. CUANDO se ejecuten jobs ENTONCES DEBEN ser monitoreables

## Configuración Técnica Requerida

### Addons de Heroku Necesarios
- **Heroku Postgres** (Base de datos)
- **Heroku Redis** (Cache y Sidekiq)
- **Heroku Scheduler** (Para jobs recurrentes)
- **Papertrail** (Logs centralizados - opcional)

### Variables de Entorno Críticas
- `RAILS_ENV=production`
- `RAILS_MASTER_KEY` (para credentials)
- `DATABASE_URL` (automático con Postgres addon)
- `REDIS_URL` (automático con Redis addon)
- `SECRET_KEY_BASE`
- `RAILS_SERVE_STATIC_FILES=true`
- `RAILS_LOG_TO_STDOUT=true`

### Configuraciones de Aplicación
- Buildpack de Ruby
- Versión de Ruby 3.3.0
- Versión de Node.js para assets
- Configuración de Sidekiq web UI

## Criterios de Éxito

### Técnicos
- [ ] Aplicación desplegada y accesible vía URL de Heroku
- [ ] Base de datos PostgreSQL funcionando
- [ ] Redis y Sidekiq operativos
- [ ] Assets compilados y servidos correctamente
- [ ] Migraciones ejecutadas exitosamente

### Funcionales
- [ ] Landing page carga correctamente
- [ ] Usuarios pueden registrarse y hacer login
- [ ] Formularios se pueden crear y usar
- [ ] Integraciones funcionan (Google Sheets, etc.)
- [ ] Jobs en background se ejecutan

### Performance
- [ ] Tiempo de respuesta < 2 segundos
- [ ] Sin errores 500 en logs
- [ ] Memoria y CPU dentro de límites
- [ ] SSL/HTTPS funcionando

---

**Prioridad:** Alta
**Impacto:** Disponibilidad Pública
**Esfuerzo Estimado:** 4-6 horas
**Tipo:** Deployment y DevOps