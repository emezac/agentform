# Sistema de Notificaciones para Administradores - mydialogform

## 📋 Resumen del Sistema

El sistema de notificaciones para administradores permite monitorear todas las actividades importantes de los usuarios en tiempo real, proporcionando visibilidad completa sobre el crecimiento y la actividad de la plataforma.

## 🏗️ Arquitectura del Sistema

### Componentes Principales

1. **Modelo AdminNotification** (`app/models/admin_notification.rb`)
   - Almacena todas las notificaciones
   - Define tipos de eventos, prioridades y categorías
   - Incluye métodos para marcar como leído/no leído

2. **Servicio AdminNotificationService** (`app/services/admin_notification_service.rb`)
   - Centraliza la creación de notificaciones
   - Previene duplicados
   - Maneja broadcasting en tiempo real

3. **Controlador Admin::NotificationsController** (`app/controllers/admin/notifications_controller.rb`)
   - Panel de administración para ver notificaciones
   - Filtros por tipo, prioridad y estado
   - Acciones para marcar como leído/eliminar

4. **Jobs de Monitoreo**
   - `TrialExpirationCheckJob`: Verifica trials que expiran
   - `ResponseVolumeCheckJob`: Detecta volúmenes altos de respuestas
   - `NotificationCleanupJob`: Limpia notificaciones antiguas

## 📊 Tipos de Eventos Monitoreados

### Actividad de Usuarios
- **user_registered**: Nuevo usuario se registra
- **user_upgraded**: Usuario actualiza a premium
- **user_downgraded**: Usuario baja a plan básico
- **user_inactive**: Usuario inactivo por período prolongado

### Facturación y Trials
- **trial_started**: Usuario inicia trial premium
- **trial_expired**: Trial de usuario expira
- **trial_ending_soon**: Trial expira en 3 días
- **payment_failed**: Fallo en procesamiento de pago
- **payment_succeeded**: Pago procesado exitosamente

### Actividad de Formularios
- **form_created**: Nuevo formulario creado
- **form_published**: Formulario publicado
- **high_response_volume**: Formulario recibe muchas respuestas (>100/día)

### Integraciones
- **integration_connected**: Nueva integración conectada
- **integration_failed**: Fallo en integración

### Seguridad
- **suspicious_activity**: Actividad sospechosa detectada

### Sistema
- **system**: Eventos del sistema (limpieza, mantenimiento)

## 🎯 Prioridades de Notificaciones

- **Critical**: Actividad sospechosa, fallos críticos del sistema
- **High**: Pagos fallidos, trials expirados, upgrades/downgrades
- **Normal**: Registros de usuarios, formularios publicados, integraciones
- **Low**: Eventos del sistema, limpieza automática

## 📂 Categorías

- **user_activity**: Actividades relacionadas con usuarios
- **billing**: Eventos de facturación y pagos
- **system**: Eventos del sistema
- **security**: Eventos de seguridad

## 🔄 Flujo de Notificaciones

### 1. Creación Automática
```ruby
# En callbacks del modelo User
after_create :notify_admin_of_registration
after_update :notify_admin_of_subscription_changes

# Uso del servicio
AdminNotificationService.notify(:user_registered, user: user)
```

### 2. Prevención de Duplicados
- No se crean notificaciones duplicadas del mismo tipo para el mismo usuario en 5 minutos
- Configurable por tipo de evento

### 3. Broadcasting en Tiempo Real
- Utiliza Turbo Streams para actualizaciones en vivo
- Actualiza contador de notificaciones no leídas
- Agrega nuevas notificaciones al panel sin recargar

## 🎨 Interfaz de Usuario

### Panel Principal (`/admin/notifications`)
- **Estadísticas**: Total, no leídas, hoy, esta semana, críticas
- **Filtros**: Por tipo de evento, prioridad, estado (leído/no leído)
- **Lista de Notificaciones**: Con iconos, prioridades y metadatos
- **Acciones**: Marcar como leído, eliminar, marcar todas como leídas

### Navegación
- Contador de notificaciones no leídas en el header del admin
- Enlace directo desde la navegación principal

### Características Visuales
- Iconos emoji para cada tipo de evento
- Colores distintivos por prioridad
- Indicadores de estado leído/no leído
- Metadatos expandibles para detalles adicionales

## ⚙️ Jobs Programados

### Verificación de Trials (Diario a las 9 AM UTC)
```ruby
# Encuentra trials que expiran en 3 días
# Encuentra trials que expiraron hoy
# Actualiza estado de usuarios con trials expirados
```

### Verificación de Volumen de Respuestas (Cada hora)
```ruby
# Detecta formularios con >100 respuestas por día
# Notifica solo una vez por día por formulario
```

### Limpieza de Notificaciones (Semanal, domingos 2 AM UTC)
```ruby
# Elimina notificaciones mayores a 90 días
# Crea notificación de resumen de limpieza
```

## 🧪 Testing

### Cobertura de Tests
- **Modelo**: Validaciones, scopes, métodos de instancia y clase
- **Servicio**: Creación de notificaciones, prevención de duplicados
- **Controlador**: Autorización, filtros, acciones CRUD
- **Jobs**: Lógica de verificación y limpieza

### Factories
```ruby
# Traits disponibles
create(:admin_notification, :read)
create(:admin_notification, :unread)
create(:admin_notification, :critical)
create(:admin_notification, :user_registered)
```

## 🚀 Uso en Desarrollo

### Crear Notificaciones de Prueba
```ruby
# En rails console o runner
AdminNotificationService.notify(:user_registered, user: user, force_in_test: true)
```

### Ejecutar Jobs Manualmente
```ruby
# Helper para desarrollo
RecurringJobsHelper.run_all_checks
```

### Ver Notificaciones
1. Acceder como superadmin: `http://localhost:3000/users/sign_in`
2. Ir al panel: `http://localhost:3000/admin/notifications`

## 📈 Métricas y Monitoreo

### Estadísticas Disponibles
- Total de notificaciones
- Notificaciones no leídas
- Notificaciones de hoy
- Notificaciones de esta semana
- Notificaciones críticas pendientes

### API de Estadísticas
```
GET /admin/notifications/stats.json
```

Retorna:
- Estadísticas diarias por tipo de evento (últimos 30 días)
- Distribución por prioridad (últimos 7 días)
- Actividad por tipo de suscripción de usuario

## 🔧 Configuración

### Variables de Entorno
```bash
# Para jobs programados en producción
SIDEKIQ_WEB_USER=admin
SIDEKIQ_WEB_PASSWORD=secure_password
```

### Personalización
- **Período de retención**: Modificar `RETENTION_PERIOD` en `NotificationCleanupJob`
- **Umbral de volumen alto**: Modificar `HIGH_VOLUME_THRESHOLD` en `ResponseVolumeCheckJob`
- **Prevención de duplicados**: Modificar tiempo en `AdminNotificationService`

## 🎯 Beneficios del Sistema

1. **Visibilidad Completa**: Monitoreo en tiempo real de todas las actividades importantes
2. **Detección Proactiva**: Identificación temprana de problemas y oportunidades
3. **Gestión Eficiente**: Filtros y categorización para priorizar acciones
4. **Escalabilidad**: Diseño modular que permite agregar nuevos tipos de eventos fácilmente
5. **Experiencia de Usuario**: Interfaz intuitiva con actualizaciones en tiempo real

## 🔮 Futuras Mejoras

- **Notificaciones por Email**: Envío automático de notificaciones críticas por email
- **Webhooks**: Integración con sistemas externos (Slack, Discord, etc.)
- **Reglas Personalizadas**: Configuración de umbrales y condiciones por administrador
- **Dashboard Analytics**: Gráficos y tendencias de actividad
- **Notificaciones Push**: Notificaciones del navegador para administradores activos

---

**Implementado**: ✅ Sistema completo funcional
**Fecha**: Enero 2025
**Versión**: 1.0