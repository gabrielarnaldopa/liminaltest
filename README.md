# Kuolki para iOS

App de chat en SwiftUI (iOS 17 o superior): inicio de sesión de administración, chats con modos y esfuerzo, proyectos, carpetas, ajustes, privacidad, plan y pagos, puntos y panel de administración. Interfaz en gris claro y oscuro; verde, amarillo y rojo de macOS solo para estados.

## Novedades de esta versión

- **iPhone rehecho como en los videos:** barra de cristal arriba (menú, «Lithium 1.1» y dos botones) que cabe en cualquier iPhone, también con Zoom de pantalla; ya no se encima nada.
- **Menú lateral que sigue tu dedo:** desliza a la derecha en cualquier parte para abrirlo y a la izquierda (o toca afuera) para cerrarlo. Los chats van en filas simples, sin cuadros; mantén presionado un chat para fijarlo, renombrarlo, moverlo o eliminarlo.
- **Inicio con el cuadro de texto al centro**, como en la web; en el chat queda flotando abajo, de cristal.
- **Ajustes en una hoja** que se cierra deslizando hacia abajo, con las páginas internas que vuelven deslizando a la derecha.
- **Diseño nuevo, igual al de la web:** fuente Bricolage Grotesque, colores de iOS 26, aura de color en el inicio, tarjetas de modos, botón de enviar con degradado y selector de modelo en cápsula de cristal.
- **Liquid Glass:** si compilas con **Xcode 26** para iOS 26 o superior, las barras, menús y botones usan el cristal real de Apple. Con Xcode 16 o en iPhones con iOS 17 a 18 se ve un cristal esmerilado parecido.
- **Editar lo que mandaste:** toca el lápiz debajo de tu mensaje, cambia el texto y pulsa Enviar. Kuolki responde de nuevo y guarda las versiones anteriores; las recorres con las flechas «‹ 1/2 ›».

- Páginas y presentaciones en vivo, como archivos que se abren y se ven al instante.
- Lithium puede buscar en internet y entrar a páginas (te pide permiso, o en automático).
- Navegador integrado, comandos con «/», lista de dispositivos conectados.
- Las respuestas siguen en el servidor aunque cierres la app, y te llega un aviso al terminar.
- Pago por región: Pago Móvil solo en Venezuela (se elige solo); en otros países, tarjeta y USDT/USDC.
- Kuolki Dev en el iPhone: se abre desde la barra lateral (o con /dev) y usa la app web que publicaste, ya con tu cuenta y tu servidor. La primera vez pega la dirección de GitHub Pages.
- Fotos: Lithium entiende recibos, tareas, documentos y capturas (el servidor necesita VISION_API_KEY).
- Investigación a fondo (con /investigar o en el menú +), gráficos y calculadoras dentro de las respuestas.
- El uso se mide en tokens y se muestra en porcentaje: la sesión de 5 horas y la semana.
- Se quitó Telegram.

## Abrir en Xcode

1. Necesitas una Mac con Xcode 16 o superior (Xcode 26 para el Liquid Glass completo).
2. Abre `Liminal.xcodeproj`.
3. En **Signing & Capabilities**, elige tu equipo (tu Apple ID sirve).
4. Elige un iPhone o el simulador y pulsa ▶︎.

## Sacar el archivo .ipa para AltServer

El .ipa solo se puede compilar con Xcode en una Mac. Dos caminos:

**Con tu Mac (un comando)**

Abre Terminal en esta carpeta y escribe `bash compilar-ipa.sh`. Deja `Kuolki.ipa` aquí mismo. Usa Xcode 26 si lo tienes instalado.

**Con tu Mac (a mano)**

1. En Xcode, elige **Any iOS Device (arm64)** y pulsa **Product › Build**.
2. En **Product › Show Build Folder in Finder**, entra a `Products/Debug-iphoneos` y copia `Liminal.app` (el proyecto conserva su nombre interno; en el iPhone se llama Kuolki).
3. Crea una carpeta llamada `Payload`, mete `Liminal.app` adentro, comprime la carpeta y cambia `Payload.zip` por `Kuolki.ipa`.

**Sin Mac, con GitHub (gratis)**

1. Sube esta carpeta a un repositorio de GitHub. Si ya tenías una versión anterior, reemplaza **todos** los archivos (incluida la carpeta `Liminal/Fonts` y `.github`); si no, el .ipa sale con el diseño viejo.
2. En la pestaña **Actions**, abre **Compilar IPA** y pulsa **Run workflow**.
3. Cuando termine (unos 5 minutos), descarga **Kuolki-ipa** al final de la página.

**Instalar con AltServer**

1. Abre AltServer en tu computadora con el iPhone conectado por cable.
2. Desde AltStore en el iPhone, toca **+** y elige `Kuolki.ipa`.
3. Con un Apple ID gratis, la app dura 7 días: renuévala desde AltStore.

## Respuestas reales con DeepSeek

- La clave de DeepSeek nunca va en la app: va en el servidor de Lithium (carpeta `Kuolki-Servidor`, un Worker de Cloudflare gratis). Sigue su `LEEME.md`.
- Luego, en la app: **Administración › Planes › Servidor de Lithium 1.1**, pega la dirección del servidor y la clave de la app, pulsa **Probar conexión** y **Guardar cambios**.
- Con el servidor, las respuestas llegan poco a poco, el modo avanzado muestra su razonamiento real y la conversación en vivo responde con Lithium. Sin servidor, la app sigue con respuestas de demostración.
- La búsqueda en internet y la lectura de Word todavía no pasan por el servidor.

## Conversación en vivo

- Con el chat vacío, el botón de enviar se convierte en un botón de ondas. Tócalo y habla: cuando haces una pausa, Lithium responde en voz alta y vuelve a escucharte. También está en el botón **+**.
- Toca el círculo para interrumpir a Lithium. Puedes pausar el micrófono o terminar; la conversación queda escrita en un chat.
- Si abres la conversación dentro de un chat, sigue ese chat. La memoria funciona igual: «recuerda que…» también por voz.
- Tu voz se convierte en texto en el iPhone cuando el equipo lo permite (sale un candado arriba), así que el audio no sale del teléfono. Lithium solo recibe el texto.
- **Costo:** escuchar y hablar no cuestan nada; cada respuesta cuenta como un mensaje del plan, igual que escribir.
- Sin el servidor, Lithium ya responde de verdad la tasa del BCV («¿a cuánto está el dólar?»), conversiones («¿cuánto son 20 dólares?»), la hora y la fecha. El resto son respuestas de demostración.
- La velocidad de la voz se cambia en **Ajustes › Voz e Isla Dinámica**.
- La primera vez, la app pide permiso de micrófono y de reconocimiento de voz.

## Isla Dinámica y pantalla bloqueada

- Mientras Lithium crea una imagen o un video, o piensa una respuesta larga en modo avanzado, ves el avance en la Isla Dinámica (iPhone 14 Pro y más nuevos) o en la pantalla bloqueada (todos los iPhone con iOS 17). Al terminar, tocas el aviso y se abre ese chat.
- Durante la conversación en vivo, la Isla Dinámica muestra si Lithium te escucha, piensa o habla, con botones para pausar el micrófono o terminar sin abrir la app.
- Verde: escuchando, hablando o listo. Amarillo: trabajando. Rojo: en pausa o cancelado.
- Se apaga en **Ajustes › Voz e Isla Dinámica** (o en Ajustes del iPhone › Kuolki).
- Por ahora la app actualiza el aviso mientras sigue abierta o recién cerrada. Con el servidor, las actualizaciones llegarán por notificaciones push aunque la app esté cerrada.
- Va en una extensión aparte (`LiminalWidgets`), que AltStore firma junto con la app. Con un Apple ID gratis, cuenta como un segundo App ID (el límite es 10 por semana).

## Un solo modelo: Lithium 1.1

- Tus clientes solo ven **Lithium 1.1**. Para cambiar el nombre, edita `Brand.modelName` en `Models.swift`.
- Detrás funcionan DeepSeek V4 Pro (principal), Qwen y GLM (respaldo). Solo los ves en Administración › Planes; la app no nombra ninguna otra IA.
- Sus licencias abiertas (MIT y Apache 2.0) no piden mostrar sus nombres en la app.

## Imágenes y video

- Se pagan con créditos: 100 al mes en el plan mensual. Una imagen usa 1 crédito y un video de 5 segundos (720p), 5.
- Un crédito le cuesta a Kuolki unos $0,021 con el proveedor. Aunque alguien use todo, el peor caso es $2,02 de texto más $2,10 de imágenes y video: $4,12 de los $4,40 de presupuesto, así que se mantiene el 60% de margen.
- Paquete extra: 100 créditos por $6.
- Los créditos, su costo y el precio se ajustan en Administración › Planes, y la app avisa si el peor caso deja de caber.
- Por ahora las imágenes y los videos son vistas previas de demostración: se vuelven reales al conectar el servidor.

## Archivos, búsqueda, conectores y exportar

- **Botón +:** subir archivos, elegir fotos, tomar una foto, grabar una nota de voz, buscar en internet, crear imagen o video, y conectores.
- **Lectura en el teléfono:** PDF (texto y páginas con PDFKit), duración de audios, tamaño y miniatura de fotos. Los Word y Excel se leen en el servidor cuando esté conectado.
- **Exportar:** cada respuesta se descarga como PDF o Word (.docx) y se abre en un editor para corregirla antes. Se comparte con la hoja de iOS: Archivos, WhatsApp, imprimir…
- **Documentos:** cuando pides un Word, un PDF o un documento, Lithium lo escribe completo empezando con `# Título` y debajo aparece una tarjeta con **Word**, **PDF** y **Editar**. El Word sale con estilos de título y secciones (se ven en el panel de navegación de Word), negritas y tablas.
- **Conectores (MCP):** Google Drive, Gmail, Google Calendar, Notion, WhatsApp Business e Instagram, más servidores MCP propios. La autorización real de cada servicio llega con el servidor.
- **Memoria:** por temas (sobre ti, tu negocio, cómo te gusta que responda), con «recuerda que…» en el chat, editar, borrar y deshacer.
- La app pide permiso de cámara y micrófono la primera vez que se usan.

## Inicio de sesión con Apple y Google

- El botón de Apple es el oficial de Apple. Para que funcione necesitas la cuenta de desarrollador de Apple de pago y activar «Sign in with Apple» en Signing & Capabilities; con un Apple ID gratis (AltServer) el botón se ve, pero avisa que falta.
- El botón de Google necesita el SDK de Google Sign-In y el servidor de Kuolki. Por ahora muestra un aviso.

## Pagos

- **Pago Móvil** en bolívares a la tasa oficial del euro del BCV (o la del dólar, si la cambias en Administración › Planes › Cobros). Con la tasa del 14 de octubre de 2026 (Bs 982,76 por euro), el plan de $11 queda en Bs 10.810,36.
- **USDT** (Tron o Solana), **USDC** (Base o Solana) y **tarjeta** (en la página segura del procesador; Kuolki nunca ve la tarjeta).
- Los pagos quedan pendientes y se aprueban o rechazan en Administración › Pagos. Configura ahí tus datos de Pago Móvil y tus direcciones antes de cobrar.
- El servidor debe actualizar la tasa cada día desde el BCV.

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
| `Replies.swift` | Respuestas simuladas (escritas y habladas): aquí se conecta tu proveedor de modelos |
| `LiveVoice.swift`, `LiveVoiceView.swift` | Conversación en vivo: escuchar, detectar la pausa y responder en voz alta |
| `LithiumClient.swift` | Habla con el servidor de Lithium y recibe las respuestas poco a poco |
| `LiveActivityController.swift` | Inicia y actualiza el aviso de la Isla Dinámica |
| `Theme.swift`, `LogoMark.swift` | Colores y logo animado |
| `Shared/` | Lo que comparten la app y la extensión: datos del aviso, botones y el logo |
| `LiminalWidgets/` | La extensión que dibuja la Isla Dinámica y el aviso de la pantalla bloqueada |
| `Config/` | Info.plist de la app (audio en segundo plano, enlaces `liminal://`) y de la extensión |

Los chats, usuarios y pagos que trae son de ejemplo.
