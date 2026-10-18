import Foundation
import UIKit

extension DocExport {
    /// Draws the blocks on A4 pages. A document keeps its own title and has no Liminal line on top.
    static func pdf(blocks all: [DocBlock], title fallback: String) -> Data {
        let (title, blocks, isDocument) = split(all, fallback: fallback)
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 56
        let width = page.width - margin * 2
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            var y = margin
            context.beginPage()

            func styled(_ text: String, font: UIFont, color: UIColor = .black) -> NSAttributedString {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 3
                return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
            }
            func height(of string: NSAttributedString, width: CGFloat) -> CGFloat {
                ceil(string.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                         options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
            }
            func room(_ needed: CGFloat) {
                if y + needed > page.height - margin {
                    context.beginPage()
                    y = margin
                }
            }
            func draw(_ text: String, font: UIFont, color: UIColor = .black, indent: CGFloat = 0, before: CGFloat = 0, after: CGFloat = 8) {
                let string = styled(text, font: font, color: color)
                let tall = height(of: string, width: width - indent)
                room(before + tall)
                y += before
                string.draw(in: CGRect(x: margin + indent, y: y, width: width - indent, height: tall))
                y += tall + after
            }
            func table(_ rows: [[String]]) {
                let columns = max(1, rows.map(\.count).max() ?? 1)
                let cellWidth = width / CGFloat(columns)
                let pad: CGFloat = 5
                y += 2
                for (r, row) in rows.enumerated() {
                    let font: UIFont = r == 0 ? .boldSystemFont(ofSize: 9.5) : .systemFont(ofSize: 9.5)
                    let cells = (0..<columns).map { c in styled(c < row.count ? row[c] : "", font: font) }
                    let rowHeight = (cells.map { height(of: $0, width: cellWidth - pad * 2) }.max() ?? 0) + pad * 2
                    room(rowHeight)
                    if r == 0 {
                        UIColor(white: 0.93, alpha: 1).setFill()
                        UIRectFill(CGRect(x: margin, y: y, width: width, height: rowHeight))
                    }
                    UIColor(white: 0.77, alpha: 1).setStroke()
                    for (c, cell) in cells.enumerated() {
                        let x = margin + CGFloat(c) * cellWidth
                        let frame = UIBezierPath(rect: CGRect(x: x, y: y, width: cellWidth, height: rowHeight))
                        frame.lineWidth = 0.6
                        frame.stroke()
                        cell.draw(in: CGRect(x: x + pad, y: y + pad, width: cellWidth - pad * 2, height: rowHeight - pad * 2))
                    }
                    y += rowHeight
                }
                y += 12
            }

            if !isDocument {
                draw("\(Brand.modelName) · Liminal", font: .systemFont(ofSize: 9), color: .gray, after: 6)
            }
            draw(title, font: .boldSystemFont(ofSize: isDocument ? 20 : 18), after: 12)
            for block in blocks {
                switch block.kind {
                case .heading: draw(block.text, font: .boldSystemFont(ofSize: block.level <= 2 ? 14 : 12.5), before: 4, after: 6)
                case .bullet: draw("•  " + block.text, font: .systemFont(ofSize: 11), indent: 14, after: 4)
                case .numbered(let n): draw("\(n).  " + block.text, font: .systemFont(ofSize: 11), indent: 14, after: 4)
                case .quote: draw(block.text, font: .italicSystemFont(ofSize: 11), color: .darkGray, indent: 14)
                case .paragraph: draw(block.text, font: .systemFont(ofSize: 11))
                case .table: table(block.rows)
                }
            }
        }
    }
}
