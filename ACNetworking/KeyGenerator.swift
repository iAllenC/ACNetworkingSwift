//
//  KeyGenerator.swift
//  ACNetworkingSwift
//
//  Created by 陈元兵 on 2018/12/20.
//  Copyright © 2018 Allen. All rights reserved.
//

import Foundation
import CommonCrypto
import Alamofire

private extension String {
    var ac_md5: String {
        if self.isEmpty { return "" }
        let str = self.cString(using: String.Encoding.utf8)
        let strLen = CUnsignedInt(self.lengthOfBytes(using: String.Encoding.utf8))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<UInt8>.allocate(capacity: 16)
        CC_MD5(str!, strLen, result)
        let hash = NSMutableString()
        for i in 0 ..< digestLen {
            hash.appendFormat("%02x", result[i])
        }
        free(result)
        return String(format: hash as String)
    }
}

public func ac_jsonStrong(forObj obj: Any) -> String? {
    guard let jsonData = try? JSONSerialization.data(withJSONObject: obj, options: JSONSerialization.WritingOptions(rawValue: 0)) else { return nil }
    return String(data: jsonData, encoding: .utf8)
}

public typealias KeyGenerator = (URLConvertible, Parameters?) -> String

public let DefaultGenerator: KeyGenerator = { (url: URLConvertible, param: Parameters?) -> String in
    guard let url = try? url.asURL().absoluteString else { return "" }
    guard let param = param else { return url.ac_md5 }
    return param.keys.sorted().reduce(url) { (result, key) -> String in
        let value = param[key]!
        var targetValue = ""
        if let value = value as? String {
            targetValue = value
        } else if let jsonValue = ac_jsonStrong(forObj: value) {
            targetValue = jsonValue
        } else {
            targetValue = String(describing: value)
        }
        return result + "&" + key + "=" + targetValue
    }.ac_md5
}
