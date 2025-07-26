import SwiftUI
import Combine
import Foundation
import UIKit
import FSCalendar
import UserNotifications
import UniformTypeIdentifiers
import AppTrackingTransparency
import GoogleMobileAds
import Vision

// MARK: - Models/Ticket.swift
struct Ticket: Identifiable, Hashable, Codable {
    let id = UUID()
    let filepath: String
    let fecha: Date
    let tipo: String // "entrada", "salida" or "desconocido"
    let uniqueCode: String

    // imageData se cargará dinámicamente cuando sea necesario
    var imageData: Data? {
        if FileManager.default.fileExists(atPath: filepath) {
            return try? Data(contentsOf: URL(fileURLWithPath: filepath))
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case filepath, fecha, tipo, uniqueCode
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(filepath)
        hasher.combine(uniqueCode)
        hasher.combine(fecha)
        hasher.combine(tipo)
    }

    static func ==(lhs: Ticket, rhs: Ticket) -> Bool {
        return lhs.filepath == rhs.filepath &&
               lhs.uniqueCode == rhs.uniqueCode &&
               lhs.fecha == rhs.fecha &&
               lhs.tipo == rhs.tipo
    }
}
// MARK: - Extensions/ColorExtensions.swift
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb: Int = (Int(r * 255) << 16) | (Int(g * 255) << 8) | (Int(b * 255))
        return String(format: "#%06X", rgb)
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

// MARK: - Extensions/DateExtensions.swift
extension Date {
    func formattedString(locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = locale
        return formatter.string(from: self).isEmpty ? self.description : formatter.string(from: self)
    }
}

// MARK: - Extensions/UIApplicationExtensions.swift
extension UIApplication {
    var windows: [UIWindow] {
        return connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows ?? []
    }
}

// MARK: - Utilities/ErrorLogger.swift
class ErrorLogger {
    static let shared = ErrorLogger()

    enum LogLevel: String, CaseIterable, Identifiable {
        case action = "ACCIÓN"
        case error = "ERROR"
        case process = "PROCESO"
        var id: String { rawValue }
    }

    struct LogEntry: Identifiable {
        let id = UUID()
        let message: String
        let level: LogLevel
        let timestamp: Date
    }

    private var logs: [LogEntry] = []
    private let queue = DispatchQueue(label: "com.ticom.logger", attributes: .concurrent)

    private init() {}

    func log(_ message: String, level: LogLevel, error: Error? = nil) {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        formatter.timeZone = TimeZone.current
        let formattedTimestamp = formatter.string(from: timestamp)

        let prefix: String
        switch level {
        case .action: prefix = "📋 [ACCIÓN]"
        case .error: prefix = "🚨 [ERROR]"
        case .process: prefix = "⚙️ [PROCESO]"
        }

        var fullMessage = "\(prefix) [\(formattedTimestamp)]: \(message)"
        if let error = error {
            fullMessage += "\nStack Trace: \(error.localizedDescription)"
        }

        let logEntry = LogEntry(message: fullMessage, level: level, timestamp: timestamp)

        queue.async(flags: .barrier) {
            self.logs.insert(logEntry, at: 0)
            print(logEntry.message)
        }
    }

    func getLogs() -> [LogEntry] {
        var result: [LogEntry] = []
        queue.sync { result = logs }
        return result
    }

    func clearLogs() {
        queue.async(flags: .barrier) { self.logs.removeAll() }
    }

    func exportLogs() -> String {
        var result = ""
        queue.sync { result = logs.map { $0.message }.joined(separator: "\n") }
        return result
    }
}

// MARK: - Extensions/UIImageExtensions.swift
extension UIImage {
    func preprocessedForOCR() -> UIImage? {
        guard let ciImage = CIImage(image: self) else { return nil }
        let scale = 800 / max(size.width, size.height)
        let scaledCiImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let contrastFilter = CIFilter(name: "CIColorControls")!
        contrastFilter.setValue(scaledCiImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(2.0, forKey: kCIInputContrastKey)
        contrastFilter.setValue(0.0, forKey: kCIInputSaturationKey)
        contrastFilter.setValue(0.2, forKey: kCIInputBrightnessKey)

        let sharpenFilter = CIFilter(name: "CIUnsharpMask")!
        sharpenFilter.setValue(contrastFilter.outputImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(1.5, forKey: kCIInputRadiusKey)
        sharpenFilter.setValue(0.5, forKey: kCIInputIntensityKey)

        guard let outputImage = sharpenFilter.outputImage else { return nil }
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Models/TicketAnalyzer.swift
class TicketAnalyzer {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_DO")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private let cachedDatePatterns: [String] = [
        "(?:LUNES|MARTES|MIÉRCOLES|JUEVES|VIERNES|SÁBADO|DOMINGO) \\d{1,2} DE (?:ENERO|FEBRERO|MARZO|ABRIL|MAYO|JUNIO|JULIO|AGOSTO|SEPTIEMBRE|OCTUBRE|NOVIEMBRE|DICIEMBRE) DEL? \\d{4}",
        "\\d{1,2} DE (?:ENERO|FEBRERO|MARZO|ABRIL|MAYO|JUNIO|JULIO|AGOSTO|SEPTIEMBRE|OCTUBRE|NOVIEMBRE|DICIEMBRE) DE? \\d{4}",
        "\\d{1,2}/\\d{1,2}/\\d{4}",
        "\\d{1,2}-\\d{1,2}-\\d{4}",
        "\\d{4}-\\d{1,2}-\\d{1,2}"
    ]

    private let cachedDateFormats: [String] = [
        "EEEE d 'DE' MMMM 'DEL' yyyy",
        "d 'DE' MMMM 'DE' yyyy",
        "dd/MM/yyyy",
        "dd-MM-yyyy",
        "yyyy-MM-dd"
    ]

    private let codePattern = "\\b\\d{6,}\\b"
    private let typePatterns = ["ENTRADA", "SALIDA"]

    func analizarTicket(filepath: String, originalImage: UIImage, completion: @escaping (Ticket?) -> Void) {
        ErrorLogger.shared.log("Iniciando análisis de ticket: \(filepath)", level: .action)

        guard FileManager.default.fileExists(atPath: filepath) else {
            ErrorLogger.shared.log("Archivo no encontrado en \(filepath)", level: .error)
            completion(nil)
            return
        }

        guard let preprocessedImage = preprocessImage(originalImage, isRetry: false) else {
            ErrorLogger.shared.log("Fallo en el preprocesamiento inicial: \(filepath)", level: .error)
            completion(nil)
            return
        }

        tryWithVision(image: preprocessedImage, filepath: filepath, attempt: 0) { [weak self] ticket in
            guard let self = self else { return }
            if let ticket = ticket {
                completion(ticket)
                return
            }

            guard let retryImage = self.preprocessImage(originalImage, isRetry: true) else {
                ErrorLogger.shared.log("Fallo en el preprocesamiento de reintento: \(filepath)", level: .error)
                completion(nil)
                return
            }
            self.tryWithVision(image: retryImage, filepath: filepath, attempt: 1) { retryTicket in
                if let retryTicket = retryTicket {
                    completion(retryTicket)
                } else {
                    self.applyAdaptiveThresholding(image: originalImage, filepath: filepath, completion: completion)
                }
            }
        }
    }

    private func preprocessImage(_ image: UIImage, isRetry: Bool) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let maxDimension: CGFloat = isRetry ? 2200 : 1200
        let scale = maxDimension / max(image.size.width, image.size.height)
        let scaledCiImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let contrastFilter = CIFilter(name: "CIColorControls")!
        contrastFilter.setValue(scaledCiImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(isRetry ? 2.3 : 1.7, forKey: kCIInputContrastKey)
        contrastFilter.setValue(0.0, forKey: kCIInputSaturationKey)
        contrastFilter.setValue(isRetry ? 0.1 : 0.05, forKey: kCIInputBrightnessKey)

        guard let enhancedImage = contrastFilter.outputImage else { return nil }

        let sharpenFilter = CIFilter(name: "CIUnsharpMask")!
        sharpenFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(isRetry ? 3.8 : 2.3, forKey: kCIInputRadiusKey)
        sharpenFilter.setValue(isRetry ? 0.95 : 0.75, forKey: kCIInputIntensityKey)

        guard let sharpenedImage = sharpenFilter.outputImage else { return nil }

        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.setValue(sharpenedImage, forKey: kCIInputImageKey)
        blurFilter.setValue(isRetry ? 2.2 : 1.1, forKey: kCIInputRadiusKey)
        guard let blurredImage = blurFilter.outputImage else { return nil }

        let context = CIContext()
        guard let cgImage = context.createCGImage(blurredImage, from: blurredImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func detectFringeColor(_ image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let fringeWidth = 40
        let fringeRect = CGRect(x: width - fringeWidth, y: 0, width: fringeWidth, height: height)

        guard let croppedCGImage = cgImage.cropping(to: fringeRect) else { return nil }
        guard let pixelData = croppedCGImage.dataProvider?.data else { return nil }
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let bytesPerPixel = 4
        let bytesPerRow = croppedCGImage.bytesPerRow
        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0
        var pixelCount: CGFloat = 0

        for y in stride(from: 0, to: croppedCGImage.height, by: 4) {
            for x in stride(from: 0, to: croppedCGImage.width, by: 4) {
                let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = CGFloat(data[pixelIndex]) / 255.0
                let g = CGFloat(data[pixelIndex + 1]) / 255.0
                let b = CGFloat(data[pixelIndex + 2]) / 255.0
                totalR += r
                totalG += g
                totalB += b
                pixelCount += 1
            }
        }

        let avgR = totalR / pixelCount
        let avgG = totalG / pixelCount
        let avgB = totalB / pixelCount

        let greenThreshold = avgG > 0.45 && avgG > avgR * 1.2 && avgG > avgB * 1.2
        let blueThreshold = avgB > 0.45 && avgB > avgR * 1.2 && avgB > avgG * 1.2

        if greenThreshold { return "entrada" }
        if blueThreshold { return "salida" }
        return nil
    }

    private func tryWithVision(image: UIImage, filepath: String, attempt: Int, completion: @escaping (Ticket?) -> Void) {
        guard let cgImage = image.cgImage else {
            ErrorLogger.shared.log("No se pudo procesar la imagen: \(filepath)", level: .error)
            completion(nil)
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [.properties: [kCGImagePropertyOrientation as String: image.imageOrientation.rawValue]])
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            if let error = error {
                ErrorLogger.shared.log("Error en OCR (intento \(attempt + 1)): \(error.localizedDescription)", level: .error, error: error)
                completion(nil)
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                ErrorLogger.shared.log("No se detectó texto (intento \(attempt + 1)): \(filepath)", level: .error)
                completion(nil)
                return
            }

            let sortedObservations = observations.sorted { $0.boundingBox.minY < $1.boundingBox.minY }
            let texto = sortedObservations.compactMap { $0.topCandidates(attempt == 0 ? 2 : 5).first?.string }.joined(separator: "\n")
            ErrorLogger.shared.log("Texto extraído (intento \(attempt + 1)): \(texto)", level: .process)

            guard let ticket = self.processText(texto: texto, filepath: filepath) else {
                completion(nil)
                return
            }

            completion(ticket)
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-ES", "en-US"]
        request.usesLanguageCorrection = true
        request.customWords = ["ENTRADA", "SALIDA", "TICKET", "LUNES", "MARTES", "MIÉRCOLES", "JUEVES", "VIERNES", "SÁBADO", "DOMINGO", "ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO", "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE", "DEL", "DE"]
        request.minimumTextHeight = attempt == 0 ? 1 / 50 : 1 / 80
        request.regionOfInterest = attempt == 0 ? CGRect(x: 0, y: 0.1, width: 1, height: 0.9) : CGRect(x: 0, y: 0, width: 1, height: 1)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                ErrorLogger.shared.log("Error en Vision (intento \(attempt + 1)): \(error.localizedDescription)", level: .error, error: error)
                completion(nil)
            }
        }
    }

    private func applyAdaptiveThresholding(image: UIImage, filepath: String, completion: @escaping (Ticket?) -> Void) {
        guard image.cgImage != nil else { return }
        let context = CIContext()
        guard let ciImage = CIImage(image: image) else { return }

        let filter = CIFilter(name: "CIColorInvert")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let invertedImage = filter.outputImage else { return }
        guard let thresholdedImage = context.createCGImage(invertedImage, from: invertedImage.extent) else { return }
        let finalImage = UIImage(cgImage: thresholdedImage)

        tryWithVision(image: finalImage, filepath: filepath, attempt: 2) { ticket in
            if let ticket = ticket {
                completion(ticket)
            } else {
                ErrorLogger.shared.log("Falló el reconocimiento tras umbralización adaptativa: \(filepath)", level: .error)
                completion(nil)
            }
        }
    }

    private func processText(texto: String, filepath: String) -> Ticket? {
        let cleanedText = texto.replacingOccurrences(of: "[^\\w\\s\\d/\\-.:]", with: " ", options: .regularExpression)
        let lines = cleanedText.split(whereSeparator: \.isNewline).map(String.init)

        let typeLine = lines.first { line in
            typePatterns.contains { pattern in line.uppercased().contains(pattern) }
        }?.uppercased() ?? ""
        let tipo = if typeLine.contains("ENTRADA") { "entrada" }
                   else if typeLine.contains("SALIDA") { "salida" }
                   else { detectFringeColor(UIImage(contentsOfFile: filepath) ?? UIImage()) ?? "desconocido" }
        guard tipo != "desconocido" else { return nil }

        let bottomDateString = lines.reversed().first { line in
            cachedDatePatterns.contains { pattern in
                line.range(of: pattern, options: .regularExpression) != nil
            }
        } ?? lines.last
        guard let fecha = bottomDateString.flatMap({ extractValidatedDate($0) }) else { return nil }

        let codeLine = lines.first { line in
            line.range(of: codePattern, options: .regularExpression) != nil
        } ?? cleanedText
        guard let uniqueCode = extractCode(codeLine) else { return nil }

        return Ticket(filepath: filepath, fecha: fecha, tipo: tipo, uniqueCode: uniqueCode)
    }

    private func extractValidatedDate(_ text: String) -> Date? {
        let uppercasedText = text.uppercased()
        for (index, pattern) in cachedDatePatterns.enumerated() {
            if let range = uppercasedText.range(of: pattern, options: .regularExpression) {
                let dateString = String(uppercasedText[range]).trimmingCharacters(in: .whitespaces)
                dateFormatter.dateFormat = cachedDateFormats[index]
                if let date = dateFormatter.date(from: dateString), Calendar.current.isDate(date, inSameDayAs: date) {
                    return date
                }
            }
        }
        let numericPatterns = ["\\d{1,2}/\\d{1,2}/\\d{4}", "\\d{1,2}-\\d{1,2}-\\d{4}"]
        for pattern in numericPatterns {
            if let range = uppercasedText.range(of: pattern, options: .regularExpression) {
                let dateString = String(uppercasedText[range]).trimmingCharacters(in: .whitespaces)
                dateFormatter.dateFormat = pattern.contains("/") ? "dd/MM/yyyy" : "dd-MM-yyyy"
                if let date = dateFormatter.date(from: dateString), Calendar.current.isDate(date, inSameDayAs: date) {
                    return date
                }
            }
        }
        return nil
    }

    private func extractCode(_ text: String) -> String? {
        let uppercasedText = text.uppercased()
        if let range = uppercasedText.range(of: codePattern, options: .regularExpression) {
            let code = String(uppercasedText[range]).trimmingCharacters(in: .whitespaces)
            return code
        }
        return nil
    }
}

// MARK: - Models/TicketStorage.swift
class TicketStorage {
    private static let entradaFileName = "ticketsEntrada.json"
    private static let salidaFileName = "ticketsSalida.json"
    private static let fileManager = FileManager.default
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func guardarTickets(entrada: [Ticket], salida: [Ticket]) {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let entradaURL = documentsURL.appendingPathComponent(entradaFileName)
        let salidaURL = documentsURL.appendingPathComponent(salidaFileName)

        do {
            let entradaData = try encoder.encode(entrada.map { $0.removeImageDataForEncoding() })
            try entradaData.write(to: entradaURL, options: .atomic)
            ErrorLogger.shared.log("Tickets de entrada guardados en \(entradaURL.path)", level: .action)

            let salidaData = try encoder.encode(salida.map { $0.removeImageDataForEncoding() })
            try salidaData.write(to: salidaURL, options: .atomic)
            ErrorLogger.shared.log("Tickets de salida guardados en \(salidaURL.path)", level: .action)
        } catch {
            ErrorLogger.shared.log("Error al guardar tickets: \(error.localizedDescription)", level: .error, error: error)
        }
    }

    static func cargarTickets() -> ([Ticket], [Ticket]) {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let entradaURL = documentsURL.appendingPathComponent(entradaFileName)
        let salidaURL = documentsURL.appendingPathComponent(salidaFileName)

        var entrada: [Ticket] = []
        var salida: [Ticket] = []

        do {
            if fileManager.fileExists(atPath: entradaURL.path) {
                let entradaData = try Data(contentsOf: entradaURL)
                entrada = try decoder.decode([Ticket].self, from: entradaData).map { $0.restoreImageData() }
                ErrorLogger.shared.log("Tickets de entrada cargados: \(entrada.count)", level: .action)
            } else {
                ErrorLogger.shared.log("No se encontró archivo de tickets de entrada en \(entradaURL.path)", level: .process)
            }

            if fileManager.fileExists(atPath: salidaURL.path) {
                let salidaData = try Data(contentsOf: salidaURL)
                salida = try decoder.decode([Ticket].self, from: salidaData).map { $0.restoreImageData() }
                ErrorLogger.shared.log("Tickets de salida cargados: \(salida.count)", level: .action)
            } else {
                ErrorLogger.shared.log("No se encontró archivo de tickets de salida en \(salidaURL.path)", level: .process)
            }
        } catch {
            ErrorLogger.shared.log("Error al cargar tickets: \(error.localizedDescription)", level: .error, error: error)
        }

        // Validar que los filepaths existen
        entrada = entrada.filter { FileManager.default.fileExists(atPath: $0.filepath) }
        salida = salida.filter { FileManager.default.fileExists(atPath: $0.filepath) }

        return (entrada, salida)
    }
}

extension Ticket {
    func removeImageDataForEncoding() -> Ticket {
        let ticket = self
        // No hacemos nada aquí porque imageData no se serializa
        return ticket
    }

    func restoreImageData() -> Ticket {
        let ticket = self
        // imageData se recarga dinámicamente desde filepath
        return ticket
    }
}
// MARK: - Models/TicketProcessor.swift

class TicketProcessor {
    private let processingQueue = DispatchQueue(label: "com.ticom.ticketProcessing", qos: .userInitiated, attributes: .concurrent)
    private let maxConcurrentOperations = 5
    private let imageCache = NSCache<NSString, UIImage>()
    private let analyzer = TicketAnalyzer()
    private var isCancelled = false // Para manejar cancelación

    func processTickets(urls: [URL], progressHandler: @escaping (Double) -> Void, completion: @escaping ([Ticket]) -> Void) -> () -> Void {
        ErrorLogger.shared.log("Iniciando procesamiento de \(urls.count) tickets a las 11:55 PM AST, 27 de mayo de 2025", level: .action) // Fecha y hora del log original, ajustar si es necesario
        let totalTickets = urls.count
        var processedCount = 0      // Contador de tickets que han iniciado/finalizado procesamiento (éxito o error)
        var successfulCount = 0     // Contador solo de tickets procesados exitosamente
        var processedTickets: [Ticket] = [] // Array para almacenar tickets procesados exitosamente
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: maxConcurrentOperations)
        isCancelled = false // Resetear estado de cancelación

        for url in urls {
            guard !isCancelled else { break } // Salir si se cancela

            group.enter()
            semaphore.wait()

            processingQueue.async { [weak self] in
                guard let self = self, !self.isCancelled else {
                    semaphore.signal()
                    group.leave()
                    return
                }

                let destino = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(url.lastPathComponent)
                do {
                    let isSecurityScoped = url.startAccessingSecurityScopedResource()
                    defer { if isSecurityScoped { url.stopAccessingSecurityScopedResource() } }

                    guard FileManager.default.fileExists(atPath: url.path) else {
                        ErrorLogger.shared.log("Archivo no encontrado: \(url.path)", level: .error)
                        // Bloque de error también actualiza el progreso basado en processedCount
                        DispatchQueue.main.async {
                            processedCount += 1
                            let progress = totalTickets > 0 ? Double(processedCount) / Double(totalTickets) : 0.0 // MODIFICADO
                            progressHandler(progress)
                        }
                        semaphore.signal()
                        group.leave()
                        return
                    }

                    if FileManager.default.fileExists(atPath: destino.path) { try FileManager.default.removeItem(at: destino) }
                    try FileManager.default.copyItem(at: url, to: destino)
                    guard let originalImage = UIImage(contentsOfFile: destino.path) else {
                        ErrorLogger.shared.log("No se pudo cargar la imagen: \(destino.path)", level: .error)
                        // Bloque de error también actualiza el progreso basado en processedCount
                        DispatchQueue.main.async {
                            processedCount += 1
                            let progress = totalTickets > 0 ? Double(processedCount) / Double(totalTickets) : 0.0 // MODIFICADO
                            progressHandler(progress)
                        }
                        semaphore.signal()
                        group.leave()
                        return
                    }

                    // Procesamiento asíncrono sin bloqueo
                    self.analyzer.analizarTicket(filepath: destino.path, originalImage: originalImage) { ticket in
                        // Este bloque se ejecuta cuando analizarTicket completa (con o sin éxito para el ticket)
                        do {
                            if let ticket = ticket, FileManager.default.fileExists(atPath: ticket.filepath) {
                                // Solo añade a processedTickets y cuenta como successful si el análisis fue bueno
                                processedTickets.append(ticket)
                                successfulCount += 1
                                if let image = UIImage(contentsOfFile: ticket.filepath) {
                                    self.imageCache.setObject(image, forKey: ticket.uniqueCode as NSString)
                                    ErrorLogger.shared.log("Imagen de ticket almacenada en caché: \(ticket.uniqueCode)", level: .process)
                                }
                            }
                        }
                        // Actualiza el progreso general basado en cuántos tickets han sido "tocados"
                        DispatchQueue.main.async {
                            processedCount += 1
                            let progress = totalTickets > 0 ? Double(processedCount) / Double(totalTickets) : 0.0 // MODIFICADO
                            progressHandler(progress)
                        }
                        semaphore.signal()
                        group.leave()
                    }
                } catch {
                    ErrorLogger.shared.log("Error al procesar archivo \(url.path): \(error.localizedDescription)", level: .error, error: error)
                    DispatchQueue.main.async {
                        processedCount += 1
                        let progress = totalTickets > 0 ? Double(processedCount) / Double(totalTickets) : 0.0 // MODIFICADO
                        progressHandler(progress)
                    }
                    semaphore.signal()
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            if self.isCancelled {
                ErrorLogger.shared.log("Procesamiento de tickets cancelado. Tickets procesados exitosamente: \(successfulCount) de \(processedCount) intentos.", level: .action)
            } else {
                ErrorLogger.shared.log("Procesamiento de tickets completado. Tickets procesados exitosamente: \(successfulCount) de \(processedCount) intentos.", level: .action)
            }
            // La completion devuelve solo los tickets que fueron analizados con éxito
            completion(processedTickets)
        }

        // Retornar una función de cancelación
        return {
            self.isCancelled = true
            ErrorLogger.shared.log("Solicitud de cancelación de procesamiento recibida a las 11:55 PM AST, 27 de mayo de 2025", level: .action) // Fecha y hora del log original
        }
    }

    func clearCache(for ticketCode: String) {
        imageCache.removeObject(forKey: ticketCode as NSString)
        ErrorLogger.shared.log("Caché de imagen limpiada para ticket: \(ticketCode)", level: .process)
    }

    func clearAllCache() {
        imageCache.removeAllObjects()
        ErrorLogger.shared.log("Caché de imágenes completamente limpiada a las 11:55 PM AST, 27 de mayo de 2025", level: .action) // Fecha y hora del log original
    }

    func getCachedImage(for ticketCode: String) -> UIImage? {
        return imageCache.object(forKey: ticketCode as NSString)
    }
}
// MARK: - Models/TicketManager.swift

class TicketManager: NSObject, ObservableObject, UIDocumentPickerDelegate, FullScreenContentDelegate {
    @Published var ticketsEntrada: [Ticket] = []
    @Published var ticketsSalida: [Ticket] = []
    @Published var diasLaborables: [String] = []
    @Published var mostrarDiasLaborables = false
    @Published var mostrarListaTickets = false
    @Published var mostrarEntradaHoy = false
    @Published var mostrarSalidaHoy = false
    @Published var selectedDate: Date? = nil
    @Published var processingCompleted = false
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var notificationTime: Date
    @Published var alertFrequency: Int = 1
    // @Published var selectedLanguage: String // Esta línea se elimina
    @Published var backgroundGradientColors: [Color]
    @Published var entradaButtonColors: [Color]
    @Published var salidaButtonColors: [Color]
    @Published var diasLaborablesButtonColors: [Color]
    @Published var listaTicketsButtonColors: [Color]
    @Published var subirTicketButtonColors: [Color]
    @Published var totalTickets: Int = 0
    @Published var processedTickets: Int = 0
    @Published var showClearConfirmation = false
    private var interstitialAd: InterstitialAd?
    private var adDisplayCounter = 0
    private var calendarEvents: [Date: [Ticket]] = [:]
    private let processor: TicketProcessor
    var calendar: Calendar
    var locale: Locale
    private var cancelProcessing: (() -> Void)?

    override init() {
        self.processor = TicketProcessor()
        self.notificationTime = UserDefaults.standard.object(forKey: "notificationTime") as? Date ?? {
            var components = DateComponents()
            components.hour = 20 // 8:00 PM
            components.minute = 0
            return Calendar.current.date(from: components) ?? Date()
        }()
        self.alertFrequency = UserDefaults.standard.integer(forKey: "alertFrequency") > 0 ? UserDefaults.standard.integer(forKey: "alertFrequency") : 1
        self.locale = Locale(identifier: "es_DO") // Establece el idioma predeterminado a español (República Dominicana)
        var calendar = Calendar.current
        calendar.locale = self.locale
        calendar.timeZone = TimeZone.current
        self.calendar = calendar
        // self.selectedLanguage = language // Esta línea se elimina

        // Colores (sin cambios aquí)
        self.backgroundGradientColors = (UserDefaults.standard.array(forKey: "backgroundGradientColors") as? [String])?.map { Color(hex: $0) } ?? [Color(hex: "#FF9500"), Color(hex: "#FF6200"), Color(hex: "#FFAD35")]
        self.entradaButtonColors = (UserDefaults.standard.array(forKey: "entradaButtonColors") as? [String])?.map { Color(hex: $0) } ?? [Color(hex: "#00CC00"), Color(hex: "#006600")]
        self.salidaButtonColors = (UserDefaults.standard.array(forKey: "salidaButtonColors") as? [String])?.map { Color(hex: $0) } ?? [Color(hex: "#1E3A8A"), Color(hex: "#3B82F6")]
        self.diasLaborablesButtonColors = (UserDefaults.standard.array(forKey: "diasLaborablesButtonColors") as? [String])?.map { Color(hex: $0) } ?? [Color(hex: "#6F6F6F"), Color(hex: "#484848")]
        self.listaTicketsButtonColors = (UserDefaults.standard.array(forKey: "listaTicketsButtonColors") as? [String])?.map { Color(hex: $0) } ?? [Color(hex: "#F80000"), Color(hex: "#950000")]
        self.subirTicketButtonColors = (UserDefaults.standard.array(forKey: "subirTicketButtonColors") as? [String])?.map { Color(hex: $0) } ?? [Color(hex: "#52A49A"), Color(hex: "#3C876A")]

        super.init()
        let (entrada, salida) = TicketStorage.cargarTickets()
        self.ticketsEntrada = entrada
        self.ticketsSalida = salida
        self.cargarConfiguracion()
        self.updateCalendar()
        self.loadInterstitialAd()

        ErrorLogger.shared.log("Tickets cargados al iniciar - Entrada: \(self.ticketsEntrada.count), Salida: \(self.ticketsSalida.count) a las \(Date().formattedString(locale: self.locale))", level: .action)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appDidEnterBackground() {
        actualizarAlmacenamiento()
        ErrorLogger.shared.log("App entró en segundo plano, tickets guardados a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    @objc private func appWillTerminate() {
        actualizarAlmacenamiento()
        ErrorLogger.shared.log("App terminada, tickets guardados a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    private func cargarConfiguracion() {
        if let dias = UserDefaults.standard.array(forKey: "diasLaborables") as? [String] {
            self.diasLaborables = dias
        }
        if let backgroundColors = UserDefaults.standard.array(forKey: "backgroundGradientColors") as? [String] {
            self.backgroundGradientColors = backgroundColors.map { Color(hex: $0) }
        }
        // No se carga selectedLanguage
    }

    func getCalendarEvents() -> [Date: [Ticket]] {
        return self.calendarEvents
    }

    func saveWorkdays(_ workdays: [String]) {
        self.diasLaborables = workdays
        UserDefaults.standard.set(workdays, forKey: "diasLaborables")
        self.scheduleMissingTicketNotifications()
        self.objectWillChange.send()
        ErrorLogger.shared.log("Días de clase guardados: \(workdays.joined(separator: ", ")) a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    func saveNotificationTime(_ time: Date) {
        self.notificationTime = time
        UserDefaults.standard.set(time, forKey: "notificationTime")
        self.scheduleMissingTicketNotifications()
        self.objectWillChange.send()
        ErrorLogger.shared.log("Hora de notificación guardada: \(time.formattedString(locale: self.locale)) a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    func saveAlertFrequency(_ frequency: Int) {
        self.alertFrequency = max(1, min(5, frequency))
        UserDefaults.standard.set(self.alertFrequency, forKey: "alertFrequency")
        self.scheduleMissingTicketNotifications()
        self.objectWillChange.send()
        ErrorLogger.shared.log("Frecuencia de alertas guardada: \(self.alertFrequency) a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    // Se elimina la función saveLanguage()
    /*
    func saveLanguage(_ language: String) {
        self.selectedLanguage = language
        UserDefaults.standard.set(language, forKey: "selectedLanguage")
        self.locale = Locale(identifier: language)
        var updatedCalendar = Calendar.current
        updatedCalendar.locale = self.locale
        self.calendar = updatedCalendar
        self.objectWillChange.send()
        ErrorLogger.shared.log("Idioma cambiado a: \(language) a las \(Date().formattedString(locale: self.locale))", level: .action)
    }
    */

    func saveBackgroundGradientColors(_ colors: [Color]) {
        self.backgroundGradientColors = colors
        let hexColors = colors.map { $0.toHex() }
        UserDefaults.standard.set(hexColors, forKey: "backgroundGradientColors")
        self.objectWillChange.send()
        ErrorLogger.shared.log("Colores de fondo guardados a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    func saveEntradaButtonColors(_ colors: [Color]) {
        self.entradaButtonColors = colors
        let hexColors = colors.map { $0.toHex() }
        UserDefaults.standard.set(hexColors, forKey: "entradaButtonColors")
        self.objectWillChange.send()
        ErrorLogger.shared.log("Colores de botón Entrada guardados a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    func saveSalidaButtonColors(_ colors: [Color]) {
        self.salidaButtonColors = colors
        let hexColors = colors.map { $0.toHex() }
        UserDefaults.standard.set(hexColors, forKey: "salidaButtonColors")
        self.objectWillChange.send()
        ErrorLogger.shared.log("Colores de botón Salida guardados a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    func saveDiasLaborablesButtonColors(_ colors: [Color]) {
        self.diasLaborablesButtonColors = colors
        let hexColors = colors.map { $0.toHex() }
        UserDefaults.standard.set(hexColors, forKey: "diasLaborablesButtonColors")
        self.objectWillChange.send()
        ErrorLogger.shared.log("Colores de botón Días de Clase guardados a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    func saveListaTicketsButtonColors(_ colors: [Color]) {
        self.listaTicketsButtonColors = colors
        let hexColors = colors.map { $0.toHex() }
        UserDefaults.standard.set(hexColors, forKey: "listaTicketsButtonColors")
        self.objectWillChange.send()
        ErrorLogger.shared.log("Colores de botón Lista de Tickets guardados a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    func saveSubirTicketButtonColors(_ colors: [Color]) {
        self.subirTicketButtonColors = colors
        let hexColors = colors.map { $0.toHex() }
        UserDefaults.standard.set(hexColors, forKey: "subirTicketButtonColors")
        self.objectWillChange.send()
        ErrorLogger.shared.log("Colores de botón Subir Ticket guardados a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    func procesarArchivos(urls: [URL], completionHandler: @escaping ([Ticket]) -> Void = { _ in }) {
        guard !self.isProcessing else {
            print("Procesamiento ya en curso, ignorando nueva solicitud.")
            return
        }

        DispatchQueue.main.async {
            self.isProcessing = true
            self.processingProgress = 0.0
            self.totalTickets = urls.count
            self.processedTickets = 0
        }

        let cancel = self.processor.processTickets(urls: urls, progressHandler: { [weak self] progress in
            DispatchQueue.main.async {
                self?.processingProgress = progress
                self?.processedTickets = Int(progress * Double(self?.totalTickets ?? 0))
            }
        }) { [weak self] newTickets in
            guard let self = self else { return }
            var addedCount = 0
            for ticket in newTickets {
                if self.agregarTicket(ticket) {
                    addedCount += 1
                }
            }

            if addedCount == 0 && !urls.isEmpty {
                print("No se pudo procesar ningún ticket. Revisa los archivos.")
            }

            self.actualizarAlmacenamiento()
            self.updateCalendar()
            DispatchQueue.main.async {
                self.isProcessing = false
                self.processingProgress = 1.0
                self.cancelProcessing = nil
                self.processingCompleted = true
                self.adDisplayCounter += 1
                self.showInterstitialAd()
                _ = self.getTicketsEntradaForToday()
                _ = self.getTicketsSalidaForToday()
                self.objectWillChange.send()
                completionHandler(newTickets)
            }
        }

        self.cancelProcessing = cancel
    }

    func cancelProcessingAction() {
        cancelProcessing?()
        DispatchQueue.main.async {
            self.isProcessing = false
            self.processingProgress = 0.0
            self.processedTickets = 0
            self.cancelProcessing = nil
        }
        ErrorLogger.shared.log("Procesamiento cancelado por el usuario a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    func confirmClearAllData() {
        self.showClearConfirmation = true
    }

    func clearAllData() {
        if showClearConfirmation {
            self.ticketsEntrada.removeAll()
            self.ticketsSalida.removeAll()
            self.calendarEvents.removeAll()
            self.selectedDate = nil
            self.processor.clearAllCache()
            self.actualizarAlmacenamiento()
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                for fileURL in fileURLs {
                    try FileManager.default.removeItem(at: fileURL)
                }
                ErrorLogger.shared.log("Todos los tickets y archivos relacionados han sido borrados a las \(Date().formattedString(locale: self.locale))", level: .action)
            } catch {
                ErrorLogger.shared.log("Error al borrar archivos: \(error.localizedDescription) a las \(Date().formattedString(locale: self.locale))", level: .error, error: error)
            }
            self.objectWillChange.send()
            self.updateCalendar()
            self.showClearConfirmation = false
        }
    }

    func obtenerTicketsDia(_ date: Date) -> [Ticket] {
        let startOfDay = self.calendar.startOfDay(for: date)
        return self.calendarEvents[startOfDay] ?? []
    }

    func getTicketsEntradaForToday() -> [Ticket] {
        let today = Date()
        let startOfDay = self.calendar.startOfDay(for: today)
        let tickets = self.ticketsEntrada.filter { self.calendar.isDate($0.fecha, inSameDayAs: startOfDay) }
        mostrarEntradaHoy = !tickets.isEmpty
        objectWillChange.send()
        ErrorLogger.shared.log("Tickets de entrada para hoy (\(today.formattedString(locale: self.locale))): \(tickets.count) a las \(Date().formattedString(locale: self.locale))", level: .action)
        return tickets
    }

    func getTicketsSalidaForToday() -> [Ticket] {
        let today = Date()
        let startOfDay = self.calendar.startOfDay(for: today)
        let tickets = self.ticketsSalida.filter { self.calendar.isDate($0.fecha, inSameDayAs: startOfDay) }
        mostrarSalidaHoy = !tickets.isEmpty
        objectWillChange.send()
        ErrorLogger.shared.log("Tickets de salida para hoy (\(today.formattedString(locale: self.locale))): \(tickets.count) a las \(Date().formattedString(locale: self.locale))", level: .action)
        return tickets
    }

    func obtenerTicketsFiltrados(_ filtro: String) -> [Ticket] {
        switch filtro {
        case "Todos":
            return (ticketsEntrada + ticketsSalida).sorted { $0.fecha > $1.fecha }
        case "Entrada":
            return ticketsEntrada.sorted { $0.fecha > $1.fecha }
        case "Salida":
            return ticketsSalida.sorted { $0.fecha > $1.fecha }
        default:
            return []
        }
    }

    public func requestNotificationPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    ErrorLogger.shared.log("Permiso de notificaciones concedido a las \(Date().formattedString(locale: self.locale))", level: .action)
                    self.scheduleMissingTicketNotifications()
                } else if let error = error {
                    ErrorLogger.shared.log("Error al solicitar permisos de notificaciones: \(error.localizedDescription) a las \(Date().formattedString(locale: self.locale))", level: .error, error: error)
                } else {
                    ErrorLogger.shared.log("Permiso de notificaciones denegado a las \(Date().formattedString(locale: self.locale))", level: .error)
                }
                completion?(granted)
            }
        }
    }

    func scheduleMissingTicketNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let calendar = self.calendar
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = self.locale
        formatter.dateFormat = "EEEE"

        ErrorLogger.shared.log("Iniciando programación de notificaciones. Hora actual: \(now.formattedString(locale: self.locale)) a las \(Date().formattedString(locale: self.locale))", level: .process)

        for dayOffset in 1...7 {
            guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let startOfDay = calendar.startOfDay(for: futureDate)

            let dayName = formatter.string(from: futureDate).lowercased()
            ErrorLogger.shared.log("Verificando día: \(futureDate.formattedString(locale: self.locale)), día de la semana: \(dayName) a las \(Date().formattedString(locale: self.locale))", level: .process)

            if self.diasLaborables.contains(dayName) {
                let ticketsForDay = self.calendarEvents[startOfDay] ?? []
                let hasEntrada = ticketsForDay.contains { $0.tipo == "entrada" }
                let hasSalida = ticketsForDay.contains { $0.tipo == "salida" }
                ErrorLogger.shared.log("Tickets para \(futureDate.formattedString(locale: self.locale)): Entrada=\(hasEntrada), Salida=\(hasSalida) a las \(Date().formattedString(locale: self.locale))", level: .process)

                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: futureDate),
                      let notificationDate = calendar.date(bySettingHour: calendar.component(.hour, from: self.notificationTime),
                                                           minute: calendar.component(.minute, from: self.notificationTime),
                                                           second: 0,
                                                           of: previousDay) else {
                    ErrorLogger.shared.log("Error al calcular la fecha de notificación para \(futureDate.formattedString(locale: self.locale)) a las \(Date().formattedString(locale: self.locale))", level: .error)
                    continue
                }

                ErrorLogger.shared.log("Fecha de notificación para \(futureDate.formattedString(locale: self.locale)): \(notificationDate.formattedString(locale: self.locale)) a las \(Date().formattedString(locale: self.locale))", level: .process)

                if notificationDate > now {
                    for i in 0..<self.alertFrequency {
                        let adjustedNotificationDate = calendar.date(byAdding: .hour, value: i * -6, to: notificationDate) ?? notificationDate
                        ErrorLogger.shared.log("Programando notificación para \(futureDate.formattedString(locale: self.locale)) a las \(adjustedNotificationDate.formattedString(locale: self.locale)) a las \(Date().formattedString(locale: self.locale))", level: .process)

                        if !hasEntrada {
                            let content = UNMutableNotificationContent()
                            content.title = "Falta Ticket de Entrada" // Texto estático en español
                            content.body = "Falta un ticket de entrada para el \(futureDate.formattedString(locale: self.locale))." // Texto estático en español
                            content.sound = .default
                            content.userInfo = ["missingType": "entrada", "date": futureDate.timeIntervalSince1970]

                            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: adjustedNotificationDate)
                            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                            let request = UNNotificationRequest(identifier: "missingEntrada_\(futureDate.timeIntervalSince1970)_\(i)", content: content, trigger: trigger)

                            UNUserNotificationCenter.current().add(request) { error in
                                if let error = error {
                                    ErrorLogger.shared.log("Error al programar notificación de entrada faltante para \(futureDate.formattedString(locale: self.locale)): \(error.localizedDescription) a las \(Date().formattedString(locale: self.locale))", level: .error)
                                } else {
                                    ErrorLogger.shared.log("Notificación de entrada faltante programada para \(futureDate.formattedString(locale: self.locale)) a las \(adjustedNotificationDate.formattedString(locale: self.locale)) a las \(Date().formattedString(locale: self.locale))", level: .process)
                                }
                            }
                        }

                        if !hasSalida {
                            let content = UNMutableNotificationContent()
                            content.title = "Falta Ticket de Salida" // Texto estático en español
                            content.body = "Falta un ticket de salida para el \(futureDate.formattedString(locale: self.locale))." // Texto estático en español
                            content.sound = .default
                            content.userInfo = ["missingType": "salida", "date": futureDate.timeIntervalSince1970]

                            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: adjustedNotificationDate)
                            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                            let request = UNNotificationRequest(identifier: "missingSalida_\(futureDate.timeIntervalSince1970)_\(i)", content: content, trigger: trigger)

                            UNUserNotificationCenter.current().add(request) { error in
                                if let error = error {
                                    ErrorLogger.shared.log("Error al programar notificación de salida faltante para \(futureDate.formattedString(locale: self.locale)): \(error.localizedDescription) a las \(Date().formattedString(locale: self.locale))", level: .error)
                                } else {
                                    ErrorLogger.shared.log("Notificación de salida faltante programada para \(futureDate.formattedString(locale: self.locale)) a las \(adjustedNotificationDate.formattedString(locale: self.locale)) a las \(Date().formattedString(locale: self.locale))", level: .process)
                                }
                            }
                        }
                    }
                } else {
                    ErrorLogger.shared.log("No se programó notificación para \(futureDate.formattedString(locale: self.locale)) porque la fecha de notificación (\(notificationDate.formattedString(locale: self.locale))) ya pasó a las \(Date().formattedString(locale: self.locale))", level: .process)
                }
            } else {
                ErrorLogger.shared.log("El día \(futureDate.formattedString(locale: self.locale)) (\(dayName)) no es un día de clase a las \(Date().formattedString(locale: self.locale))", level: .process)
            }
        }
    }

    @discardableResult
    func agregarTicket(_ ticket: Ticket) -> Bool {
        let existingTickets = self.ticketsEntrada + self.ticketsSalida
        if existingTickets.contains(where: { $0.uniqueCode == ticket.uniqueCode || $0.filepath == ticket.filepath }) {
            ErrorLogger.shared.log("Ticket duplicado detectado: \(ticket.uniqueCode) a las \(Date().formattedString(locale: self.locale))", level: .error)
            return false
        }

        if ticket.tipo == "entrada" {
            self.ticketsEntrada.append(ticket)
        } else if ticket.tipo == "salida" {
            self.ticketsSalida.append(ticket)
        } else {
            return false
        }

        ErrorLogger.shared.log("Ticket agregado: \(ticket.uniqueCode) (\(ticket.tipo)) a las \(Date().formattedString(locale: self.locale))", level: .action)
        self.actualizarAlmacenamiento()
        self.updateCalendar()
        if self.calendar.isDateInToday(ticket.fecha) {
            _ = self.getTicketsEntradaForToday()
            _ = self.getTicketsSalidaForToday()
        }
        self.objectWillChange.send()
        return true
    }

    private func actualizarAlmacenamiento() {
        TicketStorage.guardarTickets(entrada: self.ticketsEntrada, salida: self.ticketsSalida)
        ErrorLogger.shared.log("Almacenamiento actualizado - Entrada: \(ticketsEntrada.count), Salida: \(ticketsSalida.count) a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    func updateCalendar() {
        let oldEvents = self.calendarEvents
        self.calendarEvents.removeAll()
        for ticket in self.ticketsEntrada + self.ticketsSalida {
            let startOfDay = self.calendar.startOfDay(for: ticket.fecha)
            self.calendarEvents[startOfDay, default: []].append(ticket)
        }
        if oldEvents != self.calendarEvents {
            self.scheduleMissingTicketNotifications()
            self.objectWillChange.send()
            ErrorLogger.shared.log("Calendario actualizado con eventos a las \(Date().formattedString(locale: self.locale))", level: .action)
        }
    }

    func loadInterstitialAd() {

        }


    func showInterstitialAd() {

        }


    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.procesarArchivos(urls: urls)
        controller.dismiss(animated: true, completion: nil)
        ErrorLogger.shared.log("Documentos seleccionados para procesar a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true, completion: nil)
        ErrorLogger.shared.log("Selección de documentos cancelada a las \(Date().formattedString(locale: self.locale))", level: .action)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {

    }
}


// MARK: - Views/GradientButton.swift
struct GradientButton: View {
    let title: String
    let systemImage: String?
    let colors: [Color]
    let action: () -> Void
    let isPrimary: Bool

    @State private var isTapped = false
    @State private var glowIntensity: CGFloat = 0.0

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isTapped = true
                glowIntensity = 1.0
            }
            action()
        }) {
            if #available(iOS 17.0, *) {
                HStack(spacing: 10) {
                    if let systemImage = systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: isPrimary ? 22 : 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Text(title)
                        .font(.system(size: isPrimary ? 18 : 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, isPrimary ? 18 : 12)
                .padding(.horizontal, isPrimary ? 28 : 20)
                .frame(maxWidth: isPrimary ? .infinity : nil)
                .background(
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: colors), startPoint: .leading, endPoint: .trailing)
                        Color.white.opacity(isTapped ? 0.15 : 0)
                    }
                    .clipShape(Capsule())
                    .shadow(color: Color(colors.first ?? .white).opacity(glowIntensity), radius: isPrimary ? 10 : 5, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 3, y: 3)
                    .shadow(color: .white.opacity(0.3), radius: 5, x: -3, y: -3)
                )
            } else {
                // Fallback for iOS < 17.0
                HStack(spacing: 10) {
                    if let systemImage = systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: isPrimary ? 22 : 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Text(title)
                        .font(.system(size: isPrimary ? 18 : 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, isPrimary ? 18 : 12)
                .padding(.horizontal, isPrimary ? 28 : 20)
                .frame(maxWidth: isPrimary ? .infinity : nil)
                .background(
                    LinearGradient(gradient: Gradient(colors: colors), startPoint: .leading, endPoint: .trailing)
                        .clipShape(Capsule())
                        .shadow(radius: isPrimary ? 5 : 3)
                )
            }
        }
        .scaleEffect(isTapped ? 0.92 : 1.0)
        .frame(height: isPrimary ? 65 : 50)
        .onChange(of: isTapped) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring()) {
                    isTapped = false
                    glowIntensity = 0.0
                }
            }
        }
    }
}
// MARK: - Views/CircularProgressView.swift
struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 10)
                .foregroundColor(.gray.opacity(0.2))
                .frame(width: 60, height: 60)

            Circle()
                .trim(from: 0.0, to: min(progress, 1.0))
                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                .foregroundColor(.blue)
                .rotationEffect(Angle(degrees: -90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            Text(String(format: "%.0f%%", min(progress, 1.0) * 100))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 60, height: 60)
        .padding()
        .background(.black.opacity(0.1))
        .clipShape(Circle())
        .shadow(radius: 5)
    }
}

// MARK: - Views/TicketCard.swift
struct TicketCard: View {
    let ticket: Ticket
    let locale: Locale
    @State private var showingDetails = false

    var body: some View {
        Button(action: {
            showingDetails = true
        }) {
            HStack(alignment: .center, spacing: 15) {
                if let imageData = ticket.imageData, let image = UIImage(data: imageData), let resizedImage = image.resized(to: CGSize(width: 60, height: 60)) {
                    Image(uiImage: resizedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.gray.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    Image(systemName: "ticket.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                        .padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(ticket.tipo.capitalized) Ticket")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Código: \(ticket.uniqueCode)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Fecha: \(ticket.fecha.formattedString(locale: locale))")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .sheet(isPresented: $showingDetails) {
            TicketDetailView(ticket: ticket, locale: locale)
                .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
        }
    }
}
// MARK: - Views/TicketDetailView.swift
struct TicketDetailView: View {
    let ticket: Ticket
    let locale: Locale

    var body: some View {
        VStack(spacing: 20) {
            if let imageData = ticket.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 500) // Imagen agrandada
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .padding(.horizontal)
                    .shadow(radius: 5)
            } else {
                Image(systemName: "ticket.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120) // Ícono agrandado
                    .foregroundColor(.gray)
                    .padding()
                    .background(.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("\(ticket.tipo.capitalized) Ticket")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                Divider()
                HStack {
                    Text("Código:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(ticket.uniqueCode)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                HStack {
                    Text("Fecha:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(ticket.fecha.formattedString(locale: locale))
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                HStack {
                    Text("Archivo:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(URL(fileURLWithPath: ticket.filepath).lastPathComponent)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
        .navigationTitle("Detalles del Ticket")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(.red)
            }
        }
        .environment(\.locale, locale)
    }

    @Environment(\.presentationMode) private var presentationMode
}

// MARK: - Views/CalendarViews.swift
class TicomCalendarView: UIViewController, FSCalendarDataSource, FSCalendarDelegate {
    @ObservedObject var ticketManager: TicketManager
    private var calendar: FSCalendar!

    init(ticketManager: TicketManager) {
        self.ticketManager = ticketManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCalendar()
    }

    private func setupCalendar() {
        calendar = FSCalendar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 40, height: 300))
        calendar.dataSource = self
        calendar.delegate = self
        calendar.appearance.titleFont = .systemFont(ofSize: 16, weight: .medium)
        calendar.appearance.headerTitleFont = .systemFont(ofSize: 18, weight: .bold)
        calendar.appearance.weekdayFont = .systemFont(ofSize: 14, weight: .medium)
        calendar.appearance.titleDefaultColor = .white
        calendar.appearance.titleWeekendColor = UIColor.white.withAlphaComponent(0.8)
        calendar.appearance.headerTitleColor = .white
        calendar.appearance.weekdayTextColor = .white
        calendar.appearance.selectionColor = UIColor(hex: ticketManager.entradaButtonColors[0].toHex())
        calendar.appearance.todayColor = .systemBlue
        calendar.appearance.todaySelectionColor = UIColor.systemBlue.withAlphaComponent(0.7)
        calendar.appearance.eventDefaultColor = UIColor(hex: "#00CC00") // Green dots
        calendar.appearance.eventSelectionColor = UIColor(hex: "#00CC00") // Green dots
        calendar.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        calendar.layer.cornerRadius = 15
        calendar.layer.shadowColor = UIColor.black.cgColor
        calendar.layer.shadowOpacity = 0.1
        calendar.layer.shadowRadius = 5
        calendar.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.addSubview(calendar)
    }

    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        let startOfDay = ticketManager.calendar.startOfDay(for: date)
        return ticketManager.getCalendarEvents()[startOfDay]?.count ?? 0
    }

    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        let startOfDay = ticketManager.calendar.startOfDay(for: date)
        if ticketManager.selectedDate != nil && ticketManager.calendar.isDate(date, inSameDayAs: ticketManager.selectedDate!) {
            ticketManager.selectedDate = nil
        } else if ticketManager.getCalendarEvents()[startOfDay]?.isEmpty ?? true {
            ticketManager.selectedDate = nil
        } else {
            ticketManager.selectedDate = date
        }
        ErrorLogger.shared.log("Fecha seleccionada en calendario: \(date.formattedString(locale: ticketManager.locale))", level: .action)
    }

    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventDefaultColorsFor date: Date) -> [UIColor]? {
        let startOfDay = ticketManager.calendar.startOfDay(for: date)
        let tickets = ticketManager.getCalendarEvents()[startOfDay] ?? []
        return tickets.map { ticket in
            ticket.tipo == "entrada" ? UIColor(hex: ticketManager.entradaButtonColors[0].toHex()) : UIColor(hex: ticketManager.salidaButtonColors[0].toHex())
        }
    }
}

struct TicomCalendarViewRepresentable: UIViewControllerRepresentable {
    @ObservedObject var ticketManager: TicketManager

    func makeUIViewController(context: Context) -> TicomCalendarView {
        TicomCalendarView(ticketManager: ticketManager)
    }

    func updateUIViewController(_ uiViewController: TicomCalendarView, context: Context) {}
}
    // MARK: - Views/CalendarDetailsView.swift
    struct CalendarDetailsView: View {
        @ObservedObject var ticketManager: TicketManager

        var body: some View {
            VStack(alignment: .leading, spacing: 15) {
                if let date = ticketManager.selectedDate {
                    Text("Tickets del \(date.formattedString(locale: ticketManager.locale)):") // Texto estático en español
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(ticketManager.obtenerTicketsDia(date)) { ticket in
                                TicketCard(ticket: ticket, locale: ticketManager.locale)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .frame(height: 150)
                    .background(.white.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(radius: 5)
                }
            }
            .padding(.vertical)
            .opacity(ticketManager.selectedDate != nil ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: ticketManager.selectedDate)
        }
    }

// MARK: - Views/ColorCustomizationView.swift

struct ColorCustomizationView: View {
    @ObservedObject var ticketManager: TicketManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingColorPicker = false
    @State private var selectedColorType = ""
    @State private var tempColors: [Color] = []

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Fondo").font(.system(size: 16, weight: .semibold))) {
                    Button(action: {
                        tempColors = ticketManager.backgroundGradientColors
                        selectedColorType = "backgroundGradientColors"
                        showingColorPicker = true
                    }) {
                        HStack {
                            Text("Colores de Fondo")
                            Spacer()
                            GradientPreview(colors: ticketManager.backgroundGradientColors)
                                .frame(width: 50, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
                Section(header: Text("Botones").font(.system(size: 16, weight: .semibold))) {
                    Button(action: {
                        tempColors = ticketManager.entradaButtonColors
                        selectedColorType = "entradaButtonColors"
                        showingColorPicker = true
                    }) {
                        HStack {
                            Text("Botón Entrada")
                            Spacer()
                            GradientPreview(colors: ticketManager.entradaButtonColors)
                                .frame(width: 50, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                    Button(action: {
                        tempColors = ticketManager.salidaButtonColors
                        selectedColorType = "salidaButtonColors"
                        showingColorPicker = true
                    }) {
                        HStack {
                            Text("Botón Salida")
                            Spacer()
                            GradientPreview(colors: ticketManager.salidaButtonColors)
                                .frame(width: 50, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                    Button(action: {
                        tempColors = ticketManager.diasLaborablesButtonColors
                        selectedColorType = "diasLaborablesButtonColors"
                        showingColorPicker = true
                    }) {
                        HStack {
                            Text("Botón Días de Clase")
                            Spacer()
                            GradientPreview(colors: ticketManager.diasLaborablesButtonColors)
                                .frame(width: 50, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                    Button(action: {
                        tempColors = ticketManager.listaTicketsButtonColors
                        selectedColorType = "listaTicketsButtonColors"
                        showingColorPicker = true
                    }) {
                        HStack {
                            Text("Botón Lista de Tickets")
                            Spacer()
                            GradientPreview(colors: ticketManager.listaTicketsButtonColors)
                                .frame(width: 50, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                    Button(action: {
                        tempColors = ticketManager.subirTicketButtonColors
                        selectedColorType = "subirTicketButtonColors"
                        showingColorPicker = true
                    }) {
                        HStack {
                            Text("Botón Subir Ticket")
                            Spacer()
                            GradientPreview(colors: ticketManager.subirTicketButtonColors)
                                .frame(width: 50, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
            }
            .navigationTitle("Personalizar Colores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.red)
                }
            }
            .sheet(isPresented: $showingColorPicker) {
                ColorPickerView(
                    ticketManager: ticketManager,
                    selectedColorType: $selectedColorType,
                    tempColors: $tempColors,
                    showingColorPicker: $showingColorPicker
                )
                .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
            }
        }
    }
}

struct GradientPreview: View {
    let colors: [Color]

    var body: some View {
        LinearGradient(gradient: Gradient(colors: colors), startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Views/ColorPickerView.swift
struct ColorPickerView: View {
    @ObservedObject var ticketManager: TicketManager
    @Binding var selectedColorType: String
    @Binding var tempColors: [Color]
    @Binding var showingColorPicker: Bool
    @State private var selectedIndex = 0

    var body: some View {
        VStack(spacing: 20) {
            GradientPreview(colors: tempColors)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .shadow(radius: 3)

            Picker("Seleccionar Color", selection: $selectedIndex) {
                ForEach(0..<tempColors.count, id: \.self) { index in
                    Text("Color \(index + 1)").tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            ColorPicker("Elegir Color", selection: Binding(
                get: { tempColors[selectedIndex] },
                set: { tempColors[selectedIndex] = $0 }
            ))
            .padding(.horizontal)

            HStack(spacing: 10) {
                Button("Agregar Color") {
                    tempColors.append(.white)
                    selectedIndex = tempColors.count - 1
                }
                .foregroundColor(.blue)

                if tempColors.count > 1 {
                    Button("Eliminar Color") {
                        tempColors.remove(at: selectedIndex)
                        selectedIndex = min(selectedIndex, tempColors.count - 1)
                    }
                    .foregroundColor(.red)
                }
            } // Properly closed HStack

            GradientButton(
                title: "Guardar Cambios",
                systemImage: "checkmark",
                colors: [.blue, .purple],
                action: {
                    switch selectedColorType {
                    case "backgroundGradientColors":
                        ticketManager.saveBackgroundGradientColors(tempColors)
                    case "entradaButtonColors":
                        ticketManager.saveEntradaButtonColors(tempColors)
                    case "salidaButtonColors":
                        ticketManager.saveSalidaButtonColors(tempColors)
                    case "diasLaborablesButtonColors":
                        ticketManager.saveDiasLaborablesButtonColors(tempColors)
                    case "listaTicketsButtonColors":
                        ticketManager.saveListaTicketsButtonColors(tempColors)
                    case "subirTicketButtonColors":
                        ticketManager.saveSubirTicketButtonColors(tempColors)
                    default:
                        break
                    }
                    showingColorPicker = false
                },
                isPrimary: false
            )
            .padding(.horizontal)
            .padding(.bottom)

            GradientButton(
                title: "Cancelar",
                systemImage: "xmark",
                colors: [.red, .pink],
                action: {
                    showingColorPicker = false
                },
                isPrimary: false
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
        .shadow(radius: 10)
    }
}

// MARK: - Views/VisualEffectView.swift
struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect?

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

    // MARK: - Views/SettingsView.swift

    struct SettingsView: View {
        @ObservedObject var ticketManager: TicketManager
        @Environment(\.dismiss) var dismiss
        @State private var notificationTime: Date
        @State private var alertFrequency: Double
        // @State private var selectedLanguage: String // Esta línea se elimina
        @State private var showingColorCustomization = false
        @State private var isTestNotificationPressed = false

        init(ticketManager: TicketManager) {
            self.ticketManager = ticketManager
            self._notificationTime = State(initialValue: ticketManager.notificationTime)
            self._alertFrequency = State(initialValue: Double(ticketManager.alertFrequency))
            // self._selectedLanguage = State(initialValue: ticketManager.selectedLanguage) // Esta línea se elimina
        }

        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("Notificaciones")) {
                        DatePicker(
                            "Hora de Notificación", // Texto estático en español
                            selection: $notificationTime,
                            displayedComponents: .hourAndMinute
                        )
                        .environment(\.locale, ticketManager.locale)

                        Stepper(
                            "Frecuencia de Alertas: \(Int(alertFrequency))", // Texto estático en español
                            value: $alertFrequency,
                            in: 1...5
                        )

                        GradientButton(
                            title: isTestNotificationPressed ? "Notificación de Prueba (Procesando...)" : "Notificación de Prueba",
                            systemImage: "bell.fill",
                            colors: isTestNotificationPressed ? [Color(hex: "#FFD700"), Color(hex: "#FFA500")] : [Color(hex: "#6D8299"), Color(hex: "#A3BFFA")],
                            action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                isTestNotificationPressed = true
                                scheduleTestNotification()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    withAnimation(.easeInOut) {
                                        isTestNotificationPressed = false
                                    }
                                }
                            },
                            isPrimary: false
                        )
                        .frame(height: 40)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                        Text("Notificación de Prueba: Este botón permite verificar que el sistema de notificaciones funcione correctamente. Al presionarlo, se programa una notificación de prueba que aparecerá después de 1 minuto si sales de la aplicación. Cuando presiones el botón debes de salir de la aplicación y esperar 1 minuto.") // Texto estático en español
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 2)
                    }

                    // Sección de idioma eliminada
                    /*
                    Section(header: Text("Idioma")) {
                        Picker(
                            ticketManager.locale.identifier == "es_DO" ? "Idioma" : "Language",
                            selection: $selectedLanguage
                        ) {
                            Text("Español (DO)").tag("es_DO")
                            Text("English (US)").tag("en_US")
                        }
                        .pickerStyle(.segmented)
                    }
                    */

                    Section(header: Text("Apariencia")) {
                        Button(action: {
                            showingColorCustomization = true
                        }) {
                            Text("Personalización de Colores") // Texto estático en español
                        }
                    }
                }
                .navigationTitle("Ajustes") // Título estático en español
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { // Texto estático en español
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") { // Texto estático en español
                            ticketManager.saveNotificationTime(notificationTime)
                            ticketManager.saveAlertFrequency(Int(alertFrequency))
                            // ticketManager.saveLanguage(selectedLanguage) // Esta línea se elimina
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showingColorCustomization) {
                    ColorCustomizationView(ticketManager: ticketManager)
                        .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
                }
            }
            .environment(\.locale, ticketManager.locale)
        }

        private func scheduleTestNotification() {
            let content = UNMutableNotificationContent()
            content.title = "Notificación de Prueba"
            content.body = "Esta es una prueba para verificar el sistema de notificaciones."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
            let request = UNNotificationRequest(identifier: "testNotification_\(UUID().uuidString)", content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error al programar notificación de prueba: \(error.localizedDescription)")
                }
            }
        }
    }

// MARK: - Views/DocumentPickerView.swift
struct DocumentPickerView: UIViewControllerRepresentable {
    var onDocumentsPicked: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image])
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onDocumentsPicked(urls)
            controller.dismiss(animated: true, completion: nil)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            controller.dismiss(animated: true, completion: nil)
        }
    }
}

// MARK: - Banner Ad View
    struct BannerAdView: UIViewRepresentable {
        func makeUIView(context: Context) -> UIView {
            UIView() // Empty view to replace banner
        }

        func updateUIView(_ uiView: UIView, context: Context) {}
    }

// MARK: - Splash View
struct SplashView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var offset: CGFloat = -100

    var body: some View {
        ZStack {
            Color(hex: "#FF6200") // Solid orange, no transparency
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "ticket.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.white)
                    .scaleEffect(scale)
                    .offset(y: offset)

                Text("Ticom")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                scale = 1.0
                offset = 0
            }
            withAnimation(.easeIn(duration: 1.0).delay(0.5)) {
                opacity = 1.0
            }
        }
    }
}
//MARK: - Entry Exit View
struct EntryExitView: View {
    @ObservedObject var ticketManager: TicketManager

    var body: some View {
        Text("Entry/Exit View")
            .foregroundColor(.white)
    }
}

    // MARK: - Views/ActionButtonsView.swift

    struct ActionButtonsView: View {
        @ObservedObject var ticketManager: TicketManager
        @Binding var showingWorkdays: Bool
        @Binding var showingTicketList: Bool
        @Binding var showingDocumentPicker: Bool
        @State private var selectedEntradaTicket: Ticket?
        @State private var selectedSalidaTicket: Ticket?
        @State private var showingEntradaDetails = false
        @State private var showingSalidaDetails = false
        @State private var showingEntradaPicker = false
        @State private var showingSalidaPicker = false

        private func loadTicketsForToday() {
            let entradaTickets = ticketManager.getTicketsEntradaForToday()
            let salidaTickets = ticketManager.getTicketsSalidaForToday()
            selectedEntradaTicket = entradaTickets.first
            selectedSalidaTicket = salidaTickets.first
        }

        var body: some View {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    GradientButton(
                        title: "Entrada", // Texto estático en español
                        systemImage: "arrow.right.circle.fill",
                        colors: ticketManager.entradaButtonColors,
                        action: {
                            if selectedEntradaTicket != nil {
                                showingEntradaDetails = true
                            } else {
                                showingEntradaPicker = true
                            }
                        },
                        isPrimary: true
                    )

                    GradientButton(
                        title: "Salida", // Texto estático en español
                        systemImage: "arrow.left.circle.fill",
                        colors: ticketManager.salidaButtonColors,
                        action: {
                            if selectedSalidaTicket != nil {
                                showingSalidaDetails = true
                            } else {
                                showingSalidaPicker = true
                            }
                        },
                        isPrimary: true
                    )
                }

                HStack(spacing: 12) {
                    GradientButton(
                        title: "Días de Clase", // Texto estático en español
                        systemImage: "calendar",
                        colors: ticketManager.diasLaborablesButtonColors,
                        action: { showingWorkdays = true },
                        isPrimary: false
                    )

                    GradientButton(
                        title: "Lista de Tickets", // Texto estático en español
                        systemImage: "list.bullet.below.rectangle",
                        colors: ticketManager.listaTicketsButtonColors,
                        action: { showingTicketList = true },
                        isPrimary: false
                    )
                }

                GradientButton(
                    title: "Subir Ticket", // Texto estático en español
                    systemImage: "plus.circle.fill",
                    colors: ticketManager.subirTicketButtonColors,
                    action: { showingDocumentPicker = true },
                    isPrimary: false
                )
                .frame(maxWidth: 200)
                .padding(.top, 5)
            }
            .padding(.horizontal)
            .onAppear {
                loadTicketsForToday()
            }
            .onChange(of: ticketManager.ticketsEntrada) { _ in
                loadTicketsForToday()
            }
            .onChange(of: ticketManager.ticketsSalida) { _ in
                loadTicketsForToday()
            }
            .sheet(isPresented: $showingEntradaDetails) {
                if let ticket = selectedEntradaTicket {
                    TicketDetailView(ticket: ticket, locale: ticketManager.locale)
                        .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
                } else {
                    Text("No hay ticket de entrada para este día.") // Texto estático en español
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
                }
            }
            .sheet(isPresented: $showingSalidaDetails) {
                if let ticket = selectedSalidaTicket {
                    TicketDetailView(ticket: ticket, locale: ticketManager.locale)
                        .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
                } else {
                    Text("No hay ticket de salida para este día.") // Texto estático en español
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
                }
            }
            .sheet(isPresented: $showingEntradaPicker) {
                DocumentPickerView { urls in
                    ticketManager.procesarArchivos(urls: urls) { _ in
                        loadTicketsForToday()
                    }
                }
            }
            .sheet(isPresented: $showingSalidaPicker) {
                DocumentPickerView { urls in
                    ticketManager.procesarArchivos(urls: urls) { _ in
                        loadTicketsForToday()
                    }
                }
            }
        }
    }
// MARK: - ContentView.swift


struct ButtonFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Define the arrow points (triangle pointing up by default)
        path.move(to: CGPoint(x: width / 2, y: 0)) // Tip of the arrow
        path.addLine(to: CGPoint(x: 0, y: height)) // Bottom left
        path.addLine(to: CGPoint(x: width, y: height)) // Bottom right
        path.closeSubpath()
        
        return path
    }
}

    struct ContentView: View {
        @StateObject var ticketManager = TicketManager()
        @State private var showingDocumentPicker = false
        @State private var showingWorkdays = false
        @State private var showingTicketList = false
        @State private var showingSettings = false
        @State private var showingClearDataAlert = false
        @State private var offset: CGFloat = 0
        @State private var showSplash = true
        @State private var showingSmallUserGuide = false
        @State private var showingLargeUserGuide = false
        @State private var currentGuideStep = 0
        @State private var highlightID: String? = nil
        @State private var buttonFrames: [String: CGRect] = [:]

        private let guideSteps: [UserGuideStep] = [
            UserGuideStep(
                title: NSLocalizedString("Subir Ticket", comment: ""),
                description: NSLocalizedString("El botón 'Subir Ticket' se encuentra en la parte inferior central de la pantalla principal. Úsalo para cargar tickets desde archivos. Consejo: Crea una carpeta dedicada para tus tickets para organizarlos y subirlos fácilmente.", comment: ""),
                imageName: "subirTicketButton",
                highlightID: "subirTicket"
            ),
            UserGuideStep(
                title: NSLocalizedString("Calendario", comment: ""),
                description: NSLocalizedString("El calendario está en el centro de la pantalla principal y se actualiza al subir un ticket, marcando los días con tickets con un punto verde.", comment: ""),
                imageName: "calendarAndList",
                highlightID: "calendar"
            ),
            UserGuideStep(
                title: NSLocalizedString("Lista de Tickets", comment: ""),
                description: NSLocalizedString("El botón 'Lista de Tickets' muestra todos tus tickets y el conteo de entradas y salidas.", comment: ""),
                imageName: "listaTicket",
                highlightID: "ticketList"
            ),
            UserGuideStep(
                title: NSLocalizedString("Días de Clase", comment: ""),
                description: NSLocalizedString("El botón 'Días de Clase' te permite seleccionar los días en que usarás los tickets, permitiendo a la aplicación mandarte notificaciones de alertas si falta un ticket para un día de clase.", comment: ""),
                imageName: "diasLaborables",
                highlightID: "workdays"
            ),
            UserGuideStep(
                title: NSLocalizedString("Tickets de Entrada y Salida", comment: ""),
                description: NSLocalizedString("Los botones 'Entrada' y 'Salida' están en la parte superior. Al presionarlos, se muestra el ticket correspondiente al día actual.", comment: ""),
                imageName: "entradaSalidaBotones",
                highlightID: "entryExit"
            ),
            UserGuideStep(
                title: NSLocalizedString("Ajustes", comment: ""),
                description: NSLocalizedString("El botón 'Ajustes' (ícono de engranaje) te permite configurar notificaciones y colores de la interfaz.", comment: ""),
                imageName: "settingsButton",
                highlightID: "settings"
            )
        ]
        
        var body: some View {
                ZStack {
                    if showSplash {
                        SplashView()
                            .transition(.opacity)
                    } else {
                        mainContent
                    }
                    if showingSmallUserGuide, let currentStep = guideSteps[safe: currentGuideStep], let frame = buttonFrames[currentStep.highlightID] {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                VStack {
                                    Image(currentStep.imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200, height: 200)
                                    Text(currentStep.title)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(currentStep.description)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.white)
                                        .padding()
                                    HStack {
                                        if currentGuideStep > 0 {
                                            Button(action: { currentGuideStep -= 1; highlightID = guideSteps[safe: currentGuideStep]?.highlightID }) {
                                                Text("Anterior")
                                                    .foregroundColor(.white)
                                                    .padding()
                                            }
                                        }
                                        if currentGuideStep < guideSteps.count - 1 {
                                            Button(action: { currentGuideStep += 1; highlightID = guideSteps[safe: currentGuideStep]?.highlightID }) {
                                                Text("Siguiente")
                                                    .foregroundColor(.white)
                                                    .padding()
                                            }
                                        } else {
                                            Button(action: { showingSmallUserGuide = false; UserDefaults.standard.set(true, forKey: "hasSeenSmallUserGuide") }) {
                                                Text("Finalizar")
                                                    .foregroundColor(.white)
                                                    .padding()
                                            }
                                        }
                                    }
                                }
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(10)
                                .padding()
                                .overlay(
                                    GeometryReader { geo in
                                        ArrowShape()
                                            .fill(Color.white)
                                            .frame(width: 20, height: 20)
                                            .rotationEffect(.degrees(calculateArrowAngle(frame: frame, viewFrame: geo.frame(in: .global))))
                                            .position(x: calculateArrowX(frame: frame, viewFrame: geo.frame(in: .global)), y: calculateArrowY(frame: frame, viewFrame: geo.frame(in: .global)))
                                    },
                                    alignment: .center
                                )
                            }
                        }
                    }
                }
                .onAppear {
                    if !UserDefaults.standard.bool(forKey: "hasSeenSmallUserGuide") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            ticketManager.requestNotificationPermission { granted in
                                DispatchQueue.main.async {
                                    showingSmallUserGuide = true
                                    highlightID = guideSteps[safe: currentGuideStep]?.highlightID
                                }
                            }
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut) {
                            showSplash = false
                        }
                    }
                }
                .overlayPreferenceValue(ButtonFrameKey.self) { frames in
                    GeometryReader { _ in
                        ForEach(Array(frames.keys), id: \.self) { key in
                            if let frame = frames[key] {
                                Color.clear
                                    .preference(key: ButtonFrameKey.self, value: [key: frame])
                            }
                        }
                    }
                    .onPreferenceChange(ButtonFrameKey.self) { newFrames in
                        buttonFrames = newFrames
                    }
                }
                .sheet(isPresented: $showingLargeUserGuide) {
                    UserGuideView(currentGuideStep: $currentGuideStep, highlightID: $highlightID, guideSteps: guideSteps, showingUserGuide: $showingLargeUserGuide)
                        .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
        }
    }

    private var mainContent: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                mainVStack
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingLargeUserGuide = true
                        currentGuideStep = 0
                        highlightID = guideSteps[safe: currentGuideStep]?.highlightID
                    }) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        settingsButton
                        clearDataButton
                    }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { urls in
                    ticketManager.procesarArchivos(urls: urls)
                }
            }
            .sheet(isPresented: $showingWorkdays) {
                WorkdaysSelectionView(ticketManager: ticketManager)
                    .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
            }
            .sheet(isPresented: $showingTicketList) {
                TicketListView(ticketManager: ticketManager)
                    .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
            }
            .onChange(of: ticketManager.selectedDate) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    offset = ticketManager.selectedDate != nil ? -20 : 0
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .environment(\.locale, ticketManager.locale)
            .overlay(processingOverlay)
            .onAppear {
                UIApplication.shared.windows.first?.tintColor = .white
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: ticketManager.backgroundGradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var mainVStack: some View {
        VStack(spacing: 5) {
            Text("Ticom")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 40)

            ActionButtonsView(
                ticketManager: ticketManager,
                showingWorkdays: $showingWorkdays,
                showingTicketList: $showingTicketList,
                showingDocumentPicker: $showingDocumentPicker
            )
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ButtonFrameKey.self, value: [
                            "workdays": geometry.frame(in: .global),
                            "calendar": geometry.frame(in: .global),
                            "ticketList": geometry.frame(in: .global),
                            "entryExit": geometry.frame(in: .global),
                            "subirTicket": geometry.frame(in: .global)
                        ])
                }
            )

            CalendarDetailsView(ticketManager: ticketManager)
                .offset(y: offset)

            TicomCalendarViewRepresentable(ticketManager: ticketManager)
                .frame(height: 280)
                .padding(.horizontal, 20)
                .offset(y: offset - 20)

            BannerAdView()
                .frame(width: AdSizeLargeBanner.size.width, height: AdSizeLargeBanner.size.height)
                .padding(.bottom, 10)

            Spacer()
        }
        .padding(.top)
        .offset(y: -30)
    }

    private var settingsButton: some View {
        Button(action: { showingSettings = true }) {
            Image(systemName: "gearshape.circle.fill")
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(ticketManager: ticketManager)
                .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: ButtonFrameKey.self, value: [
                        "settings": geometry.frame(in: .global)
                    ])
            }
        )
    }

    private var clearDataButton: some View {
        Button(action: { showingClearDataAlert = true }) {
            Image(systemName: "trash.circle.fill")
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
        }
        .alert(isPresented: $showingClearDataAlert) {
            Alert(
                title: Text("Borrar Todos los Datos"),
                message: Text("¿Estás seguro de que deseas borrar todos los tickets y configuraciones? Esta acción no se puede deshacer."),
                primaryButton: .destructive(Text("Borrar")) {
                    ticketManager.clearAllData()
                },
                secondaryButton: .cancel()
            )
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: ButtonFrameKey.self, value: [
                        "clearData": geometry.frame(in: .global)
                    ])
            }
        )
    }

    private var processingOverlay: some View {
        Group {
            if ticketManager.isProcessing {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack {
                        CircularProgressView(progress: ticketManager.processingProgress)
                        Text("\(ticketManager.processedTickets) de \(ticketManager.totalTickets) tickets procesados")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                            .padding(.top, 10)
                        GradientButton(
                            title: ticketManager.locale.identifier == "es_DO" ? "Cancelar" : "Cancel",
                            systemImage: "xmark.circle.fill",
                            colors: [.red, .pink],
                            action: {
                                ticketManager.cancelProcessingAction()
                            },
                            isPrimary: false
                        )
                        .padding(.top, 10)
                    }
                }
            }
        }
        .allowsHitTesting(true)
    }

    private func calculateArrowAngle(frame: CGRect, viewFrame: CGRect) -> Double {
        let centerX = frame.midX
        let centerY = frame.midY
        let viewCenterX = viewFrame.midX
        let viewCenterY = viewFrame.midY
        let dx = centerX - viewCenterX
        let dy = centerY - viewCenterY
        let angle = atan2(dy, dx) * 180 / .pi
        return angle + 90 // Adjust for arrow pointing towards target
    }

    private func calculateArrowX(frame: CGRect, viewFrame: CGRect) -> CGFloat {
        let targetX = frame.midX
        let viewCenterX = viewFrame.midX
        return max(10, min(viewFrame.width - 10, targetX - viewCenterX + viewFrame.midX))
    }

    private func calculateArrowY(frame: CGRect, viewFrame: CGRect) -> CGFloat {
        let targetY = frame.midY
        let viewCenterY = viewFrame.midY
        return max(10, min(viewFrame.height - 10, targetY - viewCenterY + viewFrame.midY))
    }
}

    // MARK: - Views/HeaderView.swift
    struct HeaderView: View {
        @ObservedObject var ticketManager: TicketManager
        @Binding var showingSettings: Bool

        var body: some View {
            HStack {
                Text("Tus Tickets") // Texto estático en español
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.leading, 20)

                Spacer()

                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .padding(.trailing, 20)
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Views/TicketListView.swift
    struct TicketListView: View {
        @ObservedObject var ticketManager: TicketManager
        @State private var filtro: String = "Todos"
        @Environment(\.dismiss) var dismiss

        var body: some View {
            NavigationView {
                VStack(spacing: 15) {
                    HStack(spacing: 10) {
                        VStack {
                            Text("\(ticketManager.ticketsEntrada.count)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text("Entradas") // Texto estático en español
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack {
                            Text("\(ticketManager.ticketsSalida.count)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text("Salidas") // Texto estático en español
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    Picker("Filtro", selection: $filtro) {
                        Text("Todos").tag("Todos")
                        Text("Entrada").tag("Entrada")
                        Text("Salida").tag("Salida")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(ticketManager.obtenerTicketsFiltrados(filtro)) { ticket in
                                TicketCard(ticket: ticket, locale: ticketManager.locale)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .navigationTitle("Lista de Tickets") // Título estático en español
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cerrar") { // Texto estático en español
                            ticketManager.mostrarListaTickets = false
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: ticketManager.backgroundGradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                )
            }
            .environment(\.locale, ticketManager.locale)
        }
    }
// MARK: - Views/DynamicSectionsView.swift
struct DynamicSectionsView: View {
    @ObservedObject var ticketManager: TicketManager
    let sections: [String]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(sections, id: \.self) { section in
                    SectionView(title: section, ticketManager: ticketManager)
                }
            }
            .padding()
        }
    }
}

// MARK: - Views/SectionView.swift
struct SectionView: View {
    let title: String
    @ObservedObject var ticketManager: TicketManager
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if isExpanded {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(ticketsForSection(), id: \.id) { ticket in
                            TicketCard(ticket: ticket, locale: ticketManager.locale)
                                .padding(.horizontal)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
            }
        }
    }

    private func ticketsForSection() -> [Ticket] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = ticketManager.locale
        dateFormatter.dateFormat = "MMMM yyyy"
        let sectionDate = dateFormatter.date(from: title) ?? Date()

        let startOfMonth = ticketManager.calendar.startOfDay(for: sectionDate)
        _ = ticketManager.calendar.range(of: .month, in: .year, for: sectionDate)!
        let endOfMonth = ticketManager.calendar.date(byAdding: .month, value: 1, to: startOfMonth)!

        return (ticketManager.ticketsEntrada + ticketManager.ticketsSalida)
            .filter { ticket in
                ticket.fecha >= startOfMonth && ticket.fecha < endOfMonth
            }
            .sorted { $0.fecha > $1.fecha }
    }
}

    // MARK: - Views/FloatingActionButton.swift
    struct FloatingActionButton: View {
        @Binding var showingDocumentPicker: Bool
        @ObservedObject var ticketManager: TicketManager
        @State private var isTapped = false

        var body: some View {
            HStack(spacing: 10) {
                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isTapped = true
                    }
                    showingDocumentPicker = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring()) {
                            isTapped = false
                        }
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: ticketManager.subirTicketButtonColors),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .scaleEffect(isTapped ? 0.9 : 1.0)
                .rotationEffect(.degrees(isTapped ? 90 : 0))

                Text("Subir Ticket") // Texto estático en español
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.gray.opacity(0.3))
                    .clipShape(Capsule())
            }
        }
    }

// MARK: - Views/ActivityLogView.swift
struct ActivityLogView: View {
    @State private var selectedLevel: ErrorLogger.LogLevel? = nil
    @Environment(\.dismiss) var dismiss

    var filteredLogs: [ErrorLogger.LogEntry] {
        if let level = selectedLevel {
            return ErrorLogger.shared.getLogs().filter { $0.level == level }
        }
        return ErrorLogger.shared.getLogs()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                Picker("Nivel de Registro", selection: $selectedLevel) {
                    Text("Todos").tag(ErrorLogger.LogLevel?.none)
                    ForEach(ErrorLogger.LogLevel.allCases) { level in
                        Text(level.rawValue).tag(ErrorLogger.LogLevel?.some(level))
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(filteredLogs) { log in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(log.message)
                                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                                    .foregroundColor(.primary)
                                Divider()
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Registro de Actividades")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exportar") {
                        let logs = ErrorLogger.shared.exportLogs()
                        let activityVC = UIActivityViewController(activityItems: [logs], applicationActivities: nil)
                        UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .foregroundColor(.red)
                }
            }
        }
    }
}

    // MARK: - Views/WorkdaysSelectionView.swift

    struct WorkdaysSelectionView: View {
        @ObservedObject var ticketManager: TicketManager
        @State private var selectedDays: [String]
        @Environment(\.dismiss) var dismiss

        private let daysOfWeek = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]

        init(ticketManager: TicketManager) {
            self.ticketManager = ticketManager
            self._selectedDays = State(initialValue: ticketManager.diasLaborables)
        }

        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("Seleccionar Días de Clase")) { // Texto estático en español
                        ForEach(daysOfWeek, id: \.self) { day in
                            Toggle(day, isOn: Binding(
                                get: { selectedDays.contains(day) },
                                set: { isOn in
                                    if isOn {
                                        if !selectedDays.contains(day) {
                                            selectedDays.append(day)
                                        }
                                    } else {
                                        selectedDays.removeAll { $0 == day }
                                    }
                                }
                            ))
                        }
                    }
                }
                .navigationTitle("Días de Clase") // Título estático en español
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancelar") { // Texto estático en español
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Guardar") { // Texto estático en español
                            ticketManager.saveWorkdays(selectedDays)
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: ticketManager.backgroundGradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                )
            }
            .environment(\.locale, ticketManager.locale)
        }
    }

// MARK: - TicomApp.swift
@main
struct TicomApp: App {
    init() {
        MobileAds.shared.start(completionHandler: nil)
        requestTrackingAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func requestTrackingAuthorization() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    ErrorLogger.shared.log("Autorización de seguimiento concedida", level: .action)
                case .denied, .restricted, .notDetermined:
                    ErrorLogger.shared.log("Autorización de seguimiento denegada o no determinada", level: .process)
                @unknown default:
                    ErrorLogger.shared.log("Estado de autorización de seguimiento desconocido", level: .error)
                   }
               }
           }
       }
   }



