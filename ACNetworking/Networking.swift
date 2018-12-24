//
//  Networking.swift
//  ACNetworkingSwift
//
//  Created by 陈元兵 on 2018/12/19.
//  Copyright © 2018 Allen. All rights reserved.
//

import Foundation
import Alamofire

open class Networking {
    
    public struct FetchOptions: OptionSet {
        
        public let rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        /** 默认option 先取网络,请求失败再取本地,优先级最低.*/
        public static let netFirst = FetchOptions(rawValue: 0)
        
        /** 以下option优先级逐渐降低 */
        
        /** 传入这个option只请求网络数据,忽略本地 */
        public static let netOnly = FetchOptions(rawValue: 1 << 0)
        
        /** 传入这个option只获取本地缓存 */
        public static let localOnly = FetchOptions(rawValue: 1 << 1)
        
        /** 优先取本地缓存,无缓存取网络 */
        public static let localFirst = FetchOptions(rawValue: 1 << 2)
        
        /** 传入这个option先取本地(如果有的话),然后取网络 */
        public static let localAndNet = FetchOptions(rawValue: 1 << 3)
        
        /** 以下option无冲突,无优先级区别 */
        
        /** 默认请求成功后会更新本地缓存的返回结果, 传入这个option将不更新缓存*/
        public static let notUpdateCache = FetchOptions(rawValue: 1 << 4)
        
        /** 传入这个option,将在回调结束后删除本地缓存 */
        public static let deleteCache = FetchOptions(rawValue: 1 << 5)
        
    }
    
    public enum NetFetchError: Error {
        case noCache
    }
    
    public typealias NetworkingCompletion = (NetCache.CacheType, Any?, Error?) -> Void

    static let shared = Networking()
    
    var sessionManager = SessionManager.default
    
    let responseCache = NetCache()
    
    //MARK: Public
    
    /// 根据传入的method和options发起(post/get)请求,或获取本地数据
    ///
    /// - Parameters:
    ///   - url: URL
    ///   - options: options
    ///   - method: method
    ///   - parameters: parameters
    ///   - encoding: encoding
    ///   - headers: headers
    ///   - expire: 过期时间
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    /// - Returns: DataRequest
    @discardableResult
    open func fetch(url: URLConvertible, options:FetchOptions, method: HTTPMethod, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, expiresIn expire: TimeInterval, keyGenerator generator: @escaping KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) -> DataRequest? {
        if shouldFetchLocalResponse(forUrl: url, param: parameters, options: options, expiresIn: expire) {
            let async = options.contains(.localOnly) || options.contains(.localFirst)
            responseCache.fetchResponse(forUrl: url, param: parameters, expiresIn: expire, async: async, keyGenerator: generator) { [weak self](cacheType, response) in
                completion?(cacheType, response, cacheType == .none ? NetFetchError.noCache : nil)
                if options.contains(.deleteCache) {
                    self?.responseCache.deleteResponse(forUrl: url, param: parameters)
                }
            }
            if !async {
                return fetchNet(url:url, options:options, method:method, parameters:parameters, encoding:encoding, headers:headers, expiresIn:expire, keyGenerator:generator, completion:completion)
            } else {
                return nil
            }
        } else {
            return fetchNet(url:url, options:options, method:method, parameters:parameters, encoding:encoding, headers:headers, expiresIn:expire, keyGenerator:generator, completion:completion)
        }
    }
    
    //MARK: Public
    
    /// 根据传入的method和options发起(post/get)请求
    ///
    /// - Parameters:
    ///   - url: url
    ///   - options: options
    ///   - method: method
    ///   - parameters: parameters
    ///   - encoding: encoding
    ///   - headers: headers
    ///   - expire: 过期时间
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    /// - Returns: DataRequest
    @discardableResult
    func fetchNet(url: URLConvertible, options:FetchOptions, method: HTTPMethod, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, expiresIn expire: TimeInterval, keyGenerator generator: @escaping KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) -> DataRequest {
        return sessionManager.request(url, method: method, parameters: parameters, encoding: encoding, headers: nil).responseJSON { [weak self]response in
            switch(response.result) {
            case .success(let v):
                self?.handleHttpSuccess(url: url, parameters: parameters, expires: expire, options: options, response: v, keyGenerator: generator, completion: completion)
                break
            case .failure(let e):
                self?.handleHttpFailure(url: url, parameters: parameters, expiresIn: expire, options: options, error: e, keyGenerator: generator, completion: completion)
                break
            }
        }
    }

    /// 发起get请求
    ///
    /// - Parameters:
    ///   - url: url
    ///   - parameters: parameters
    ///   - encoding: encoding
    ///   - headers: headers
    ///   - expire: 过期时间
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    /// - Returns: DataRequest
    @discardableResult
    open func getNet(fromUrl url: URLConvertible, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, expiresIn expire: TimeInterval = .always, keyGenerator generator: @escaping KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) -> DataRequest? {
        return fetch(url: url, options: .netOnly, method: .get, parameters: parameters, encoding: encoding, headers: headers, expiresIn: expire, keyGenerator: generator, completion: completion)
    }
    
    /// 获取get数据, 优先获取网络数据, 失败取本地缓存
    ///
    /// - Parameters:
    ///   - url: url
    ///   - parameters: parameters
    ///   - encoding: encoding
    ///   - headers: headers
    ///   - expire: 过期时间
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    /// - Returns: DataRequest
    @discardableResult
    open func getRequest(fromUrl url: URLConvertible, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, expiresIn expire: TimeInterval = .always, keyGenerator generator: @escaping KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) -> DataRequest? {
        return fetch(url: url, options: .netFirst, method: .get, parameters: parameters, encoding: encoding, headers: headers, expiresIn: expire, keyGenerator: generator, completion: completion)
    }
    
    /// 获取get数据, 优先获取本地缓存, 无缓存则发起网络请求
    ///
    /// - Parameters:
    ///   - url: url
    ///   - parameters: parameters
    ///   - encoding: encoding
    ///   - headers: headers
    ///   - expire: 过期时间
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    /// - Returns: DataRequest
    @discardableResult
    open func getData(fromUrl url: URLConvertible, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, expiresIn expire: TimeInterval = .never, keyGenerator generator: @escaping KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) -> DataRequest? {
        return fetch(url: url, options: .localFirst, method: .get, parameters: parameters, encoding: encoding, headers: headers, expiresIn: expire, keyGenerator: generator, completion: completion)
    }
    
    /// 获取本地缓存
    ///
    /// - Parameters:
    ///   - url: url
    ///   - parameters: parameters
    ///   - encoding: encoding
    ///   - headers: headers
    ///   - expire: 过期时间
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    open func getLocal(fromUrl url: URLConvertible, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, expiresIn expire: TimeInterval = .never, keyGenerator generator: @escaping KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) {
        fetch(url: url, options: .localOnly, method: .get, parameters: parameters, encoding: encoding, headers: headers, expiresIn: expire, keyGenerator: generator, completion: completion)
    }
    
    /// 先取本地缓存, 然后发起网络请求
    ///
    /// - Parameters:
    ///   - url: url
    ///   - parameters: parameters
    ///   - encoding: encoding
    ///   - headers: headers
    ///   - expire: 过期时间
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    @discardableResult
    open func getLocalThenNet(fromUrl url: URLConvertible, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, expiresIn expire: TimeInterval = .never, keyGenerator generator: @escaping KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) -> DataRequest? {
        return fetch(url: url, options: .localAndNet, method: .get, parameters: parameters, encoding: encoding, headers: headers, expiresIn: expire, keyGenerator: generator, completion: completion)
    }
    
    /// 发起post请求
    ///
    /// - Parameters:
    ///   - url: url
    ///   - parameters: parameters
    ///   - encoding: encoding
    ///   - headers: headers
    ///   - expire: 过期时间
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    /// - Returns: DataRequest
    @discardableResult
    open func postNet(fromUrl url: URLConvertible, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, expiresIn expire: TimeInterval = .always, keyGenerator generator: @escaping KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) -> DataRequest? {
        return fetch(url: url, options: .netOnly, method: .post, parameters: parameters, encoding: encoding, headers: headers, expiresIn: expire, keyGenerator: generator, completion: completion)
    }
    
    /// 获取post数据, 优先获取网络数据, 失败取本地缓存
    ///
    /// - Parameters:
    ///   - url: url
    ///   - parameters: parameters
    ///   - encoding: encoding
    ///   - headers: headers
    ///   - expire: 过期时间
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    /// - Returns: DataRequest
    @discardableResult
    open func postRequest(fromUrl url: URLConvertible, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, expiresIn expire: TimeInterval = .always, keyGenerator generator: @escaping KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) -> DataRequest? {
        return fetch(url: url, options: .netFirst, method: .post, parameters: parameters, encoding: encoding, headers: headers, expiresIn: expire, keyGenerator: generator, completion: completion)
    }
    
    /// 获取post数据, 优先获取本地缓存, 无缓存则发起网络请求
    ///
    /// - Parameters:
    ///   - url: url
    ///   - parameters: parameters
    ///   - encoding: encoding
    ///   - headers: headers
    ///   - expire: 过期时间
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    /// - Returns: DataRequest
    @discardableResult
    open func postData(fromUrl url: URLConvertible, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, expiresIn expire: TimeInterval = .never, keyGenerator generator: @escaping KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) -> DataRequest? {
        return fetch(url: url, options: .localFirst, method: .get, parameters: parameters, encoding: encoding, headers: headers, expiresIn: expire, keyGenerator: generator, completion: completion)
    }

    /// 获取本地缓存
    ///
    /// - Parameters:
    ///   - url: url
    ///   - parameters: parameters
    ///   - encoding: encoding
    ///   - headers: headers
    ///   - expire: 过期时间
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    open func postLocal(fromUrl url: URLConvertible, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, expiresIn expire: TimeInterval = .never, keyGenerator generator: @escaping KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) {
        fetch(url: url, options: .localOnly, method: .post, parameters: parameters, encoding: encoding, headers: headers, expiresIn: expire, keyGenerator: generator, completion: completion)
    }

    /// 先取本地缓存, 然后发起网络请求
    ///
    /// - Parameters:
    ///   - url: url
    ///   - parameters: parameters
    ///   - encoding: encoding
    ///   - headers: headers
    ///   - expire: 过期时间
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    @discardableResult
    open func postLocalThenNet(fromUrl url: URLConvertible, parameters: Parameters?, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, expiresIn expire: TimeInterval = .never, keyGenerator generator: @escaping KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) -> DataRequest? {
        return fetch(url: url, options: .localAndNet, method: .post, parameters: parameters, encoding: encoding, headers: headers, expiresIn: expire, keyGenerator: generator, completion: completion)
    }

    //MARK: Private
    
    /// 统一处理请求成功
    ///
    /// - Parameters:
    ///   - url: url
    ///   - parameters: parameters
    ///   - expires: 过期时间
    ///   - options: options
    ///   - headers: headers
    ///   - response: response
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    private func handleHttpSuccess(url: URLConvertible, parameters: Parameters?, expires: TimeInterval, options:FetchOptions, headers: HTTPHeaders? = nil, response: Any, keyGenerator generator: KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) {
        completion?(.disk, response, nil)
        if options.contains(.deleteCache) {
            responseCache.deleteResponse(forUrl: url, param: parameters)
        }
        if !options.contains(.notUpdateCache) {
            responseCache.storeResponse(response, forUrl: url, param: parameters, keyGenerator: generator)
        }
    }
    
    //MARK: Private
    
    /// 统一处理请求失败
    ///
    /// - Parameters:
    ///   - url: url
    ///   - parameters: parameters
    ///   - expires: 过期时间
    ///   - options: options
    ///   - headers: headers
    ///   - error: error
    ///   - generator: 存储key生成器
    ///   - completion: 回调
    private func handleHttpFailure(url: URLConvertible, parameters: Parameters?, expiresIn expire: TimeInterval, options:FetchOptions, headers: HTTPHeaders? = nil, error: Error, keyGenerator generator: KeyGenerator = DefaultGenerator, completion: NetworkingCompletion? = nil) {
        if options.contains(.netOnly) || options.contains(.localOnly) || options.contains(.localFirst) {
            //只读网络、优先读本地、先读本地再取网络,直接回调(优先读本地或先读本地走到失败意味着本地没有缓存)
            completion?(.none, nil, error)
            if options.contains(.deleteCache) {
                responseCache.deleteResponse(forUrl: url, param: parameters)
            }
        } else {
            responseCache.fetchResponse(forUrl: url, param: parameters, expiresIn: expire, keyGenerator: generator) { (cacheType, response) in
                completion?(cacheType, response, cacheType == .none ? error : nil)
            }
            if options.contains(.deleteCache) {
                responseCache.deleteResponse(forUrl: url, param: parameters)
            }
        }
    }
    
    
    /// 判断是否需要读取本地缓存
    ///
    /// - Parameters:
    ///   - url: url
    ///   - param: param
    ///   - options: options
    ///   - expire: 过期时间
    /// - Returns: 是否需要读取缓存
    private func shouldFetchLocalResponse(forUrl url: URLConvertible, param: Parameters?, options: FetchOptions, expiresIn expire: TimeInterval) -> Bool {
        //option只读网络
        if options.contains(.netOnly) { return false }
        //option只读本地
        if options.contains(.localOnly) { return true }
        //option优先读缓存或先读缓存,返回本地是否有未过期缓存
        if options.contains(.localFirst) || options.contains(.localAndNet) {
            return responseCache.cacheExists(forUrl: url, param: param)
        }
        //以上option均未传,不读缓存
        return false
    }

}
