# Credenciales del Superadmin - mydialogform

## 🔑 Credenciales Actuales

**Email:** `superadmin@mydialogform.com`  
**Password:** `MyPassword123!`  
**Role:** `superadmin`  
**Subscription:** `premium`

## 🌐 URLs de Acceso

**Producción:** https://mydialogform.com/users/sign_in  
**Local:** http://localhost:3000/users/sign_in

## 📊 Estado del Usuario

- ✅ **Activo:** Sí
- ✅ **Confirmado:** Sí  
- ✅ **Suspendido:** No
- **ID:** `8b9905da-f321-4ac5-b082-d6beb59ff706`
- **Creado:** 2025-09-11 03:34:07 UTC
- **Última actualización:** 2025-09-11 06:13:37 UTC

## 🔧 Comandos Útiles

### Mostrar credenciales actuales
```bash
heroku run rake users:show_superadmin_credentials --app mydialogform
```

### Diagnosticar problemas de login
```bash
heroku run rake users:diagnose_superadmin --app mydialogform
```

### Resetear contraseña
```bash
heroku run EMAIL=superadmin@mydialogform.com PASSWORD=NuevaPassword123! rake users:reset_superadmin_password --app mydialogform
```

### Setup completo (arregla todos los problemas)
```bash
heroku run EMAIL=superadmin@mydialogform.com PASSWORD=NuevaPassword123! rake users:setup_superadmin --app mydialogform
```

### Confirmar email manualmente
```bash
heroku run rake users:confirm_superadmin --app mydialogform
```

### Activar usuario
```bash
heroku run rake users:activate_superadmin --app mydialogform
```

## 🚨 Solución de Problemas

Si no puedes hacer login:

1. **Verifica las credenciales** usando el comando de mostrar credenciales
2. **Ejecuta diagnósticos** para identificar el problema específico
3. **Resetea la contraseña** si es necesario
4. **Ejecuta setup completo** si hay múltiples problemas

## 📝 Notas Importantes

- Las credenciales fueron configuradas el 11 de septiembre de 2025
- La contraseña fue reseteada usando el script de fix
- El usuario tiene permisos completos de superadmin
- Tiene acceso a todas las funciones premium
- Puede acceder al panel de administración

## 🔒 Seguridad

- **NO** compartas estas credenciales
- Cambia la contraseña regularmente
- Usa una contraseña fuerte y única
- Considera usar un gestor de contraseñas

---

**Última verificación:** 11 de septiembre de 2025, 07:07 UTC  
**Estado:** ✅ Funcionando correctamente