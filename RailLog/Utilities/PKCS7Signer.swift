import CryptoKit
import Foundation

/// Minimal DER encoder for PKCS#7 SignedData structure.
/// Produces a detached-style CMS signature suitable for Apple Wallet pass signing.
enum PKCS7Signer {

    // MARK: - Public

    /// Sign `data` using the given identity (cert + private key).
    /// Returns a DER-encoded PKCS#7 SignedData blob.
    static func sign(_ data: Data, identity: SecIdentity) throws -> Data {
        // Extract certificate and private key
        var certRef: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certRef) == errSecSuccess, let cert = certRef else {
            throw Error.badIdentity
        }
        var keyRef: SecKey?
        guard SecIdentityCopyPrivateKey(identity, &keyRef) == errSecSuccess, let key = keyRef else {
            throw Error.badIdentity
        }

        let certData = SecCertificateCopyData(cert) as Data

        // Compute SHA1 digest of data
        let digest = Data(Insecure.SHA1.hash(data: data))

        // Sign digest with RSA
        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA1, digest as CFData, &signError) as Data? else {
            throw signError?.takeRetainedValue() ?? Error.signFailed
        }

        // Build PKCS#7 SignedData
        return try encodeSignedData(
            content: data,
            certificate: certData,
            signature: signature
        )
    }

    // MARK: - DER Encoding

    private struct DER {
        var bytes: Data

        init() { bytes = Data() }

        mutating func append(tag: UInt8, data: Data) {
            bytes.append(tag)
            encodeLength(data.count)
            bytes.append(data)
        }

        mutating func append(tag: UInt8, constructed: Bool = false, _ build: (inout DER) -> Void) {
            var inner = DER()
            build(&inner)
            let innerBytes = inner.bytes
            let actualTag = constructed ? (tag | 0x20) : tag
            bytes.append(actualTag)
            encodeLength(innerBytes.count)
            bytes.append(innerBytes)
        }

        fileprivate mutating func encodeLength(_ len: Int) {
            if len < 128 {
                bytes.append(UInt8(len))
            } else if len < 256 {
                bytes.append(0x81)
                bytes.append(UInt8(len))
            } else {
                bytes.append(0x82)
                bytes.append(UInt8(len >> 8))
                bytes.append(UInt8(len & 0xFF))
            }
        }
    }

    // OIDs
    private static let oidSignedData     = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x07, 0x02]) // 1.2.840.113549.1.7.2
    private static let oidData           = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x07, 0x01]) // 1.2.840.113549.1.7.1
    private static let oidSHA1           = Data([0x2b, 0x0e, 0x03, 0x02, 0x1a])                         // 1.3.14.3.2.26
    private static let oidRSAWithSHA1    = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x05]) // 1.2.840.113549.1.1.5
    private static let oidIssuerAndSerial = Data([0x55, 0x04, 0x1d]) // Actually, for signer identifier we use issuerAndSerialNumber from the cert

    private static func encodeSignedData(content: Data, certificate: Data, signature: Data) throws -> Data {
        var der = DER()

        // Top: SEQUENCE { OID signedData, [0] EXPLICIT { ... } }
        der.append(tag: 0x30, constructed: true) { top in
            // OID: signedData
            top.bytes.append(0x06); top.encodeLength(oidSignedData.count); top.bytes.append(oidSignedData)

            // [0] EXPLICIT constructed — wraps the SignedData content
            top.append(tag: 0xa0, constructed: true) { sd in
                sd.append(tag: 0x30, constructed: true) { body in
                    // version: INTEGER 1
                    body.bytes.append(0x02); body.bytes.append(0x01); body.bytes.append(0x01)

                    // digestAlgorithms: SET { SEQUENCE { OID sha1 } }
                    body.append(tag: 0x31, constructed: true) { da in
                        da.append(tag: 0x30, constructed: true) { alg in
                            alg.bytes.append(0x06); alg.encodeLength(oidSHA1.count); alg.bytes.append(oidSHA1)
                            // parameters: NULL
                            alg.bytes.append(0x05); alg.bytes.append(0x00)
                        }
                    }

                    // encapContentInfo: SEQUENCE { OID data }
                    body.append(tag: 0x30, constructed: true) { eci in
                        eci.bytes.append(0x06); eci.encodeLength(oidData.count); eci.bytes.append(oidData)
                        // content is omitted (detached signature)
                    }

                    // certificates: [0] IMPLICIT SET { certificate, ... }  — include signer cert
                    body.append(tag: 0xa0, constructed: true) { certs in
                        certs.bytes.append(certificate)  // certificate is already DER-encoded
                    }

                    // signerInfos: SET { signerInfo }
                    body.append(tag: 0x31, constructed: true) { signers in
                        signers.append(tag: 0x30, constructed: true) { signer in
                            // version: INTEGER 1
                            signer.bytes.append(0x02); signer.bytes.append(0x01); signer.bytes.append(0x01)

                            // issuerAndSerialNumber: SEQUENCE (extract from cert)
                            // Certificate is SEQUENCE { TBSCertificate, Algorithm, Signature }
                            // TBSCert is SEQUENCE { ... version, serialNumber, signature, issuer, ... }
                            // We extract issuer (field 3) and serialNumber (field 1)
                            if let (issuerData, serialData) = extractIssuerAndSerial(from: certificate) {
                                signer.append(tag: 0x30, constructed: true) { isn in
                                    isn.bytes.append(issuerData)
                                    isn.bytes.append(serialData)
                                }
                            }

                            // digestAlgorithm: SEQUENCE { OID sha1, NULL }
                            signer.append(tag: 0x30, constructed: true) { alg in
                                alg.bytes.append(0x06); alg.encodeLength(oidSHA1.count); alg.bytes.append(oidSHA1)
                                alg.bytes.append(0x05); alg.bytes.append(0x00)
                            }

                            // signatureAlgorithm: SEQUENCE { OID rsaWithSHA1, NULL }
                            signer.append(tag: 0x30, constructed: true) { alg in
                                alg.bytes.append(0x06); alg.encodeLength(oidRSAWithSHA1.count); alg.bytes.append(oidRSAWithSHA1)
                                alg.bytes.append(0x05); alg.bytes.append(0x00)
                            }

                            // signature: OCTET STRING
                            signer.bytes.append(0x04); signer.encodeLength(signature.count); signer.bytes.append(signature)
                        }
                    }
                }
            }
        }

        return der.bytes
    }

    /// Extracts issuer and serialNumber from a DER-encoded X.509 certificate.
    /// Returns (issuer SEQUENCE bytes, serialNumber INTEGER bytes).
    private static func extractIssuerAndSerial(from certData: Data) -> (Data, Data)? {
        let bytes = [UInt8](certData)
        var pos = 0

        // Top: SEQUENCE
        guard nextTLV(bytes, &pos, tag: 0x30) else { return nil }

        // TBSCertificate: SEQUENCE
        guard nextTLV(bytes, &pos, tag: 0x30) else { return nil }

        // version: [0] EXPLICIT (optional, skip if present)
        let savedPos = pos
        if let (tag, _, tlvLen) = peekTLV(bytes, pos) {
            if tag == 0xa0 {
                pos += tlvLen
            }
        }

        // serialNumber: INTEGER
        guard let (serialTLV, serialValue) = captureTLV(bytes, &pos, tag: 0x02) else { return nil }

        // signature algorithm: SEQUENCE (skip)
        guard skipTLV(bytes, &pos) else { return nil }

        // issuer: SEQUENCE
        guard let (issuerTLV, _) = captureTLV(bytes, &pos, tag: 0x30) else { return nil }

        return (Data(issuerTLV), Data(serialTLV))
    }

    // MARK: - TLV Helpers

    private static func peekTLV(_ bytes: [UInt8], _ pos: Int) -> (tag: UInt8, length: Int, totalLength: Int)? {
        guard pos < bytes.count else { return nil }
        let tag = bytes[pos]
        var p = pos + 1
        guard p < bytes.count else { return nil }
        let len = readLength(bytes, &p)
        guard len >= 0 else { return nil }
        return (tag, len, p - pos + len)
    }

    private static func nextTLV(_ bytes: [UInt8], _ pos: inout Int, tag: UInt8) -> Bool {
        guard pos < bytes.count, bytes[pos] == tag else { return false }
        pos += 1
        let len = readLength(bytes, &pos)
        guard len >= 0, pos + len <= bytes.count else { return false }
        pos += len
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
        let b = bytes[pos]
        pos += 1
        if b < 0x80 { return Int(b) }
        let numOctets = Int(b & 0x7F)
        guard numOctets <= 4, pos + numOctets <= bytes.count else { return -1 }
        var result = 0
        for _ in 0..<numOctets {
            result = (result << 8) | Int(bytes[pos])
            pos += 1
        }
        return result
    }

    // MARK: - Error

    enum Error: Swift.Error, LocalizedError {
        case badIdentity
        case signFailed

        var errorDescription: String? {
            switch self {
            case .badIdentity: "无法从证书提取密钥"
            case .signFailed: "RSA 签名失败"
            }
        }
    }
}
