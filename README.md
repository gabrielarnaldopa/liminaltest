# Liminal para iOS

App de chat en SwiftUI (iOS 17 o superior): inicio de sesión de administración, chats con modos y esfuerzo, proyectos, carpetas, ajustes, privacidad, plan y pagos, puntos, Telegram y panel de administración. Interfaz en gris claro y oscuro; verde, amarillo y rojo de macOS solo para estados.

## Abrir en Xcode

1. Necesitas una Mac con Xcode 16 o superior.
2. Abre `Liminal.xcodeproj`.
3. En **Signing & Capabilities**, elige tu equipo (tu Apple ID sirve).
4. Elige un iPhone o el simulador y pulsa ▶︎.

## Sacar el archivo .ipa para AltServer

El .ipa solo se puede compilar con Xcode en una Mac. Dos caminos:

**Con tu Mac**

1. En Xcode, elige **Any iOS Device (arm64)** y pulsa **Product › Build**.
2. En **Product › Show Build Folder in Finder**, entra a `Products/Debug-iphoneos` y copia `Liminal.app`.
3. Crea una carpeta llamada `Payload`, mete `Liminal.app` adentro, comprime la carpeta y cambia `Payload.zip` por `Liminal.ipa`.

**Sin Mac, con GitHub (gratis)**

1. Sube esta carpeta a un repositorio de GitHub.
2. En la pestaña **Actions**, abre **Compilar IPA** y pulsa **Run workflow**.
3. Cuando termine (unos 5 minutos), descarga **Liminal-ipa** al final de la página.

**Instalar con AltServer**

1. Abre AltServer en tu computadora con el iPhone conectado por cable.
2. Desde AltStore en el iPhone, toca **+** y elige `Liminal.ipa`.
3. Con un Apple ID gratis, la app dura 7 días: renuévala desde AltStore.

## Acceso de administración

- La cuenta de administración es la de `AuthService.adminEmail`.
- La contraseña no está escrita en el código: solo se guarda su huella SHA-256 en `AuthService.adminPasswordHash`.
- Para cambiarla, en Terminal ejecuta `echo -n "tu-nueva-clave" | shasum -a 256` y pega el resultado en `adminPasswordHash`.
- Tras 5 intentos fallidos, el acceso se pausa 30 segundos. "Recordarme" guarda la sesión 30 días en el Llavero; sin eso, dura 12 horas.

**Antes de publicar:** este inicio de sesión funciona solo en el dispositivo. Para usuarios reales, el acceso tiene que pasar a un servidor propio, con las contraseñas guardadas con Argon2 o bcrypt.

## Estructura

| Archivo | Qué tiene |
| --- | --- |
| `LiminalApp.swift` | Arranque, sesión, tema y navegación |
| `LoginView.swift` | Pantalla de inicio de sesión |
| `SidebarView.swift` | Chats, proyectos, carpetas y búsqueda |
| `ChatViews.swift` | Inicio, chat, mensajes, cuadro de texto y Markdown |
| `ProjectView.swift` | Proyecto con instrucciones, archivos y chats |
| `SettingsView.swift` | Todos los ajustes |
| `AdminView.swift` | Resumen, usuarios, planes y pagos |
| `AppStore.swift` | Datos, envío de mensajes, límites y guardado |
| `AuthService.swift` | Inicio de sesión y Llavero |
| `Replies.swift` | Respuestas simuladas: aquí se conecta tu proveedor de modelos |
| `Theme.swift`, `LogoMark.swift` | Colores y logo |

Los chats, usuarios y pagos que trae son de ejemplo.
