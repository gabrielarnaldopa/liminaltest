import Foundation

/// A piece of a document: the same blocks become a PDF or a Word file.
struct DocBlock: Equatable {
    enum Kind: Equatable {
        case heading, paragraph, bullet, quote, table
        case numbered(Int)
    }
    var kind: Kind
    /// Plain text, without Markdown marks.
    var text: String
    /// The same text keeping its **bold** marks, so Word can keep them.
    var marked: String = ""
    /// 1 is the document title ("# "), 2 a section ("## "), 3 or more a subsection.
    var level: Int = 3
    /// The cells of a table; the first row is the header.
    var rows: [[String]] = []
}

/// An answer that starts with "# Título" is a document: the app shows a card to download it.
struct DocumentInfo: Equatable {
    var title: String
    var words: Int
}

enum DocExport {
    // MARK: Documents

    /// The title and size of a document answer, or nil for an ordinary answer.
    static func document(in markdown: String) -> DocumentInfo? {
        guard let text = source(of: markdown) else { return nil }
        guard text.first == "#", let second = text.dropFirst().first, second == " " || second == "\t" else { return nil }
        let firstLine = text.prefix(while: { $0 != "\n" && $0 != "\r" })
        let title = clean(String(firstLine.dropFirst()))
        guard !title.isEmpty else { return nil }
        let body = text.dropFirst(firstLine.count)
        let words = body.split(whereSeparator: { $0.isWhitespace || "|#*>-".contains($0) }).count
        return DocumentInfo(title: title, words: words)
    }

    /// The document inside an answer, from its title on: Lithium sometimes writes a short sentence before it.
    /// A title further down only counts when a real document follows (60 words or more).
    static func source(of markdown: String) -> Substring? {
        let text = markdown.drop(while: { $0.isWhitespace })
        if text.hasPrefix("# ") || text.hasPrefix("#\t") { return text }
        guard let range = text.range(of: #"\n#[ \t]+\S"#, options: .regularExpression),
              text.distance(from: text.startIndex, to: range.lowerBound) <= 600 else { return nil }
        let rest = text[text.index(after: range.lowerBound)...]
        return rest.split(whereSeparator: { $0.isWhitespace }).count >= 60 ? rest : nil
    }

    /// True when the request asks for a file to download (a PDF, a Word file, a document).
    static func asksForFile(_ request: String) -> Bool {
        request.lowercased().range(of: #"\b(pdf|word|docx|documento|archivo|descarga|descargar)\b"#, options: .regularExpression) != nil
    }

    /// True when the request asks for a PDF and not for a Word file, so the card offers PDF first.
    static func prefersPDF(_ request: String) -> Bool {
        let text = request.lowercased()
        return text.range(of: #"\bpdf\b"#, options: .regularExpression) != nil
            && text.range(of: #"\bword\b|docx"#, options: .regularExpression) == nil
    }

    /// Takes the document title off the blocks when they start with one.
    static func split(_ blocks: [DocBlock], fallback: String) -> (title: String, blocks: [DocBlock], isDocument: Bool) {
        if let first = blocks.first, first.kind == .heading, first.level == 1 {
            return (first.text, Array(blocks.dropFirst()), true)
        }
        return (fallback, blocks, false)
    }

    // MARK: Markdown

    static func blocks(fromMarkdown markdown: String) -> [DocBlock] {
        let lines = markdown.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
        var blocks: [DocBlock] = []
        var index = 0
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            index += 1
            if line.isEmpty || line.hasPrefix("```") || isRule(line) { continue }
            if isRow(line), index < lines.count, isSeparator(lines[index].trimmingCharacters(in: .whitespaces)) {
                var rows = [cells(line)]
                index += 1
                while index < lines.count, isRow(lines[index].trimmingCharacters(in: .whitespaces)) {
                    rows.append(cells(lines[index].trimmingCharacters(in: .whitespaces)))
                    index += 1
                }
                blocks.append(DocBlock(kind: .table, text: "", rows: rows.map { $0.map(clean) }))
                continue
            }
            if line.hasPrefix("#") {
                let hashes = line.prefix(while: { $0 == "#" }).count
                blocks.append(block(.heading, String(line.dropFirst(hashes)), level: min(hashes, 4)))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                blocks.append(block(.bullet, String(line.dropFirst(2))))
            } else if line.hasPrefix(">") {
                blocks.append(block(.quote, String(line.dropFirst())))
            } else if let item = numbered(line) {
                blocks.append(item)
            } else {
                blocks.append(block(.paragraph, line))
            }
        }
        return blocks.filter { $0.kind == .table ? !$0.rows.isEmpty : !$0.text.isEmpty }
    }

    static func markdown(from blocks: [DocBlock]) -> String {
        blocks.map { block in
            switch block.kind {
            case .heading: return (block.level == 1 ? "# " : block.level == 2 ? "## " : "### ") + block.text
            case .bullet: return "- " + block.text
            case .numbered(let n): return "\(n). " + block.text
            case .quote: return "> " + block.text
            case .paragraph: return block.text
            case .table:
                return block.rows.enumerated().map { index, row in
                    let line = "| " + row.joined(separator: " | ") + " |"
                    return index == 0 ? line + "\n|" + row.map { _ in "---" }.joined(separator: "|") + "|" : line
                }.joined(separator: "\n")
            }
        }.joined(separator: "\n\n")
    }

    private static func block(_ kind: DocBlock.Kind, _ raw: String, level: Int = 3) -> DocBlock {
        let marked = raw.trimmingCharacters(in: .whitespaces)
        return DocBlock(kind: kind, text: clean(marked), marked: marked, level: level)
    }

    private static func numbered(_ line: String) -> DocBlock? {
        let digits = line.prefix(while: { $0.isNumber })
        guard !digits.isEmpty, let n = Int(digits) else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return block(.numbered(n), String(rest.dropFirst(2)))
    }

    private static func isRule(_ line: String) -> Bool {
        guard line.count >= 3, let first = line.first, "-*_".contains(first) else { return false }
        return line.allSatisfy { $0 == first }
    }

    private static func isRow(_ line: String) -> Bool {
        line.count >= 2 && line.hasPrefix("|") && line.hasSuffix("|")
    }

    private static func isSeparator(_ line: String) -> Bool {
        line.contains("--") && line.allSatisfy { "|-: ".contains($0) }
    }

    private static func cells(_ line: String) -> [String] {
        var inner = Substring(line)
        if inner.hasPrefix("|") { inner = inner.dropFirst() }
        if inner.hasSuffix("|") { inner = inner.dropLast() }
        return String(inner).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Removes **bold**, *italics* and `code` marks.
    static func clean(_ text: String) -> String {
        strip(text).trimmingCharacters(in: .whitespaces)
    }

    private static func strip(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "*", with: "")
    }

    // MARK: Word

    static func docx(blocks all: [DocBlock], title fallback: String) -> Data {
        let (title, blocks, isDocument) = split(all, fallback: fallback)
        func escape(_ text: String) -> String {
            text.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        }
        func run(_ text: String, bold: Bool = false, italic: Bool = false, size: Int? = nil, color: String? = nil) -> String {
            let props = (bold ? "<w:b/>" : "") + (italic ? "<w:i/>" : "")
                + (color.map { "<w:color w:val=\"\($0)\"/>" } ?? "") + (size.map { "<w:sz w:val=\"\($0)\"/>" } ?? "")
            return "<w:r>" + (props.isEmpty ? "" : "<w:rPr>\(props)</w:rPr>") + "<w:t xml:space=\"preserve\">\(escape(text))</w:t></w:r>"
        }
        /// The text in runs, with the parts between ** marks in bold.
        func runs(_ marked: String, italic: Bool = false, color: String? = nil) -> String {
            let parts = marked.components(separatedBy: "**")
            let balanced = parts.count % 2 == 1
            return parts.enumerated().map { index, part in
                part.isEmpty ? "" : run(strip(part), bold: balanced && index % 2 == 1, italic: italic, color: color)
            }.joined()
        }
        func paragraph(_ inner: String, style: String? = nil, indent: Int = 0, hanging: Int = 0, after: Int? = nil) -> String {
            var props = ""
            if let style { props += "<w:pStyle w:val=\"\(style)\"/>" }
            if let after { props += "<w:spacing w:after=\"\(after)\"/>" }
            if indent > 0 { props += "<w:ind w:left=\"\(indent)\" w:hanging=\"\(hanging)\"/>" }
            return "<w:p>" + (props.isEmpty ? "" : "<w:pPr>\(props)</w:pPr>") + inner + "</w:p>"
        }
        func marker(_ text: String) -> String {
            "<w:r><w:t xml:space=\"preserve\">\(escape(text))</w:t><w:tab/></w:r>"
        }
        func table(_ rows: [[String]]) -> String {
            let columns = max(1, rows.map(\.count).max() ?? 1)
            let width = 9638 / columns
            var xml = "<w:tbl><w:tblPr><w:tblStyle w:val=\"Tabla\"/><w:tblW w:w=\"5000\" w:type=\"pct\"/></w:tblPr><w:tblGrid>"
                + String(repeating: "<w:gridCol w:w=\"\(width)\"/>", count: columns) + "</w:tblGrid>"
            for (r, row) in rows.enumerated() {
                xml += "<w:tr>" + (r == 0 ? "<w:trPr><w:tblHeader/></w:trPr>" : "")
                for c in 0..<columns {
                    let shade = r == 0 ? "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"EDEDF0\"/>" : ""
                    xml += "<w:tc><w:tcPr><w:tcW w:w=\"\(width)\" w:type=\"dxa\"/>\(shade)</w:tcPr>"
                        + paragraph(run(c < row.count ? row[c] : "", bold: r == 0), after: 0) + "</w:tc>"
                }
                xml += "</w:tr>"
            }
            return xml + "</w:tbl>" + paragraph("", after: 60)
        }

        var body = isDocument ? "" : paragraph(run("\(Brand.modelName) · Kuolki", size: 18, color: "6E6E73"))
        body += paragraph(run(title), style: "Title")
        for block in blocks {
            let marked = block.marked.isEmpty ? block.text : block.marked
            switch block.kind {
            case .heading: body += paragraph(runs(marked), style: block.level <= 2 ? "Heading1" : "Heading2")
            case .bullet: body += paragraph(marker("•") + runs(marked), indent: 720, hanging: 360, after: 60)
            case .numbered(let n): body += paragraph(marker("\(n).") + runs(marked), indent: 720, hanging: 360, after: 60)
            case .quote: body += paragraph(runs(marked, italic: true, color: "48484A"), indent: 360)
            case .paragraph: body += paragraph(runs(marked))
            case .table: body += table(block.rows)
            }
        }
        let header = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        let contentTypes = header + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/><Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/></Types>"
        let rels = header + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>"
        let documentRels = header + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/></Relationships>"
        let document = header + "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>\(body)<w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/><w:pgMar w:top=\"1134\" w:right=\"1134\" w:bottom=\"1134\" w:left=\"1134\" w:header=\"708\" w:footer=\"708\" w:gutter=\"0\"/></w:sectPr></w:body></w:document>"
        return StoredZip.make([
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rels.utf8)),
            ("word/_rels/document.xml.rels", Data(documentRels.utf8)),
            ("word/styles.xml", Data((header + wordStyles).utf8)),
            ("word/document.xml", Data(document.utf8))
        ])
    }

    /// Calibri 11, a title, two heading levels (they show in Word's navigation pane) and a table style.
    private static let wordStyles: String = {
        let borders = ["top", "left", "bottom", "right", "insideH", "insideV"]
            .map { "<w:\($0) w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"C4C4C9\"/>" }.joined()
        return "<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
            + "<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii=\"Calibri\" w:hAnsi=\"Calibri\" w:eastAsia=\"Calibri\" w:cs=\"Calibri\"/><w:color w:val=\"1D1D1F\"/><w:sz w:val=\"22\"/><w:szCs w:val=\"22\"/><w:lang w:val=\"es-VE\"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after=\"140\" w:line=\"276\" w:lineRule=\"auto\"/></w:pPr></w:pPrDefault></w:docDefaults>"
            + "<w:style w:type=\"paragraph\" w:default=\"1\" w:styleId=\"Normal\"><w:name w:val=\"Normal\"/><w:qFormat/></w:style>"
            + "<w:style w:type=\"paragraph\" w:styleId=\"Title\"><w:name w:val=\"Title\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:qFormat/><w:pPr><w:spacing w:after=\"240\"/></w:pPr><w:rPr><w:b/><w:sz w:val=\"40\"/><w:szCs w:val=\"40\"/></w:rPr></w:style>"
            + "<w:style w:type=\"paragraph\" w:styleId=\"Heading1\"><w:name w:val=\"heading 1\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:uiPriority w:val=\"9\"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before=\"280\" w:after=\"100\"/><w:outlineLvl w:val=\"0\"/></w:pPr><w:rPr><w:b/><w:sz w:val=\"30\"/><w:szCs w:val=\"30\"/></w:rPr></w:style>"
            + "<w:style w:type=\"paragraph\" w:styleId=\"Heading2\"><w:name w:val=\"heading 2\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:uiPriority w:val=\"9\"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before=\"200\" w:after=\"80\"/><w:outlineLvl w:val=\"1\"/></w:pPr><w:rPr><w:b/><w:color w:val=\"48484A\"/><w:sz w:val=\"26\"/><w:szCs w:val=\"26\"/></w:rPr></w:style>"
            + "<w:style w:type=\"table\" w:default=\"1\" w:styleId=\"TableNormal\"><w:name w:val=\"Normal Table\"/><w:tblPr><w:tblInd w:w=\"0\" w:type=\"dxa\"/><w:tblCellMar><w:top w:w=\"0\" w:type=\"dxa\"/><w:left w:w=\"108\" w:type=\"dxa\"/><w:bottom w:w=\"0\" w:type=\"dxa\"/><w:right w:w=\"108\" w:type=\"dxa\"/></w:tblCellMar></w:tblPr></w:style>"
            + "<w:style w:type=\"table\" w:styleId=\"Tabla\"><w:name w:val=\"Tabla Kuolki\"/><w:basedOn w:val=\"TableNormal\"/><w:tblPr><w:tblBorders>\(borders)</w:tblBorders><w:tblCellMar><w:top w:w=\"60\" w:type=\"dxa\"/><w:left w:w=\"100\" w:type=\"dxa\"/><w:bottom w:w=\"60\" w:type=\"dxa\"/><w:right w:w=\"100\" w:type=\"dxa\"/></w:tblCellMar></w:tblPr></w:style>"
            + "</w:styles>"
    }()

    // MARK: Files

    /// Writes the data to a temporary file ready to share.
    static func temporaryFile(_ data: Data, title: String, ext: String) throws -> URL {
        let base = title.folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let name = String((base.isEmpty ? "documento" : base).prefix(50)) + "." + ext
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}

/// A minimal ZIP writer without compression, enough for Word documents.
enum StoredZip {
    static func make(_ files: [(String, Data)]) -> Data {
        var archive = Data()
        var directory = Data()
        for (name, data) in files {
            let nameData = Data(name.utf8)
            let crc = crc32(data)
            let offset = UInt32(archive.count)
            // Local file header
            archive.append(le32(0x0403_4B50))
            archive.append(le16(20)); archive.append(le16(0)); archive.append(le16(0))
            archive.append(le16(0)); archive.append(le16(0x21))
            archive.append(le32(crc)); archive.append(le32(UInt32(data.count))); archive.append(le32(UInt32(data.count)))
            archive.append(le16(UInt16(nameData.count))); archive.append(le16(0))
            archive.append(nameData)
            archive.append(data)
            // Central directory entry
            directory.append(le32(0x0201_4B50))
            directory.append(le16(20)); directory.append(le16(20)); directory.append(le16(0)); directory.append(le16(0))
            directory.append(le16(0)); directory.append(le16(0x21))
            directory.append(le32(crc)); directory.append(le32(UInt32(data.count))); directory.append(le32(UInt32(data.count)))
            directory.append(le16(UInt16(nameData.count))); directory.append(le16(0)); directory.append(le16(0))
            directory.append(le16(0)); directory.append(le16(0)); directory.append(le32(0))
            directory.append(le32(offset))
            directory.append(nameData)
        }
        let directoryOffset = UInt32(archive.count)
        archive.append(directory)
        archive.append(le32(0x0605_4B50))
        archive.append(le16(0)); archive.append(le16(0))
        archive.append(le16(UInt16(files.count))); archive.append(le16(UInt16(files.count)))
        archive.append(le32(UInt32(directory.count))); archive.append(le32(directoryOffset))
        archive.append(le16(0))
        return archive
    }

    private static func le16(_ value: UInt16) -> Data {
        Data([UInt8(value & 0xFF), UInt8(value >> 8)])
    }

    private static func le32(_ value: UInt32) -> Data {
        Data([UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8(value >> 24)])
    }

    private static let table: [UInt32] = (0..<256).map { index -> UInt32 in
        var c = UInt32(index)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}
