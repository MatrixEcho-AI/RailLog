import CryptoKit
import Foundation

/// Produces a DER-encoded PKCS#7 SignedData signature suitable for Apple Wallet pass signing.
enum PKCS7Signer {

    // MARK: - Public

    static func sign(_ data: Data, identity: SecIdentity) throws -> Data {
        var certRef: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certRef) == errSecSuccess, let cert = certRef else {
            throw Error.badIdentity
        }
        var keyRef: SecKey?
        guard SecIdentityCopyPrivateKey(identity, &keyRef) == errSecSuccess, let key = keyRef else {
            throw Error.badIdentity
        }

        let certData = SecCertificateCopyData(cert) as Data

        let digest = Data(Insecure.SHA1.hash(data: data))

        // Build signed attributes content (Attribute SEQUENCEs without outer SET).
        // The outer SET tag is omitted because [0] IMPLICIT replaces it in SignerInfo.
        let signedAttrsContent = buildSignedAttributes(contentDigest: digest)

        // The signature is computed over the DER encoding of SET OF Attribute (with SET tag).
        var setDer = DER()
        setDer.append(tag: 0x31, data: signedAttrsContent)
        let signedAttrsForSigning = setDer.bytes

        // Sign the DER-encoded SET of signed attributes
        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA1, signedAttrsForSigning as CFData, &signError) as Data? else {
            throw signError?.takeRetainedValue() ?? Error.signFailed
        }

        return encodeSignedData(
            certificate: certData,
            signedAttributes: signedAttrsContent,
            signature: signature
        )
    }

    // MARK: - Signed Attributes

    // OIDs
    private static let oidContentType    = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x09, 0x03]) // 1.2.840.113549.1.9.3
    private static let oidMessageDigest  = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x09, 0x04]) // 1.2.840.113549.1.9.4
    private static let oidData           = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x07, 0x01]) // 1.2.840.113549.1.7.1

    /// Build signed attributes content (without outer SET wrapper — IMPLICIT tag replaces it).
    private static func buildSignedAttributes(contentDigest: Data) -> Data {
        var der = DER()

        // Attribute: contentType
        der.append(tag: 0x30, constructed: true) { attr in
            attr.append(tag: 0x06, data: oidContentType)
            attr.append(tag: 0x31, constructed: true) { vals in
                vals.append(tag: 0x06, data: oidData)
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
    private static let oidSHA1           = Data([0x2b, 0x0e, 0x03, 0x02, 0x1a])
    private static let oidRSAWithSHA1    = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x05])

    private static func encodeSignedData(certificate: Data, signedAttributes: Data, signature: Data) -> Data {
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
                            alg.append(tag: 0x06, data: oidSHA1)
                            alg.bytes.append(0x05); alg.bytes.append(0x00) // NULL
                        }
                    }

                    // encapContentInfo: SEQUENCE { OID data } (detached)
                    body.append(tag: 0x30, constructed: true) { eci in
                        eci.append(tag: 0x06, data: oidData)
                    }

                    // certificates: [0] IMPLICIT (raw cert DER)
                    body.append(tag: 0xa0, constructed: true) { certs in
                        certs.bytes.append(certificate)
                    }

                    // signerInfos: SET of SignerInfo
                    body.append(tag: 0x31, constructed: true) { signers in
                        signers.append(tag: 0x30, constructed: true) { signer in
                            // version: INTEGER 1 (PKCS#7 v1.5)
                            signer.bytes.append(0x02); signer.bytes.append(0x01); signer.bytes.append(0x01)

                            // issuerAndSerialNumber from cert
                            if let (issuer, serial) = extractIssuerAndSerial(from: certificate) {
                                signer.append(tag: 0x30, constructed: true) { isn in
                                    isn.bytes.append(Data(issuer))
                                    isn.bytes.append(Data(serial))
                                }
                            }

                            // digestAlgorithm
                            signer.append(tag: 0x30, constructed: true) { alg in
                                alg.append(tag: 0x06, data: oidSHA1)
                                alg.bytes.append(0x05); alg.bytes.append(0x00)
                            }

                            // signedAttributes: [0] IMPLICIT SET of Attribute
                            signer.bytes.append(0xa0)
                            signer.encodeLength(signedAttributes.count)
                            signer.bytes.append(signedAttributes)

                            // signatureAlgorithm
                            signer.append(tag: 0x30, constructed: true) { alg in
                                alg.append(tag: 0x06, data: oidRSAWithSHA1)
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

        // Certificate ::= SEQUENCE
        guard nextTLV(bytes, &pos, tag: 0x30) else { return nil }
        // TBSCertificate ::= SEQUENCE
        guard nextTLV(bytes, &pos, tag: 0x30) else { return nil }

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
