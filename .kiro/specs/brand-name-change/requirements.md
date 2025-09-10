# Cambio de Marca: AgentForm → mydialogform

## Resumen
Cambiar todas las referencias de "AgentForm" a "mydialogform" en toda la aplicación para reflejar el nuevo nombre de marca.

## Historias de Usuario

### Como propietario del negocio
- Quiero que todo el texto visible para el usuario muestre "mydialogform" en lugar de "AgentForm"
- Quiero que las plantillas de email usen el nuevo nombre de marca
- Quiero que el título de la aplicación y los metadatos reflejen el nuevo nombre
- Quiero que la documentación use el nombre de marca actualizado

### Como usuario
- Debería ver "mydialogform" en todos los elementos de la UI
- Debería recibir emails con el nombre de marca correcto
- Debería ver el nombre de marca correcto en títulos del navegador y meta tags

### Como desarrollador
- Quiero que los comentarios del código y documentación usen el nombre actualizado
- Quiero que los archivos de configuración reflejen la nueva marca
- Quiero que los archivos de prueba usen nomenclatura consistente

## Criterios de Aceptación

### ✅ Actualizaciones de Interfaz de Usuario
- [ ] Todas las plantillas de vista (.html.erb) actualizadas
- [ ] Menús de navegación muestran "mydialogform"
- [ ] Títulos de página y encabezados actualizados
- [ ] Branding de footer y header actualizado
- [ ] Etiquetas de formulario y texto de ayuda actualizados
- [ ] Mensajes de error y notificaciones flash actualizados

### ✅ Plantillas de Email
- [ ] Todas las plantillas de mailer actualizadas (versiones HTML y texto)
- [ ] Asuntos de email usan el nuevo nombre de marca
- [ ] Firmas y footers de email actualizados
- [ ] Emails de bienvenida y notificaciones actualizados

### ✅ Archivos de Configuración
- [ ] Nombre de aplicación en config/application.rb
- [ ] Comentarios de configuración de base de datos
- [ ] Configuraciones específicas de entorno
- [ ] Archivos de inicialización
- [ ] Comentarios en archivo de rutas

### ✅ Documentación
- [ ] Archivos README actualizados
- [ ] Documentación de API
- [ ] Comentarios de código en controladores y modelos
- [ ] Descripciones de specs y nombres de pruebas
- [ ] Comentarios de migraciones

### ✅ Metadatos y SEO
- [ ] Meta tags HTML (título, descripción)
- [ ] Tags de Open Graph
- [ ] Metadatos de Twitter Card
- [ ] Favicon e iconos de app (si están nombrados)
- [ ] Archivo manifest de PWA

## Estrategia de Implementación

### Fase 1: Archivos Principales de la Aplicación
1. Actualizar plantillas de vista y layouts
2. Actualizar plantillas de mailer
3. Actualizar archivos de configuración
4. Actualizar metadatos de aplicación

### Fase 2: Documentación y Comentarios
1. Actualizar README y documentación
2. Actualizar comentarios de código
3. Actualizar descripciones de pruebas

### Fase 3: Assets y Frontend
1. Actualizar archivos JavaScript
2. Actualizar archivos CSS/SCSS
3. Actualizar manifest de PWA
4. Actualizar meta tags y SEO

## Reemplazos a Realizar
1. **Reemplazos sensibles a mayúsculas**:
   - "AgentForm" → "mydialogform"
   - "AGENTFORM" → "MYDIALOGFORM"
   - "agentform" → "mydialogform"

2. **Preservar contexto**:
   - Mantener capitalización apropiada en oraciones
   - Mantener estructuras de URL intactas
   - Preservar funcionalidad del código

---

**Prioridad**: Alta
**Esfuerzo Estimado**: 4-6 horas
**Dependencias**: Ninguna
**Stakeholders**: Marketing, Desarrollo, QA