#!/usr/bin/swift

import Foundation
import AppKit
import PDFKit

struct Theme {
  let pageBackground = NSColor(calibratedRed: 0.992, green: 0.985, blue: 0.971, alpha: 1.0)
  let cardBackground = NSColor(calibratedRed: 1.0, green: 0.992, blue: 0.973, alpha: 1.0)
  let border = NSColor(calibratedRed: 0.835, green: 0.796, blue: 0.733, alpha: 1.0)
  let text = NSColor(calibratedRed: 0.180, green: 0.165, blue: 0.141, alpha: 1.0)
  let muted = NSColor(calibratedRed: 0.455, green: 0.412, blue: 0.357, alpha: 1.0)
  let snake = NSColor(calibratedRed: 0.247, green: 0.490, blue: 0.302, alpha: 1.0)
  let food = NSColor(calibratedRed: 0.792, green: 0.357, blue: 0.278, alpha: 1.0)
}

struct Fonts {
  let title = NSFont.systemFont(ofSize: 25, weight: .bold)
  let subtitle = NSFont.systemFont(ofSize: 10.5, weight: .regular)
  let section = NSFont.systemFont(ofSize: 11, weight: .semibold)
  let body = NSFont.systemFont(ofSize: 9.9, weight: .regular)
  let bullet = NSFont.systemFont(ofSize: 9.8, weight: .regular)
}

let theme = Theme()
let fonts = Fonts()
let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
let margin: CGFloat = 40
let contentWidth = pageRect.width - (margin * 2)
let cardInset: CGFloat = 14

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let outputDir = repoRoot.appendingPathComponent("output/pdf", isDirectory: true)
let tempDir = repoRoot.appendingPathComponent("tmp/pdfs", isDirectory: true)
let pdfURL = outputDir.appendingPathComponent("snake-app-summary.pdf")
let previewURL = tempDir.appendingPathComponent("snake-app-summary-preview.png")

let whatItIs = """
Snake is a static browser game that recreates the classic arcade experience in plain HTML, CSS, and JavaScript. The entire UI and gameplay loop run in the page, and no backend, package manifest, or build tooling was found in the repo.
"""

let whoItsFor = """
Players who want a lightweight browser game with both keyboard and on-screen controls, including smaller-screen use suggested by the responsive layout.
"""

let features = [
  "Renders a 16 x 16 board and paints snake, head, and food states directly in the DOM.",
  "Starts movement from Arrow keys or WASD and blocks reverse-direction turns.",
  "Shows a live score in the header while updating status text for start, pause, play, win, and game-over states.",
  "Includes touch-friendly directional buttons for up, left, down, and right input.",
  "Lets the player pause and resume with the button or Space key.",
  "Lets the player restart with the button or the R key.",
  "Randomly places food, grows the snake on pickup, detects collisions, and declares a win when the board is full."
]

let architecture = [
  "index.html defines the shell: title, score panel, status message, board container, action buttons, touch controls, and script loading order.",
  "js/game.js exposes window.SnakeGame and owns the game rules: initial state, seeded RNG, food placement, direction changes, pause logic, collisions, and tick-to-tick state transitions.",
  "js/main.js bootstraps the page, builds the board grid, maps keyboard and button input to game actions, advances the game every 140 ms, and re-renders score, status, and cell classes.",
  "styles.css supplies the visual system: centered panel layout, responsive stacking under 520 px, and color/state styling for the board, controls, and score panel.",
  "External services, APIs, persistence, analytics, and backend components: Not found in repo."
]

let gettingStarted = [
  "Open index.html in a browser.",
  "Use Arrow keys or WASD to start and steer; Space pauses and R restarts.",
  "Dedicated install, build, test, or server steps: Not found in repo."
]

func paragraphStyle(lineSpacing: CGFloat, spacingAfter: CGFloat = 0) -> NSMutableParagraphStyle {
  let style = NSMutableParagraphStyle()
  style.lineSpacing = lineSpacing
  style.paragraphSpacing = spacingAfter
  return style
}

func bulletStyle() -> NSMutableParagraphStyle {
  let style = NSMutableParagraphStyle()
  style.lineSpacing = 2
  style.paragraphSpacing = 2
  style.firstLineHeadIndent = 0
  style.headIndent = 12
  return style
}

func drawText(
  _ text: String,
  rect: CGRect,
  font: NSFont,
  color: NSColor,
  paragraph: NSParagraphStyle
) -> CGFloat {
  let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: color,
    .paragraphStyle: paragraph
  ]
  let attributed = NSAttributedString(string: text, attributes: attributes)
  let measured = attributed.boundingRect(
    with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
    options: [.usesLineFragmentOrigin, .usesFontLeading]
  )
  let height = ceil(measured.height)
  attributed.draw(
    with: CGRect(x: rect.minX, y: rect.maxY - height, width: rect.width, height: height),
    options: [.usesLineFragmentOrigin, .usesFontLeading]
  )
  return height
}

func drawSectionHeading(_ title: String, y: inout CGFloat) {
  y -= 6
  let headingHeight = drawText(
    title.uppercased(),
    rect: CGRect(x: margin + cardInset, y: y - 18, width: contentWidth - (cardInset * 2), height: 18),
    font: fonts.section,
    color: theme.snake,
    paragraph: paragraphStyle(lineSpacing: 1)
  )
  y -= headingHeight + 5

  theme.border.setFill()
  NSBezierPath(rect: CGRect(x: margin + cardInset, y: y, width: contentWidth - (cardInset * 2), height: 1)).fill()
  y -= 10
}

func drawParagraph(_ text: String, y: inout CGFloat) {
  let height = drawText(
    text,
    rect: CGRect(x: margin + cardInset, y: y - 300, width: contentWidth - (cardInset * 2), height: 300),
    font: fonts.body,
    color: theme.text,
    paragraph: paragraphStyle(lineSpacing: 2)
  )
  y -= height + 10
}

func drawBullets(_ bullets: [String], y: inout CGFloat) {
  for bullet in bullets {
    let line = "- " + bullet
    let height = drawText(
      line,
      rect: CGRect(x: margin + cardInset, y: y - 220, width: contentWidth - (cardInset * 2), height: 220),
      font: fonts.bullet,
      color: theme.text,
      paragraph: bulletStyle()
    )
    y -= height + 2
  }
  y -= 4
}

func renderPreview(from pdfURL: URL, to previewURL: URL) throws -> Int {
  guard let document = PDFDocument(url: pdfURL) else {
    throw NSError(domain: "PDF", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open generated PDF."])
  }

  guard let page = document.page(at: 0) else {
    throw NSError(domain: "PDF", code: 2, userInfo: [NSLocalizedDescriptionKey: "Generated PDF is missing page 1."])
  }

  let image = page.thumbnail(of: NSSize(width: 1224, height: 1584), for: .mediaBox)
  guard let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "PDF", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create preview image."])
  }

  try png.write(to: previewURL)
  return document.pageCount
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

let consumer = CGDataConsumer(url: pdfURL as CFURL)!
var mediaBox = pageRect
guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
  fatalError("Could not create PDF context.")
}

context.beginPDFPage(nil)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

theme.pageBackground.setFill()
pageRect.fill()

let cardRect = CGRect(x: margin, y: margin, width: contentWidth, height: pageRect.height - (margin * 2))
theme.cardBackground.setFill()
NSBezierPath(roundedRect: cardRect, xRadius: 18, yRadius: 18).fill()
theme.border.setStroke()
let cardBorder = NSBezierPath(roundedRect: cardRect, xRadius: 18, yRadius: 18)
cardBorder.lineWidth = 1.2
cardBorder.stroke()

let accentRect = CGRect(x: margin, y: pageRect.height - margin - 20, width: contentWidth, height: 20)
theme.food.setFill()
NSBezierPath(roundedRect: accentRect, xRadius: 18, yRadius: 18).fill()
theme.cardBackground.setFill()
NSBezierPath(rect: CGRect(x: margin, y: pageRect.height - margin - 20, width: contentWidth, height: 10)).fill()

var y = pageRect.height - margin - 32

let titleHeight = drawText(
  "Snake App Summary",
  rect: CGRect(x: margin + cardInset, y: y - 40, width: contentWidth - (cardInset * 2), height: 40),
  font: fonts.title,
  color: theme.text,
  paragraph: paragraphStyle(lineSpacing: 1)
)
y -= titleHeight + 6

let subtitleHeight = drawText(
  "Repo evidence only: index.html, styles.css, js/game.js, and js/main.js",
  rect: CGRect(x: margin + cardInset, y: y - 22, width: contentWidth - (cardInset * 2), height: 22),
  font: fonts.subtitle,
  color: theme.muted,
  paragraph: paragraphStyle(lineSpacing: 1)
)
y -= subtitleHeight + 12

theme.border.setFill()
NSBezierPath(rect: CGRect(x: margin + cardInset, y: y, width: contentWidth - (cardInset * 2), height: 1)).fill()
y -= 12

drawSectionHeading("What it is", y: &y)
drawParagraph(whatItIs, y: &y)

drawSectionHeading("Who it is for", y: &y)
drawParagraph(whoItsFor, y: &y)

drawSectionHeading("What it does", y: &y)
drawBullets(features, y: &y)

drawSectionHeading("How it works", y: &y)
drawBullets(architecture, y: &y)

drawSectionHeading("How to run", y: &y)
drawBullets(gettingStarted, y: &y)

if y < margin + 10 {
  fputs("Warning: content is close to the bottom margin.\n", stderr)
}

NSGraphicsContext.restoreGraphicsState()
context.endPDFPage()
context.closePDF()

let pageCount = try renderPreview(from: pdfURL, to: previewURL)
print("PDF: \(pdfURL.path)")
print("Preview: \(previewURL.path)")
print("Pages: \(pageCount)")
