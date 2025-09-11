# Google Sheets Production Setup - mydialogform

## ✅ Configuración Completada

La integración de Google Sheets ha sido configurada exitosamente para usar variables de entorno en producción.

### 🔑 Variables de Entorno Configuradas

**En Heroku:**
- ✅ `GOOGLE_SHEETS_CLIENT_ID`: Configurado
- ✅ `GOOGLE_SHEETS_CLIENT_SECRET`: Configurado

### 📊 Estado de la Configuración

```
Environment: production
OAuth configured: ✅ true
Service Account configured: ❌ false (opcional)
Production Environment Variables:
  GOOGLE_SHEETS_CLIENT_ID: ✅
  GOOGLE_SHEETS_CLIENT_SECRET: ✅
  GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON: ❌ (opcional)
```

## 🔧 Cambios Implementados

### 1. Servicio de Configuración Centralizado
- **Archivo:** `app/services/google_sheets/config_service.rb`
- **Función:** Maneja la configuración de Google Sheets para diferentes entornos
- **Características:**
  - Usa variables de entorno en producción
  - Usa Rails credentials en desarrollo
  - Proporciona métodos de verificación
  - Logging detallado del estado

### 2. Servicios Actualizados
Los siguientes servicios ahora usan el nuevo sistema de configuración:

- `app/services/google_sheets/base_service.rb`
- `app/services/google_sheets/token_refresh_service.rb`
- `app/services/integrations/google_sheets_service.rb`
- `app/controllers/google_oauth_controller.rb`
- `app/controllers/google_integrations_controller.rb`
- `app/helpers/google_integration_helper.rb`

### 3. Initializer Actualizado
- **Archivo:** `config/initializers/google_sheets.rb`
- **Cambios:** Usa el nuevo servicio de configuración para logging

### 4. Scripts de Verificación
- **Script:** `script/verify_google_sheets_config.rb`
- **Rake Tasks:** `lib/tasks/google_sheets_config.rake`
- **Comandos disponibles:**
  - `rake google_sheets:verify_config`
  - `rake google_sheets:show_config`
  - `rake google_sheets:test_oauth`
  - `rake google_sheets:usage`

## 🧪 Comandos de Verificación

### Verificar configuración completa
```bash
heroku run rake google_sheets:verify_config --app mydialogform
```

### Mostrar estado actual
```bash
heroku run rake google_sheets:show_config --app mydialogform
```

### Probar OAuth
```bash
heroku run rake google_sheets:test_oauth --app mydialogform
```

### Ver instrucciones de uso
```bash
heroku run rake google_sheets:usage --app mydialogform
```

## 🔍 Verificación Manual

### En Rails Console
```ruby
# Conectar a producción
heroku run rails console --app mydialogform

# Verificar configuración
GoogleSheets::ConfigService.oauth_configured?
# => true

GoogleSheets::ConfigService.configuration_summary
# => Hash con detalles de configuración

# Verificar variables de entorno
ENV['GOOGLE_SHEETS_CLIENT_ID'].present?
# => true

ENV['GOOGLE_SHEETS_CLIENT_SECRET'].present?
# => true
```

## 📋 Funcionalidades Disponibles

### ✅ Funcionalidades Activas
- **OAuth Authentication:** Los usuarios pueden conectar sus cuentas de Google
- **Google Sheets Integration:** Exportar respuestas de formularios a Google Sheets
- **Token Refresh:** Renovación automática de tokens de acceso
- **Rate Limiting:** Control de límites de API
- **Error Handling:** Manejo robusto de errores

### ⚠️ Funcionalidades Limitadas (Opcional)
- **Service Account:** No configurado (para operaciones avanzadas del sistema)
- **Advanced API Features:** Algunas funciones avanzadas pueden estar limitadas

## 🚀 Próximos Pasos

### Para Usuarios
1. **Conectar Google Account:** Los usuarios pueden ir a la configuración de integraciones
2. **Configurar Google Sheets:** Crear integraciones con sus hojas de cálculo
3. **Exportar Datos:** Las respuestas se exportarán automáticamente

### Para Administradores
1. **Monitorear Logs:** Verificar que no haya errores de Google API
2. **Configurar Service Account (Opcional):** Para funciones avanzadas
3. **Ajustar Rate Limits (Opcional):** Si es necesario

## 🔒 Seguridad

### Variables de Entorno Seguras
- Las credenciales están almacenadas como variables de entorno en Heroku
- No están expuestas en el código fuente
- Se muestran parcialmente en logs para debugging

### Tokens de Usuario
- Los tokens de OAuth se almacenan encriptados en la base de datos
- Se renuevan automáticamente cuando expiran
- Se pueden revocar desde la aplicación

## 📞 Soporte

### Si hay problemas:

1. **Verificar configuración:**
   ```bash
   heroku run rake google_sheets:show_config --app mydialogform
   ```

2. **Revisar logs:**
   ```bash
   heroku logs --tail --app mydialogform | grep -i google
   ```

3. **Verificar variables de entorno:**
   ```bash
   heroku config --app mydialogform | grep GOOGLE
   ```

### Errores Comunes

1. **"OAuth not configured"**
   - Verificar que las variables de entorno estén configuradas
   - Ejecutar `rake google_sheets:show_config`

2. **"Invalid client credentials"**
   - Verificar que las credenciales de Google Cloud Console sean correctas
   - Asegurar que el redirect URI esté configurado

3. **"Token expired"**
   - El sistema debería renovar automáticamente
   - Si persiste, el usuario debe reconectar su cuenta

---

**Configurado:** 11 de septiembre de 2025  
**Estado:** ✅ Funcionando correctamente  
**Entorno:** Producción (Heroku)  
**Última verificación:** 2025-09-11 07:20 UTC