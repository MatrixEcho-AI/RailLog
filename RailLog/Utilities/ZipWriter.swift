import Foundation

/// Minimal ZIP file creator — no external dependencies.
final class ZipWriter {
    private var entries: [Entry] = []

    private struct Entry {
        let name: String
        let data: Data
    }

    func addFile(name: String, data: Data) {
        entries.append(Entry(name: name, data: data))
    }

    func finalize() -> Data {
        var output = Data()
        var centralDirectory = Data()
        var localHeaderOffsets: [UInt32] = []

        for entry in entries {
            let offset = UInt32(output.count)
            localHeaderOffsets.append(offset)

            let utf8Name = entry.name.data(using: .utf8)!
            let crc = crc32(entry.data)
            let compressedSize = UInt32(entry.data.count)
            let uncompressedSize = UInt32(entry.data.count)

            // Local file header
            output.append(littleEndian: UInt32(0x04034b50)) // signature
            output.append(littleEndian: UInt16(20))          // version needed
            output.append(littleEndian: UInt16(0))           // flags
            output.append(littleEndian: UInt16(0))           // compression method (stored)
            output.append(littleEndian: UInt16(0))           // mod time
            output.append(littleEndian: UInt16(0))           // mod date
            output.append(littleEndian: crc)
            output.append(littleEndian: compressedSize)
            output.append(littleEndian: uncompressedSize)
            output.append(littleEndian: UInt16(utf8Name.count))
            output.append(littleEndian: UInt16(0))           // extra field length
            output.append(utf8Name)
            output.append(entry.data)

            // Central directory entry
            centralDirectory.append(littleEndian: UInt32(0x02014b50)) // signature
            centralDirectory.append(littleEndian: UInt16(20))         // version made by
            centralDirectory.append(littleEndian: UInt16(20))         // version needed
            centralDirectory.append(littleEndian: UInt16(0))          // flags
            centralDirectory.append(littleEndian: UInt16(0))          // compression
            centralDirectory.append(littleEndian: UInt16(0))          // mod time
            centralDirectory.append(littleEndian: UInt16(0))          // mod date
            centralDirectory.append(littleEndian: crc)
            centralDirectory.append(littleEndian: compressedSize)
            centralDirectory.append(littleEndian: uncompressedSize)
            centralDirectory.append(littleEndian: UInt16(utf8Name.count))
            centralDirectory.append(littleEndian: UInt16(0))          // extra
            centralDirectory.append(littleEndian: UInt16(0))          // comment
            centralDirectory.append(littleEndian: UInt16(0))          // disk start
            centralDirectory.append(littleEndian: UInt16(0))          // internal attrs
            centralDirectory.append(littleEndian: UInt32(0))          // external attrs
            centralDirectory.append(littleEndian: offset)             // local header offset
            centralDirectory.append(utf8Name)
        }

        let cdOffset = UInt32(output.count)
        output.append(centralDirectory)

        // End of central directory record
        output.append(littleEndian: UInt32(0x06054b50)) // signature
        output.append(littleEndian: UInt16(0))           // disk number
        output.append(littleEndian: UInt16(0))           // disk with CD
        output.append(littleEndian: UInt16(entries.count))
        output.append(littleEndian: UInt16(entries.count))
        output.append(littleEndian: UInt32(centralDirectory.count))
        output.append(littleEndian: cdOffset)
        output.append(littleEndian: UInt16(0))           // comment length

        return output
    }

    // MARK: - CRC32

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let idx = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ Self.crc32Table[idx]
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let crc32Table: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB8_8320
                } else {
                    crc >>= 1
                }
            }
            table[i] = crc
        }
        return table
    }()
}

// MARK: - Little-endian helpers

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
