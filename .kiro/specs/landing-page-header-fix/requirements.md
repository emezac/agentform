# Corrección del Doble Header en Landing Page

## Introducción

La página de inicio actual (`app/views/landing/index.html.erb`) tiene un problema crítico de UI/UX: contiene su propio HTML completo (incluyendo `<!DOCTYPE html>`, `<head>`, `<body>`) pero está siendo renderizada dentro del layout principal de Rails (`application.html.erb`), lo que resulta en:

1. **Doble header**: Un header del layout principal + header interno de la landing page
2. **HTML inválido**: Estructura HTML anidada incorrectamente
3. **Mala experiencia de usuario**: Navegación confusa y diseño inconsistente
4. **Problemas de SEO**: Estructura HTML malformada

## Requisitos

### Requisito 1: Estructura HTML Válida

**Historia de Usuario:** Como desarrollador, quiero que la landing page tenga una estructura HTML válida y semánticamente correcta.

**Criterios de Aceptación:**
1. CUANDO un usuario visite la landing page ENTONCES el sistema DEBE renderizar HTML válido sin elementos duplicados
2. CUANDO se inspeccione el código fuente ENTONCES NO DEBE haber elementos `<html>`, `<head>`, o `<body>` anidados
3. CUANDO se valide con herramientas de HTML ENTONCES NO DEBE mostrar errores de estructura

### Requisito 2: Header Único y Consistente

**Historia de Usuario:** Como usuario visitante, quiero ver un solo header claro y profesional en la landing page.

**Criterios de Aceptación:**
1. CUANDO un usuario visite la landing page ENTONCES DEBE ver exactamente un header
2. CUANDO navegue entre la landing page y otras páginas ENTONCES la experiencia DEBE ser consistente
3. CUANDO use dispositivos móviles ENTONCES el header DEBE funcionar correctamente sin duplicación

### Requisito 3: Navegación Funcional

**Historia de Usuario:** Como usuario visitante, quiero poder navegar fácilmente desde la landing page hacia otras secciones.

**Criterios de Aceptación:**
1. CUANDO haga clic en enlaces de navegación ENTONCES DEBEN funcionar correctamente
2. CUANDO esté autenticado ENTONCES DEBE ver opciones apropiadas (Dashboard)
3. CUANDO no esté autenticado ENTONCES DEBE ver opciones de registro/login

### Requisito 4: Diseño Responsivo

**Historia de Usuario:** Como usuario móvil, quiero que la landing page se vea y funcione perfectamente en mi dispositivo.

**Criterios de Aceptación:**
1. CUANDO acceda desde móvil ENTONCES el menú hamburguesa DEBE funcionar correctamente
2. CUANDO cambie la orientación del dispositivo ENTONCES el layout DEBE adaptarse apropiadamente
3. CUANDO use diferentes tamaños de pantalla ENTONCES NO DEBE haber elementos superpuestos

## Opciones de Solución

### Opción 1: Layout Específico para Landing (Recomendada)
- Crear `app/views/layouts/landing.html.erb` sin header
- Configurar `LandingController` para usar este layout
- Mantener el header interno de la landing page como único header

### Opción 2: Convertir Landing a Vista Parcial
- Convertir la landing page a una vista Rails estándar
- Usar el header del layout principal
- Adaptar el contenido para trabajar con el layout existente

### Opción 3: Layout Condicional
- Modificar el layout principal para no mostrar header en landing
- Usar lógica condicional basada en el controlador/acción

## Criterios de Éxito

### Técnicos
- [ ] HTML válido sin elementos duplicados
- [ ] Un solo header visible
- [ ] Navegación funcional en desktop y móvil
- [ ] Estructura semánticamente correcta

### UX/UI
- [ ] Experiencia de navegación fluida
- [ ] Diseño consistente con la marca
- [ ] Responsividad completa
- [ ] Tiempos de carga optimizados

### SEO
- [ ] Meta tags apropiados
- [ ] Estructura HTML semántica
- [ ] Sin errores de validación HTML
- [ ] Open Graph tags funcionales

## Validación

### Pruebas Manuales
1. Verificar que solo hay un header visible
2. Probar navegación en diferentes dispositivos
3. Validar HTML con herramientas online
4. Verificar funcionalidad del menú móvil

### Pruebas Técnicas
1. Inspeccionar DOM para elementos duplicados
2. Verificar que los enlaces funcionan correctamente
3. Probar en diferentes navegadores
4. Validar accesibilidad (WCAG)

---

**Prioridad:** Alta
**Impacto:** Experiencia de Usuario, SEO, Calidad Técnica
**Esfuerzo Estimado:** 2-3 horas
**Tipo:** Corrección Crítica de UI/UX