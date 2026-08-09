import CryptoKit
import Foundation

/// Produces a DER-encoded PKCS#7 SignedData signature suitable for Apple Wallet pass signing.
enum PKCS7Signer {

    // MARK: - Public

    /// - Parameter additionalCertificates: Extra DER-encoded certificates (e.g. Apple WWDR
    ///   intermediates) embedded in the PKCS#7 certificate set so Wallet can build the trust chain.
    static func sign(_ data: Data, identity: SecIdentity, additionalCertificates: [Data] = []) throws -> Data {
        var certRef: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certRef) == errSecSuccess, let cert = certRef else {
            throw Error.badIdentity
        }
        var keyRef: SecKey?
        guard SecIdentityCopyPrivateKey(identity, &keyRef) == errSecSuccess, let key = keyRef else {
            throw Error.badIdentity
        }

        let certData = SecCertificateCopyData(cert) as Data

        guard let (issuer, serial) = extractIssuerAndSerial(from: certData) else {
            throw Error.badIdentity
        }

        let digest = Data(SHA256.hash(data: data))

        // Build signed attributes content (Attribute SEQUENCEs without outer SET).
        // The outer SET tag is omitted because [0] IMPLICIT replaces it in SignerInfo.
        let signedAttrsContent = buildSignedAttributes(contentDigest: digest)

        // The signature is computed over the DER encoding of SET OF Attribute (with SET tag).
        var setDer = DER()
        setDer.append(tag: 0x31, data: signedAttrsContent)
        let signedAttrsForSigning = setDer.bytes

        // Sign the DER-encoded SET of signed attributes
        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA256, signedAttrsForSigning as CFData, &signError) as Data? else {
            throw signError?.takeRetainedValue() ?? Error.signFailed
        }

        return encodeSignedData(
            certificate: certData,
            additionalCertificates: additionalCertificates,
            issuer: issuer,
            serial: serial,
            signedAttributes: signedAttrsContent,
            signature: signature
        )
    }

    // MARK: - Signed Attributes

    // OIDs
    private static let oidContentType    = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x09, 0x03]) // 1.2.840.113549.1.9.3
    private static let oidMessageDigest  = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x09, 0x04]) // 1.2.840.113549.1.9.4
    private static let oidSigningTime    = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x09, 0x05]) // 1.2.840.113549.1.9.5
    private static let oidData           = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x07, 0x01]) // 1.2.840.113549.1.7.1

    /// Build signed attributes content (without outer SET wrapper — IMPLICIT tag replaces it).
    /// Attributes are emitted in canonical DER SET OF order (ascending full encoding):
    /// contentType (30 18…), signingTime (30 1c…), messageDigest (30 2f…).
    private static func buildSignedAttributes(contentDigest: Data, signingTime: Date = Date()) -> Data {
        var der = DER()

        // Attribute: contentType
        der.append(tag: 0x30, constructed: true) { attr in
            attr.append(tag: 0x06, data: oidContentType)
            attr.append(tag: 0x31, constructed: true) { vals in
                vals.append(tag: 0x06, data: oidData)
            }
        }
        // Attribute: signingTime — required by Apple Wallet ("Signature must contain a signing date")
        let df = DateFormatter()
        df.dateFormat = "yyMMddHHmmss'Z'"
        df.timeZone = TimeZone(identifier: "GMT")
        df.locale = Locale(identifier: "en_US_POSIX")
        let utcTime = Data(df.string(from: signingTime).utf8)
        der.append(tag: 0x30, constructed: true) { attr in
            attr.append(tag: 0x06, data: oidSigningTime)
            attr.append(tag: 0x31, constructed: true) { vals in
                vals.append(tag: 0x17, data: utcTime) // UTCTime "YYMMDDHHMMSSZ"
            }
        }
        // Attribute: messageDigest
        der.append(tag: 0x30, constructed: true) { attr in
            attr.append(tag: 0x06, data: oidMessageDigest)
            attr.append(tag: 0x31, constructed: true) { vals in
                vals.append(tag: 0x04, data: contentDigest)
            }
        }

        return der.bytes
    }

    // MARK: - DER Encoding

    private struct DER {
        var bytes = Data()

        mutating func append(tag: UInt8, data: Data) {
            bytes.append(tag)
            encodeLength(data.count)
            bytes.append(data)
        }

        mutating func append(tag: UInt8, constructed: Bool = false, _ build: (inout DER) -> Void) {
            var inner = DER()
            build(&inner)
            let b = inner.bytes
            bytes.append(constructed ? (tag | 0x20) : tag)
            encodeLength(b.count)
            bytes.append(b)
        }

        fileprivate mutating func encodeLength(_ len: Int) {
            if len < 128 {
                bytes.append(UInt8(len))
            } else if len < 256 {
                bytes.append(0x81); bytes.append(UInt8(len))
            } else {
                bytes.append(0x82)
                bytes.append(UInt8(len >> 8))
                bytes.append(UInt8(len & 0xFF))
            }
        }
    }

    private static let oidSignedData     = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x07, 0x02])
    private static let oidSHA256         = Data([0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01]) // 2.16.840.1.101.3.4.2.1
    private static let oidRSAWithSHA256  = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0b]) // 1.2.840.113549.1.1.11

    private static func encodeSignedData(certificate: Data, additionalCertificates: [Data], issuer: [UInt8], serial: [UInt8], signedAttributes: Data, signature: Data) -> Data {
        var der = DER()

        // ContentInfo: SEQUENCE { OID signedData, [0] EXPLICIT SignedData }
        der.append(tag: 0x30, constructed: true) { top in
            top.append(tag: 0x06, data: oidSignedData)

            top.append(tag: 0xa0, constructed: true) { sd in
                sd.append(tag: 0x30, constructed: true) { body in
                    // version: INTEGER 1 (PKCS#7 v1.5)
                    body.bytes.append(0x02); body.bytes.append(0x01); body.bytes.append(0x01)

                    // digestAlgorithms: SET of AlgorithmIdentifier
                    body.append(tag: 0x31, constructed: true) { da in
                        da.append(tag: 0x30, constructed: true) { alg in
                            alg.append(tag: 0x06, data: oidSHA256)
                            alg.bytes.append(0x05); alg.bytes.append(0x00) // NULL
                        }
                    }

                    // encapContentInfo: SEQUENCE { OID data } (detached)
                    body.append(tag: 0x30, constructed: true) { eci in
                        eci.append(tag: 0x06, data: oidData)
                    }

                    // certificates: [0] IMPLICIT (leaf + WWDR intermediates, raw cert DER)
                    body.append(tag: 0xa0, constructed: true) { certs in
                        certs.bytes.append(certificate)
                        for extra in additionalCertificates {
                            certs.bytes.append(extra)
                        }
                    }

                    // signerInfos: SET of SignerInfo
                    body.append(tag: 0x31, constructed: true) { signers in
                        signers.append(tag: 0x30, constructed: true) { signer in
                            // version: INTEGER 1 (PKCS#7 v1.5)
                            signer.bytes.append(0x02); signer.bytes.append(0x01); signer.bytes.append(0x01)

                            // issuerAndSerialNumber from cert
                            signer.append(tag: 0x30, constructed: true) { isn in
                                isn.bytes.append(Data(issuer))
                                isn.bytes.append(Data(serial))
                            }

                            // digestAlgorithm
                            signer.append(tag: 0x30, constructed: true) { alg in
                                alg.append(tag: 0x06, data: oidSHA256)
                                alg.bytes.append(0x05); alg.bytes.append(0x00)
                            }

                            // signedAttributes: [0] IMPLICIT SET of Attribute
                            signer.bytes.append(0xa0)
                            signer.encodeLength(signedAttributes.count)
                            signer.bytes.append(signedAttributes)

                            // signatureAlgorithm
                            signer.append(tag: 0x30, constructed: true) { alg in
                                alg.append(tag: 0x06, data: oidRSAWithSHA256)
                                alg.bytes.append(0x05); alg.bytes.append(0x00)
                            }

                            // signature: OCTET STRING
                            signer.append(tag: 0x04, data: signature)
                        }
                    }
                }
            }
        }

        print("[PKCS7] DER total: \(der.bytes.count) bytes")
        return der.bytes
    }

    // MARK: - Certificate Parsing

    private static func extractIssuerAndSerial(from certData: Data) -> ([UInt8], [UInt8])? {
        let bytes = [UInt8](certData)
        var pos = 0

        // Certificate ::= SEQUENCE (descend)
        guard enterTLV(bytes, &pos, tag: 0x30) else { return nil }
        // TBSCertificate ::= SEQUENCE (descend)
        guard enterTLV(bytes, &pos, tag: 0x30) else { return nil }

        // version [0] EXPLICIT (optional)
        if pos < bytes.count && bytes[pos] == 0xa0 {
            guard skipTLV(bytes, &pos) else { return nil }
        }

        // serialNumber INTEGER
        guard let (serialTLV, _) = captureTLV(bytes, &pos, tag: 0x02) else { return nil }

        // signature algorithm SEQUENCE (skip)
        guard skipTLV(bytes, &pos) else { return nil }

        // issuer SEQUENCE
        guard let (issuerTLV, _) = captureTLV(bytes, &pos, tag: 0x30) else { return nil }

        return (issuerTLV, serialTLV)
    }

    // MARK: - TLV Helpers

    /// Consume only tag and length, leaving pos at the content — for descending into constructed types.
    private static func enterTLV(_ bytes: [UInt8], _ pos: inout Int, tag: UInt8) -> Bool {
        guard pos < bytes.count, bytes[pos] == tag else { return false }
        pos += 1
        let len = readLength(bytes, &pos)
        guard len >= 0, pos + len <= bytes.count else { return false }
        return true
    }

    private static func skipTLV(_ bytes: [UInt8], _ pos: inout Int) -> Bool {
        guard pos < bytes.count else { return false }
        pos += 1
        let len = readLength(bytes, &pos)
        guard len >= 0, pos + len <= bytes.count else { return false }
        pos += len
        return true
    }

    private static func captureTLV(_ bytes: [UInt8], _ pos: inout Int, tag: UInt8) -> (entireTLV: [UInt8], value: [UInt8])? {
        let start = pos
        guard pos < bytes.count, bytes[pos] == tag else { return nil }
        pos += 1
        let len = readLength(bytes, &pos)
        guard len >= 0, pos + len <= bytes.count else { return nil }
        let valueStart = pos
        pos += len
        return (Array(bytes[start..<pos]), Array(bytes[valueStart..<pos]))
    }

    private static func readLength(_ bytes: [UInt8], _ pos: inout Int) -> Int {
        guard pos < bytes.count else { return -1 }
        let b = bytes[pos]; pos += 1
        if b < 0x80 { return Int(b) }
        let count = Int(b & 0x7F)
        guard count <= 4, pos + count <= bytes.count else { return -1 }
        var result = 0
        for _ in 0..<count {
            result = (result << 8) | Int(bytes[pos])
            pos += 1
        }
        return result
    }

    enum Error: Swift.Error, LocalizedError {
        case badIdentity, signFailed
        var errorDescription: String? {
            switch self {
            case .badIdentity: "无法从证书提取密钥"
            case .signFailed: "RSA 签名失败"
            }
        }
    }
}
