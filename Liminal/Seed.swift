import Foundation

/// Example content so the app opens in a realistic working state. Marked as examples in the UI.
enum Seed {
    static func state(name: String, adminEmail: String) -> AppState {
        let now = Date()
        let hour: TimeInterval = 3600
        let day: TimeInterval = 86400

        let tienda = Project(
            name: "Tienda Cami", desc: "Ropa de verano que vendo por Instagram.", colorHex: Palette.projectColors[0],
            instructions: "Habla como una tienda cercana y alegre. Precios en dólares. Hacemos envíos por agencia a todo el país.",
            files: [ProjectFile(name: "catalogo-octubre.pdf", size: "1,2 MB"), ProjectFile(name: "precios-2026.xlsx", size: "48 KB")],
            created: now.addingTimeInterval(-20 * day))
        let enfermeria = Project(
            name: "Enfermería 4.º semestre", desc: "Apuntes y repaso para los parciales.", colorHex: Palette.projectColors[1],
            instructions: "Explícame como a una estudiante de enfermería. Usa ejemplos clínicos sencillos.",
            files: [ProjectFile(name: "anatomia-unidad-3.pdf", size: "3,4 MB")],
            created: now.addingTimeInterval(-12 * day))
        let clientes = Folder(name: "Clientes")
        let casa = Folder(name: "Casa")

        func user(_ text: String) -> Message { Message(role: .user, text: text) }
        func bot(_ text: String, mode: ChatMode = .general, tier: Tier = .fast, effort: Effort = .medio, thought: [String] = []) -> Message {
            Message(role: .bot, text: text, tier: tier, effort: effort, engine: .deepseek, mode: mode,
                    thinkingSeconds: tier == .adv ? effort.seconds : 0, thought: thought)
        }

        let chats: [Chat] = [
            Chat(title: "Qué es una stablecoin", mode: .general, updated: now.addingTimeInterval(-28 * 60), messages: [
                user("¿Qué es una stablecoin? Explícamelo fácil."),
                bot("Es una criptomoneda que intenta valer siempre lo mismo que un dólar.\n\n- **Para qué sirve:** guardar y enviar dólares digitales sin un banco de por medio.\n- **Ejemplos:** USDT y USDC.\n- **El riesgo:** depende de que la empresa que la emite tenga de verdad los dólares que la respaldan.\n\nEn Liminal puedes pagar tu plan con USDT o USDC.")
            ]),
            Chat(title: "Descripciones para vestidos de lino", mode: .emprendedor, projectID: tienda.id, updated: now.addingTimeInterval(-2 * hour), messages: [
                user("Escríbeme 3 descripciones cortas para Instagram de vestidos de lino de verano. Precio: $18."),
                bot("Aquí tienes tres opciones, de la más directa a la más cálida.\n\n### Opción 1: directa\nVestido de lino, fresco y liviano para los días de calor. Tallas S a L. **$18.** Escríbenos y te lo apartamos hoy.\n\n### Opción 2: con beneficio\nEl vestido que no se pega al cuerpo con el calor. Lino suave, corte suelto y colores claros. **Solo $18.**\n\n### Opción 3: cercana\n¿Plan de playa o de oficina? Este vestido de lino va con los dos. **$18** y envío a todo el país.\n\n**Hashtags sugeridos:** #VestidosDeLino #ModaVerano #TiendaCami",
                    mode: .emprendedor, tier: .adv, effort: .medio,
                    thought: ["Necesita tres textos cortos para Instagram, con el precio visible.", "El proyecto pide un tono cercano y alegre, con precios en dólares.", "Ordeno las opciones de la más directa a la más cálida y cierro con hashtags."])
            ]),
            Chat(title: "Respuesta a clienta por envío atrasado", mode: .emprendedor, folderID: clientes.id, updated: now.addingTimeInterval(-5 * hour), messages: [
                user("Una clienta está molesta porque su pedido lleva 6 días de retraso. ¿Qué le respondo?"),
                bot("Te propongo este mensaje. Reconoce el problema, da una fecha y ofrece algo a cambio.\n\n> Hola, Andrea. Tienes toda la razón: tu pedido debió llegar hace días y lo siento mucho. Ya hablé con la agencia y sale mañana; te paso el número de guía apenas lo tenga. Por la espera, tu próxima compra tiene 10% de descuento.\n\n**Antes de enviarlo:**\n- Confirma con la agencia que de verdad sale mañana.\n- No culpes a la agencia en el mensaje: a tu clienta solo le importa su pedido.", mode: .emprendedor)
            ]),
            Chat(title: "Plan de estudio para el parcial de anatomía", mode: .estudiante, projectID: enfermeria.id, updated: now.addingTimeInterval(-27 * hour), messages: [
                user("Hazme un plan de estudio de 5 días para el parcial de anatomía del sistema cardiovascular."),
                bot("Este plan reparte el temario en bloques de 90 minutos y deja el último día solo para practicar.\n\n1. **Día 1, corazón:** cavidades, válvulas y capas. Dibuja el corazón de memoria al terminar.\n2. **Día 2, ciclo cardíaco:** sístole, diástole y ruidos cardíacos. Haz una tabla con cada fase.\n3. **Día 3, vasos sanguíneos:** arterias, venas y capilares. Compara su estructura en tres columnas.\n4. **Día 4, circulación:** mayor y menor. Recorre en voz alta el camino de una gota de sangre.\n5. **Día 5, práctica:** 30 preguntas tipo examen y repaso solo de lo que fallaste.\n\n### Truco para retener\nAl final de cada día, explica el tema en 2 minutos sin mirar tus apuntes. Donde te trabes, ahí está lo que debes repasar.\n\n¿Quieres que te prepare las 30 preguntas del día 5?",
                    mode: .estudiante, tier: .adv, effort: .alto,
                    thought: ["Son 5 días: conviene ir de estructura a función y terminar con práctica.", "El proyecto pide ejemplos clínicos sencillos, así que cada día cierra con una actividad concreta.", "Dejo el último día libre de temario nuevo para repasar errores."]),
                user("Sí, empieza con 5 sobre las válvulas."),
                bot("Aquí van. Responde y te digo cuáles acertaste.\n\n1. ¿Qué válvula separa la aurícula izquierda del ventrículo izquierdo?\n2. ¿Cuántas valvas tiene la válvula tricúspide?\n3. ¿Qué ruido cardíaco se produce al cerrarse las válvulas auriculoventriculares?\n4. ¿Qué estructuras impiden que las valvas se inviertan hacia las aurículas?\n5. ¿Por dónde sale la sangre del ventrículo derecho hacia los pulmones?", mode: .estudiante)
            ]),
            Chat(title: "Carta de presentación para asistente administrativa", mode: .empleo, pinned: true, updated: now.addingTimeInterval(-2 * day), messages: [
                user("Ayúdame con una carta de presentación para asistente administrativa. Tengo 2 años de experiencia en una farmacia."),
                bot("Aquí tienes un borrador de una página. Cambia lo que está entre corchetes.\n\n> Estimado equipo de [empresa]:\n>\n> Les escribo para postularme al puesto de asistente administrativa. Durante dos años en [farmacia] llevé el control de inventario, atendí a más de 60 clientes al día y organicé los pedidos a proveedores.\n>\n> Me considero ordenada y aprendo rápido sistemas nuevos. Me encantaría aportar eso a su equipo.\n>\n> Quedo atenta a su respuesta.\n> [Tu nombre], [teléfono]\n\n**Para que destaque:** agrega una cifra concreta, por ejemplo cuánto redujiste los faltantes de inventario.",
                    mode: .empleo, tier: .adv, effort: .medio,
                    thought: ["Puesto administrativo y experiencia en farmacia: destacar inventario, atención y orden.", "Una página, tono formal pero cálido.", "Dejo campos entre corchetes para que los complete."])
            ]),
            Chat(title: "Comidas para 3 días con lo que hay en casa", mode: .diadia, folderID: casa.id, updated: now.addingTimeInterval(-3 * day), messages: [
                user("Tengo arroz, huevos, plátanos, queso y caraotas. Dame ideas de comidas para 3 días."),
                bot("Con eso armas tres días sin repetir:\n\n- **Día 1:** arroz con caraotas, huevo frito y tajadas de plátano.\n- **Día 2:** tortilla de plátano maduro con queso y, si tienes tomate, una ensalada.\n- **Día 3:** arroz frito con huevo revuelto y caraotas refritas por encima.\n\n**Consejo:** cocina las caraotas una sola vez el primer día y guárdalas en la nevera; te duran los tres días.", mode: .diadia)
            ]),
            Chat(title: "Cómo cobrar el envío sin perder dinero", mode: .emprendedor, projectID: tienda.id, updated: now.addingTimeInterval(-6 * day), messages: [
                user("¿Cómo calculo el precio del envío a otras ciudades sin perder dinero?"),
                bot("Suma tres cosas y redondea hacia arriba:\n\n1. **Lo que cobra la agencia** por un paquete de tu tamaño.\n2. **El empaque:** bolsa, caja y etiqueta.\n3. **Un margen del 10%** para cubrir los pedidos que se devuelven.\n\nSi te sale $4,30, cobra $4,50. Y ofrece envío gratis a partir de dos prendas: así sube lo que gasta cada clienta.", mode: .emprendedor)
            ])
        ]

        let users: [AdminUser] = [
            AdminUser(name: name, email: adminEmail, plan: .mensual, status: .activo, advThisWeek: 188, points: 1150, lastSeen: now.addingTimeInterval(-5 * 60), isAdmin: true),
            AdminUser(name: "Ana Rojas", email: "ana.rojas@ejemplo.com", plan: .mensual, status: .activo, advThisWeek: 312, points: 2400, lastSeen: now.addingTimeInterval(-2 * hour), isAdmin: false),
            AdminUser(name: "Luis Méndez", email: "luis.mendez@ejemplo.com", plan: .semanal, status: .activo, advThisWeek: 88, points: 650, lastSeen: now.addingTimeInterval(-26 * hour), isAdmin: false),
            AdminUser(name: "Carla Díaz", email: "carla.diaz@ejemplo.com", plan: .mensual, status: .vence, advThisWeek: 401, points: 1150, lastSeen: now.addingTimeInterval(-2 * day), isAdmin: false),
            AdminUser(name: "José Márquez", email: "jose.marquez@ejemplo.com", plan: .mensual, status: .activo, advThisWeek: 140, points: 900, lastSeen: now.addingTimeInterval(-4 * hour), isAdmin: false),
            AdminUser(name: "Valentina Ruiz", email: "valentina.r@ejemplo.com", plan: .semanal, status: .suspendido, advThisWeek: 0, points: 300, lastSeen: now.addingTimeInterval(-12 * day), isAdmin: false),
            AdminUser(name: "Pedro Gil", email: "pedro.gil@ejemplo.com", plan: .mensual, status: .activo, advThisWeek: 433, points: 1800, lastSeen: now.addingTimeInterval(-30 * 60), isAdmin: false),
            AdminUser(name: "Sofía Torres", email: "sofia.torres@ejemplo.com", plan: .mensual, status: .vence, advThisWeek: 57, points: 550, lastSeen: now.addingTimeInterval(-3 * day), isAdmin: false)
        ]

        let payments: [Payment] = [
            Payment(date: now.addingTimeInterval(-40 * 60), email: "ana.rojas@ejemplo.com", plan: .mensual, amount: "11 USDT", network: .tron, status: .confirmado),
            Payment(date: now.addingTimeInterval(-3 * hour), email: "pedro.gil@ejemplo.com", plan: .mensual, amount: "11 USDC", network: .base, status: .confirmado),
            Payment(date: now.addingTimeInterval(-5 * hour), email: "luis.mendez@ejemplo.com", plan: .semanal, amount: "3 USDT", network: .tron, status: .pendiente),
            Payment(date: now.addingTimeInterval(-9 * hour), email: "jose.marquez@ejemplo.com", plan: .mensual, amount: "11 USDC", network: .solana, status: .fallido),
            Payment(date: now.addingTimeInterval(-26 * hour), email: "carla.diaz@ejemplo.com", plan: .mensual, amount: "11 USDT", network: .tron, status: .confirmado),
            Payment(date: now.addingTimeInterval(-2 * day), email: "sofia.torres@ejemplo.com", plan: .mensual, amount: "11 USDC", network: .base, status: .confirmado),
            Payment(date: now.addingTimeInterval(-3 * day), email: "valentina.r@ejemplo.com", plan: .semanal, amount: "3 USDT", network: .tron, status: .fallido),
            Payment(date: now.addingTimeInterval(-30 * day), email: adminEmail, plan: .mensual, amount: "11 USDT", network: .tron, status: .confirmado)
        ]

        var paidUntilComponents = DateComponents()
        paidUntilComponents.year = 2026
        paidUntilComponents.month = 11
        paidUntilComponents.day = 14
        let paidUntil = Calendar.current.date(from: paidUntilComponents) ?? now.addingTimeInterval(30 * day)

        return AppState(
            version: 1,
            prefs: Prefs(name: name, language: "es-419", tone: .cercano,
                         custom: "Estoy construyendo Liminal, una IA en español para Latinoamérica. Respóndeme corto y con ejemplos.",
                         theme: .system, fontScale: .normal, tier: .adv, effort: .medio, engine: .deepseek,
                         defaultMode: .general, showThinking: true, saveHistory: true, tempDefault: false,
                         memory: true, network: .tron, plan: .mensual),
            usage: Usage(adv: 23, advCap: 65, week: 188, weekCap: 450, fast: 41, fastCap: 200,
                         fastDay: AppStore.dayKey(now), resetAt: now.addingTimeInterval(3.3 * hour),
                         weekResetAt: now.addingTimeInterval(4.6 * day)),
            points: 1150,
            referralCode: "GABRIEL-7K2",
            pointsHistory: [
                PointsEntry(month: "oct 2026", reason: "Mes activo", points: 300),
                PointsEntry(month: "sep 2026", reason: "Amigo suscrito con tu enlace", points: 250),
                PointsEntry(month: "sep 2026", reason: "Mes activo", points: 300),
                PointsEntry(month: "ago 2026", reason: "Mes activo", points: 300)
            ],
            memories: [
                Memory(text: "Está construyendo Liminal, una IA para Latinoamérica."),
                Memory(text: "El plan cuesta $11 al mes y se paga con USDT o USDC."),
                Memory(text: "Prefiere respuestas cortas y con ejemplos.")
            ],
            projects: [tienda, enfermeria],
            folders: [clientes, casa],
            chats: chats,
            admin: .defaults,
            users: users,
            payments: payments,
            paidUntil: paidUntil,
            telegramLinked: false
        )
    }
}
