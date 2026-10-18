import Foundation

/// Simulated answers for the demo. Replace with calls to your model provider.
enum Replies {
    static func reply(for text: String, mode: ChatMode, project: Project?) -> String {
        let topic = shortTopic(text, limit: 70)
        let projectNote = project.map { "\n\nSeguí las instrucciones del proyecto **\($0.name)**." } ?? ""
        switch mode {
        case .emprendedor:
            return "Aquí tienes una propuesta para «\(topic)».\n\n### Versión para Instagram\nLo que buscabas, al precio justo. Escríbenos por mensaje directo y te lo apartamos hoy mismo.\n\n### Versión para WhatsApp\nHola, te cuento rápido: ya tenemos disponible lo que me preguntaste. ¿Te lo aparto?\n\n### Para cerrar la venta\n- Responde en menos de una hora: es cuando más ventas se concretan.\n- Ofrece dos formas de pago claras.\n- Confirma la entrega con fecha y hora." + projectNote
        case .estudiante:
            return "Vamos por partes con «\(topic)».\n\n### La idea central\nAntes de memorizar, entiende para qué sirve cada concepto y cómo se conecta con el anterior.\n\n### Paso a paso\n1. Lee el tema una vez sin subrayar.\n2. Escribe con tus palabras las tres ideas principales.\n3. Explícaselo en voz alta a alguien, o a mí.\n4. Resuelve una pregunta de práctica.\n\n¿Cuál de las ideas te costó más explicar? Empezamos por ahí y te hago cinco preguntas tipo examen." + projectNote
        case .empleo:
            return "Trabajemos «\(topic)» para que destaque.\n\n### Qué cambiaría\n- Empieza cada logro con un verbo: *organicé*, *reduje*, *atendí*.\n- Agrega números: cuántos clientes, cuánto tiempo, cuánto ahorro.\n- Quita todo lo que no tenga que ver con el puesto.\n\n### Ejemplo\n> Atendí a más de 40 clientes al día y reduje los reclamos un 30% en seis meses.\n\n¿Me pegas tu versión actual y la ajusto línea por línea?" + projectNote
        case .diadia:
            return "Listo, aquí va una propuesta para «\(topic)».\n\n- **Lunes:** lo más urgente, temprano y sin distracciones.\n- **Miércoles:** prepara el doble y deja listo el jueves.\n- **Viernes:** cierra pendientes y deja la tarde libre.\n\nSi me dices cuánto tiempo tienes cada día, lo ajusto." + projectNote
        case .general:
            return "Sobre «\(topic)», esto es lo esencial:\n\n1. **Primero**, define qué quieres lograr y para cuándo.\n2. **Después**, separa lo que depende de ti de lo que no.\n3. **Por último**, empieza por el paso más pequeño que puedas dar hoy.\n\n¿Lo bajamos a un plan concreto?" + projectNote
        }
    }

    static func thought(for text: String, mode: ChatMode, project: Project?, hasCustomInstructions: Bool) -> [String] {
        var lines = ["Entender qué necesita: «\(shortTopic(text, limit: 60))»."]
        if mode != .general {
            lines.append("Aplicar el modo \(mode.name): \(mode.summary.lowercased())")
        }
        if let project {
            lines.append("Seguir las instrucciones del proyecto \(project.name).")
        }
        if hasCustomInstructions {
            lines.append("Tener en cuenta tus instrucciones personalizadas.")
        }
        lines.append("Ordenar la respuesta en secciones cortas y terminar con un siguiente paso.")
        return lines
    }

    /// What Lithium could read from the attached files.
    static func fileReply(_ files: [Attachment]) -> String {
        files.map { file -> String in
            switch file.kind {
            case .pdf, .text:
                guard !file.text.isEmpty else {
                    return "No encontré texto en **\(file.name)**. Si es un documento escaneado, la versión con servidor lo lee con reconocimiento de texto."
                }
                let flat = file.text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
                let words = flat.split(separator: " ").count
                let pages = file.pages.map { $0 == 1 ? " (1 página)" : " (\($0) páginas)" } ?? ""
                let points = sentences(in: flat).prefix(3).map { "- " + $0 }
                let summary = points.isEmpty ? "- " + String(flat.prefix(200)) : points.joined(separator: "\n")
                return "Leí **\(file.name)**\(pages): unas \(words) palabras.\n\n### Lo principal\n\(summary)\n\n¿Quieres un resumen más corto, preguntas tipo examen o que lo pase a Word?"
            case .word:
                return "Recibí **\(file.name)**. Con el servidor conectado leo los documentos de Word completos y te los resumo o corrijo."
            case .audio:
                let length = file.duration.map { $0 > 0 ? " (\(Attachment.clock($0)))" : "" } ?? ""
                return "Escuché **\(file.name)**\(length).\n\n> Transcripción de demostración: con el servidor conectado aquí aparece el texto completo de tu audio.\n\n¿Lo resumo o te preparo una respuesta?"
            case .image:
                let size = (file.width != nil && file.height != nil) ? " (\(file.width!)×\(file.height!))" : ""
                return "Vi tu imagen **\(file.name)**\(size). Con el servidor conectado te describo lo que hay en ella, leo su texto y te ayudo a mejorarla."
            case .sheet:
                return "Recibí la hoja de cálculo **\(file.name)**. Con el servidor conectado leo sus tablas y te hago cuentas o gráficos."
            case .other:
                return "Recibí **\(file.name)**."
            }
        }.joined(separator: "\n\n")
    }

    /// Sentences of at least 30 characters.
    static func sentences(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if ".!?".contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if trimmed.count >= 30 { result.append(String(trimmed.prefix(220))) }
                current = ""
            }
        }
        return result
    }

    /// Demo sources for web search answers.
    static func sources(for text: String, mode: ChatMode) -> [String] {
        let pool: [String]
        switch mode {
        case .emprendedor: pool = ["bcv.org.ve", "business.instagram.com", "es.wikipedia.org", "bbc.com"]
        case .estudiante: pool = ["es.wikipedia.org", "khanacademy.org", "scielo.org", "bbc.com"]
        default: pool = ["es.wikipedia.org", "bbc.com", "dw.com", "elpais.com"]
        }
        let start = Int(AppStore.seed(for: text) % UInt32(pool.count))
        return (0..<3).map { pool[(start + $0) % pool.count] }
    }

    /// Finds a fact worth remembering, like "me llamo Ana" or "recuerda que vendo ropa".
    static func memoryFact(in text: String) -> Memory? {
        let lower = text.lowercased()
        var fact: Substring?
        for prefix in ["por favor recuerda que ", "recuerda que ", "recuerda "] where lower.hasPrefix(prefix) {
            fact = text.dropFirst(prefix.count)
            break
        }
        if fact == nil {
            let starters = ["me llamo ", "mi negocio ", "mi tienda ", "mi emprendimiento ", "mi empresa ", "vendo ",
                            "estudio ", "trabajo en ", "trabajo como ", "soy de ", "vivo en "]
            for starter in starters {
                if let range = lower.range(of: starter) {
                    let start = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))
                    let tail = text[start...]
                    let end = tail.firstIndex(where: { ".!?\n".contains($0) }) ?? tail.endIndex
                    fact = tail[..<end]
                    break
                }
            }
        }
        guard var clean = fact.map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) }), clean.count >= 4 else {
            return nil
        }
        clean = String(clean.prefix(160))
        while let last = clean.last, ".!?".contains(last) { clean.removeLast() }
        clean = clean.prefix(1).uppercased() + clean.dropFirst() + "."
        let lowerFact = clean.lowercased()
        let category: MemoryCategory
        if ["negocio", "tienda", "vendo", "emprend", "empresa"].contains(where: { lowerFact.contains($0) }) {
            category = .negocio
        } else if ["me llamo", "soy de", "vivo en", "estudio", "trabajo"].contains(where: { lowerFact.contains($0) }) {
            category = .perfil
        } else {
            category = .preferencias
        }
        return Memory(text: clean, category: category)
    }

    /// First seven words, without opening ¿¡ or closing punctuation.
    static func title(from text: String) -> String {
        let words = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).prefix(7).joined(separator: " ")
        var title = words.trimmingCharacters(in: CharacterSet(charactersIn: "¿¡ "))
        while let last = title.last, ".,;:!?".contains(last) { title.removeLast() }
        if title.isEmpty { return "Chat sin título" }
        return title.prefix(1).uppercased() + title.dropFirst()
    }

    // MARK: - Live conversation

    /// Short answers for a live conversation: plain sentences that sound natural out loud.
    /// Demo answers until the server is connected; the rate, the time and memory already work for real.
    static func spoken(for said: String, mode: ChatMode, memory: Memory?, pay: PaymentSettings,
                       name: String, now: Date = Date()) -> VoiceAnswer {
        let plain = fold(said)
        let words = plain.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let short = words.count <= 6
        let you = name.isEmpty ? "" : ", \(name)"

        if short, containsAny(plain, ["adios", "chao", "chau", "hasta luego", "nos vemos", "eso es todo",
                                       "terminar la conversacion", "ya termine", "cuelga"]) {
            return VoiceAnswer(text: "¡Chao\(you)! Cuando quieras seguimos hablando.", ends: true)
        }
        if let memory {
            return VoiceAnswer(text: "Listo, lo guardé en mi memoria: «\(memory.text)» ¿Seguimos?")
        }
        if let conversion = conversion(in: said, pay: pay) {
            return VoiceAnswer(text: conversion)
        }
        if containsAny(plain, ["tasa", "bcv", "dolar", "dolares", "euro", "euros"]),
           containsAny(plain, ["cuanto", "a como", "como esta", "tasa", "precio", "valor"]) {
            return VoiceAnswer(text: "Según la tasa oficial del BCV que tengo del \(dayMonth(pay.rateDate)), el euro está en \(amount(pay.rateEur)) bolívares y el dólar en \(amount(pay.rateUsd)). Dime un monto y te lo convierto.")
        }
        if containsAny(plain, ["que hora es", "que hora son", "dime la hora", "me dices la hora"]) {
            return VoiceAnswer(text: clock(now))
        }
        if containsAny(plain, ["que dia es", "que fecha es", "fecha de hoy", "dia es hoy"]) {
            return VoiceAnswer(text: "Hoy es \(fullDate(now)).")
        }
        if containsAny(plain, ["quien eres", "como te llamas", "que eres", "que puedes hacer", "en que me ayudas"]) {
            return VoiceAnswer(text: "Soy Lithium, la inteligencia artificial de Liminal. Te ayudo con tu negocio, tus estudios, tu trabajo y lo del día a día. ¿Por dónde empezamos?")
        }
        if short, containsAny(plain, ["gracias", "muy amable", "te pasaste"]) {
            return VoiceAnswer(text: "¡Con gusto\(you)! ¿Te ayudo con algo más?")
        }
        if short, let first = words.first, ["hola", "buenas", "buenos", "epa", "saludos", "hey"].contains(first) {
            return VoiceAnswer(text: "¡Hola\(you)! Te escucho. ¿En qué te ayudo?")
        }

        let topic = shortTopic(said, limit: 60).trimmingCharacters(in: CharacterSet(charactersIn: "¿¡?!.,; "))
        var answer = modeAnswer(topic, mode: mode)
        answer.generic = true
        return answer
    }

    private static func modeAnswer(_ topic: String, mode: ChatMode) -> VoiceAnswer {
        switch mode {
        case .emprendedor:
            return VoiceAnswer(text: "Para «\(topic)», te propongo un mensaje corto, con el precio claro y una pregunta al final, como «¿te lo aparto?». Y responde rápido: es cuando más se vende. ¿Quieres que te lo deje escrito en el chat?")
        case .estudiante:
            return VoiceAnswer(text: "Vamos con «\(topic)». Primero entiende para qué sirve, y después memorizas. Te lo explico en tres ideas y luego te hago una pregunta de práctica. ¿Empezamos?")
        case .empleo:
            return VoiceAnswer(text: "Para «\(topic)», empieza cada logro con un verbo y súmale un número, por ejemplo: atendí a cuarenta clientes al día. ¿Quieres que practiquemos una entrevista ahora mismo?")
        case .diadia:
            return VoiceAnswer(text: "Con «\(topic)», haz primero lo más urgente y deja un rato libre al final del día. ¿Cuánto tiempo tienes hoy?")
        case .general:
            return VoiceAnswer(text: "Sobre «\(topic)»: define qué quieres lograr, separa lo que depende de ti y empieza por el paso más pequeño. ¿Lo convertimos en un plan?")
        }
    }

    /// "20 dólares", "$20", "15 euros" or "10.000 bolívares", converted with the BCV rate.
    static func conversion(in said: String, pay: PaymentSettings) -> String? {
        let plain = fold(said)
        let pattern = #"(\$\s*)?(\d[\d.,]*)\s*(dolares|dolar|usd|\$|euros|euro|eur|€|bolivares|bolivar|bs)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(plain.startIndex..., in: plain)
        for match in regex.matches(in: plain, range: range) {
            guard let numberRange = Range(match.range(at: 2), in: plain), let value = number(String(plain[numberRange])),
                  value > 0 else { continue }
            let dollarSign = match.range(at: 1).location != NSNotFound
            let unit = Range(match.range(at: 3), in: plain).map { String(plain[$0]) } ?? (dollarSign ? "$" : "")
            let when = dayMonth(pay.rateDate)
            switch unit {
            case "dolares", "dolar", "usd", "$":
                let label = value == 1 ? "1 dólar es" : "\(amount(value)) dólares son"
                return "\(label) \(amount(value * pay.rateUsd)) bolívares, con la tasa del BCV del \(when)."
            case "euros", "euro", "eur", "€":
                let label = value == 1 ? "1 euro es" : "\(amount(value)) euros son"
                return "\(label) \(amount(value * pay.rateEur)) bolívares, con la tasa del BCV del \(when)."
            case "bolivares", "bolivar", "bs":
                guard pay.rateUsd > 0, pay.rateEur > 0 else { return nil }
                return "\(amount(value)) bolívares son \(amount(value / pay.rateUsd)) dólares o \(amount(value / pay.rateEur)) euros, con la tasa del BCV del \(when)."
            default:
                continue
            }
        }
        return nil
    }

    /// Reads "20", "10.000", "1.234,56", "12,5" or "1,234.56".
    static func number(_ raw: String) -> Double? {
        var text = raw
        while let last = text.last, ".,".contains(last) { text.removeLast() }
        let hasDot = text.contains("."), hasComma = text.contains(",")
        if hasDot && hasComma {
            let decimal: Character = text.lastIndex(of: ",")! > text.lastIndex(of: ".")! ? "," : "."
            let grouping: Character = decimal == "," ? "." : ","
            text = text.replacingOccurrences(of: String(grouping), with: "").replacingOccurrences(of: String(decimal), with: ".")
        } else if hasDot {
            let groups = text.split(separator: ".", omittingEmptySubsequences: false)
            if groups.count > 1, groups.dropFirst().allSatisfy({ $0.count == 3 }), groups[0].count <= 3 {
                text = text.replacingOccurrences(of: ".", with: "")
            }
        } else if hasComma {
            text = text.replacingOccurrences(of: ",", with: ".")
        }
        return Double(text)
    }

    /// 17558.4 → "17.558,40", 20 → "20". Written for reading aloud in Venezuelan Spanish.
    static func amount(_ value: Double) -> String {
        let cents = Int((value * 100).rounded())
        let whole = cents / 100, part = cents % 100
        var digits = String(whole)
        var grouped = ""
        while digits.count > 3 {
            grouped = "." + digits.suffix(3) + grouped
            digits.removeLast(3)
        }
        grouped = digits + grouped
        return part == 0 ? grouped : grouped + "," + (part < 10 ? "0\(part)" : "\(part)")
    }

    /// "Son las 2 y 41 de la tarde."
    static func clock(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0, minute = parts.minute ?? 0
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        let period: String
        switch hour {
        case 0..<6: period = "de la madrugada"
        case 6..<12: period = "de la mañana"
        case 12..<19: period = "de la tarde"
        default: period = "de la noche"
        }
        let verb = twelve == 1 ? "Es la" : "Son las"
        let minutes = minute == 0 ? " en punto" : " y \(minute)"
        return "\(verb) \(twelve)\(minutes) \(period)."
    }

    static func dayMonth(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.day, .month], from: date)
        return "\(parts.day ?? 1) de \(monthNames[max(0, min(11, (parts.month ?? 1) - 1))])"
    }

    static func fullDate(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.weekday, .day, .month, .year], from: date)
        let weekday = weekdayNames[max(0, min(6, (parts.weekday ?? 1) - 1))]
        return "\(weekday) \(dayMonth(date)) de \(parts.year ?? 2026)"
    }

    private static let monthNames = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
                                     "septiembre", "octubre", "noviembre", "diciembre"]
    private static let weekdayNames = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]

    /// The model's reasoning as short lines for the "Razonó durante…" panel: the last 10, each up to 280 characters.
    static func thoughtLines(_ reasoning: String) -> [String] {
        let lines = reasoning.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.suffix(10).map { $0.count > 280 ? String($0.prefix(279)) + "…" : $0 }
    }

    /// What the server should know about attached files: their text, or that it could not be read.
    static func filesForModel(_ files: [Attachment]) -> String {
        files.map { file -> String in
            file.text.isEmpty
                ? "\n\n[Archivo adjunto: \(file.name) (\(file.kind.label)). Su contenido no se pudo leer en el teléfono.]"
                : "\n\n[Archivo adjunto: \(file.name)]\n\(String(file.text.prefix(12_000)))"
        }.joined()
    }

    /// Text that sounds right out loud: no Markdown marks.
    static func speakable(_ text: String) -> String {
        text.filter { !"*#_`>".contains($0) }
    }

    /// The first sentence of an answer without Markdown, for the Dynamic Island.
    static func preview(of markdown: String, limit: Int = 110) -> String {
        var lines: [String] = []
        for raw in markdown.split(separator: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            while let first = line.first, "#>-*".contains(first) { line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces) }
            if let dot = line.firstIndex(of: "."), line[line.startIndex..<dot].allSatisfy(\.isNumber), !line.isEmpty, line.first!.isNumber {
                line = String(line[line.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
            }
            line = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: "")
            if !line.isEmpty { lines.append(line) }
        }
        let flat = lines.joined(separator: " ")
        return flat.count > limit ? String(flat.prefix(limit - 1)) + "…" : flat
    }

    /// Lowercase, without accents, so "¿Cuánto está el dólar?" matches "cuanto" and "dolar".
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
            .replacingOccurrences(of: "¿", with: "").replacingOccurrences(of: "¡", with: "")
    }

    private static func containsAny(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains { phrase in
            text.range(of: #"(^|[^a-z0-9])"# + NSRegularExpression.escapedPattern(for: phrase) + #"($|[^a-z0-9])"#,
                       options: .regularExpression) != nil
        }
    }

    private static func shortTopic(_ text: String, limit: Int) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return flat.count > limit ? String(flat.prefix(limit)) + "…" : flat
    }

    // MARK: - Demo pages and presentations

    /// Without the server, a request for a page or a presentation gets a sample live file, so the preview can be tried.
    static func demoArtifact(for text: String) -> String? {
        let lower = text.lowercased()
        let wantsDeck = lower.range(of: #"presentaci[oó]n|diapositivas|\bslides?\b"#, options: .regularExpression) != nil
        let wantsPage = lower.range(of: #"p[aá]gina|landing|sitio web|\bweb\b|\bapp\b|aplicaci[oó]n|calculadora|juego"#, options: .regularExpression) != nil
            && lower.range(of: #"\b(word|docx|pdf)\b"#, options: .regularExpression) == nil
        guard wantsDeck || wantsPage else { return nil }
        let raw = text.components(separatedBy: ": ").last ?? text
        var about = raw
        if let range = raw.range(of: #"\b(sobre|acerca de|para|del|de)\s+"#, options: [.regularExpression, .caseInsensitive]) {
            about = String(raw[range.upperBound...])
        }
        about = about.trimmingCharacters(in: CharacterSet(charactersIn: " .?!¿¡\n")).prefix(60).description
        if about.isEmpty { about = "Tu proyecto" }
        let title = about.prefix(1).uppercased() + about.dropFirst()
        let safe = title.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        if wantsDeck {
            return """
            Listo: una presentación de 4 diapositivas sobre \(about). Ábrela y desliza o toca los lados de la pantalla.

            ```html
            <!DOCTYPE html>
            <html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Presentación: \(safe)</title>
            <style>
            *{box-sizing:border-box;margin:0}html,body{height:100%}
            body{font-family:-apple-system,system-ui,sans-serif;background:#0f1115;color:#f4f4f6;overflow:hidden}
            .slide{position:absolute;inset:0;display:flex;flex-direction:column;justify-content:center;gap:2.4vh;padding:8vh 8vw;opacity:0;transform:translateX(40px);transition:opacity .45s,transform .45s}
            .slide.on{opacity:1;transform:none}
            .kicker{color:#ffb347;font-weight:700;letter-spacing:.14em;text-transform:uppercase;font-size:.85rem}
            h1{font-size:clamp(2.2rem,9vw,5rem);line-height:1.02;letter-spacing:-.03em}h2{font-size:clamp(1.7rem,7vw,3.4rem);line-height:1.08}
            p,li{font-size:clamp(1rem,4vw,1.6rem);color:#b9bac4;line-height:1.45}ul{padding-left:1.2em;display:grid;gap:1.4vh}
            .big{font-size:clamp(3.4rem,18vw,9rem);font-weight:800;color:#ffb347;line-height:1}
            .count{position:fixed;right:18px;bottom:16px;color:#8d8e99;font-size:.9rem}
            </style></head><body>
            <section class="slide on"><div class="kicker">Presentación</div><h1>\(safe)</h1><p>Hecha por Lithium · toca para avanzar</p></section>
            <section class="slide"><div class="kicker">El reto</div><h2>Lo que hoy cuesta más de lo que debería</h2><ul><li>Procesos lentos y manuales</li><li>Poca información para decidir</li><li>Clientes que esperan rapidez</li></ul></section>
            <section class="slide"><div class="kicker">La propuesta</div><div class="big">3×</div><p>más rápido con una solución simple y medible.</p></section>
            <section class="slide"><div class="kicker">Siguiente paso</div><h2>Probarlo en 30 días</h2><p>Con el servidor conectado, Lithium la arma con tus datos.</p></section>
            <div class="count" id="count">1 / 4</div>
            <script>
            const s=[...document.querySelectorAll('.slide')];let i=0;
            function show(n){i=Math.max(0,Math.min(s.length-1,n));s.forEach((e,k)=>e.classList.toggle('on',k===i));document.getElementById('count').textContent=(i+1)+' / '+s.length;}
            document.body.addEventListener('click',e=>show(e.clientX>innerWidth/2?i+1:i-1));
            addEventListener('keydown',e=>{if(e.key==='ArrowRight')show(i+1);if(e.key==='ArrowLeft')show(i-1);});
            </script>
            </body></html>
            ```

            ¿Le agrego tus datos reales o una diapositiva de precios?
            """
        }
        return """
        Listo: una página para \(about), lista para ver en vivo.

        ```html
        <!DOCTYPE html>
        <html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>\(safe)</title>
        <style>
        :root{--ink:#16161a;--muted:#5b5b66;--bg:#faf8f5;--line:#ece7df}
        *{box-sizing:border-box;margin:0}body{font-family:-apple-system,system-ui,sans-serif;background:var(--bg);color:var(--ink)}
        header{display:flex;justify-content:space-between;align-items:center;padding:20px 6vw;font-weight:800}
        .hero{padding:8vh 6vw 6vh;display:grid;gap:20px}
        h1{font-size:clamp(2.2rem,9vw,4.4rem);line-height:1.02;letter-spacing:-.035em}
        .hero p{font-size:1.1rem;color:var(--muted);line-height:1.55}
        .btn{justify-self:start;padding:14px 22px;border-radius:999px;font-weight:600;background:var(--ink);color:#fff;text-decoration:none}
        .cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px;padding:0 6vw 8vh}
        .card{background:#fff;border:1px solid var(--line);border-radius:20px;padding:22px}
        .card b{display:block;margin-bottom:6px}.card span{color:var(--muted)}
        </style></head><body>
        <header>\(safe)</header>
        <section class="hero"><h1>\(safe), como te lo mereces.</h1><p>Página de ejemplo creada por Lithium. Con el servidor conectado, la diseña a tu medida.</p><a class="btn" href="#">Escríbenos por WhatsApp</a></section>
        <section class="cards"><div class="card"><b>Envíos a todo el país</b><span>En 24 a 72 horas.</span></div><div class="card"><b>Pago Móvil y divisas</b><span>Como te quede cómodo.</span></div><div class="card"><b>Atención cercana</b><span>Te respondemos rápido.</span></div></section>
        </body></html>
        ```

        ¿Le pongo tu logo, tus precios o una sección de preguntas?
        """
    }
}
