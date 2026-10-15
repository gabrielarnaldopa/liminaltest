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

    /// First seven words, without opening ¿¡ or closing punctuation.
    static func title(from text: String) -> String {
        let words = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).prefix(7).joined(separator: " ")
        var title = words.trimmingCharacters(in: CharacterSet(charactersIn: "¿¡ "))
        while let last = title.last, ".,;:!?".contains(last) { title.removeLast() }
        if title.isEmpty { return "Chat sin título" }
        return title.prefix(1).uppercased() + title.dropFirst()
    }

    private static func shortTopic(_ text: String, limit: Int) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return flat.count > limit ? String(flat.prefix(limit)) + "…" : flat
    }
}
