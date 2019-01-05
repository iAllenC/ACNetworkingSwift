//
//  NetCache.swift
//  ACNetworkingSwift
//
//  Created by 陈元兵 on 2018/12/19.
//  Copyright © 2018 Allen. All rights reserved.
//

import Foundation
import Alamofire

public extension TimeInterval {
    static let never = TimeInterval.greatestFiniteMagnitude
    static let always = Double(0)
}

open class NetCache {
    
    public enum CacheType {
        case none
        case memory(updateDate: Date)
        case disk(updateDate: Date)
        case net
        
        static public func ==(lhs: CacheType, rhs: CacheType) -> Bool {
            switch (lhs, rhs) {
            case (.none, .none), (.memory, .memory), (.disk, .disk), (.net, .net):
                return true
            default:
                return false
            }
        }
    }
    
    public typealias FetchCompletion = (CacheType, Any?) -> Void

    open class MemoryCache: NSCache<NSString, AnyObject>  {
        
        private var expireDateDict: [String: Date] = [:]
        
        private var updateDateDict: [String: Date] = [:]

        //MARK: Override
        
        override open func object(forKey key: NSString) -> AnyObject? {
            if let expireDate = expireDateDict[key as String], expireDate.timeIntervalSinceNow <= 0 {
                return nil
            }
            return super.object(forKey: key)
        }
        
        override open func setObject(_ obj: AnyObject, forKey key: NSString) {
            setObject(obj, forKey: key as String, refreshExpireDate: true)
        }
        
        override open func setObject(_ obj: AnyObject, forKey key: NSString, cost g: Int) {
            setObject(obj, forKey: key as String, cost: g, refreshExpireDate: true)
        }
        
        //MARK: Public
        
        /// object(forKey:)的String版
        ///
        /// - Parameter key: key
        /// - Returns: object
        open func object(forKey key: String) -> AnyObject? {
            if let expireDate = expireDateDict[key], expireDate.timeIntervalSinceNow <= 0 {
                return nil
            }
            return super.object(forKey: key as NSString)
        }
        
        /// setObject(obj:forKey:)的String版
        ///
        /// - Parameters:
        ///   - obj: object
        ///   - key: key
        open func setObject(_ obj: AnyObject, forKey key: String) {
            setObject(obj, forKey: key, refreshExpireDate: true)
        }
        
        /// setObject(obj:forKey:cost:)的String版
        ///
        /// - Parameters:
        ///   - obj: object
        ///   - key: key
        ///   - g: 消耗
        open func setObject(_ obj: AnyObject, forKey key: String, cost g: Int) {
            setObject(obj, forKey: key, cost: g, refreshExpireDate: true)
        }
        
        /// removeObject(forKey:)的String版
        ///
        /// - Parameter key: key
        open func removeObject(forKey key: String) {
            super.removeObject(forKey: key as NSString)
        }
        
        /// 缓存对象
        ///
        /// - Parameters:
        ///   - obj: 需缓存的对象
        ///   - key: key
        ///   - refresh: 是否要刷新过期时间(如果有)
        open func setObject(_ obj: AnyObject, forKey key: String, refreshExpireDate refresh: Bool) {
            super.setObject(obj, forKey: key as NSString)
            updateDateDict.updateValue(Date(), forKey: key)
            if refresh, expireDateDict.keys.contains(key) {
                expireDateDict.removeValue(forKey: key)
            }
        }
        
        /// 缓存对象
        ///
        /// - Parameters:
        ///   - obj: 需缓存的对象
        ///   - key: key
        ///   - g: 消耗
        ///   - refresh: 是否要刷新过期时间(如果有)
        open func setObject(_ obj: AnyObject, forKey key: String, cost g: Int, refreshExpireDate refresh: Bool) {
            super.setObject(obj, forKey: key as NSString, cost: g)
            updateDateDict.updateValue(Date(), forKey: key)
            if refresh, expireDateDict.keys.contains(key) {
                expireDateDict.removeValue(forKey: key)
            }
        }
        
        /// 缓存对象
        ///
        /// - Parameters:
        ///   - obj: 需缓存的对象
        ///   - key: key
        ///   - expire: 过期时长
        open func setObject(_ obj: AnyObject, forKey key: String, expiresIn expire: TimeInterval) {
            setObject(obj, forKey: key, expireDate: Date(timeIntervalSinceNow: expire))
        }
        
        /// 缓存对象
        ///
        /// - Parameters:
        ///   - obj: 需缓存的对象
        ///   - key: key
        ///   - date: 过期日期
        open func setObject(_ obj: AnyObject, forKey key: String, expireDate date: Date?) {
            if let date = date {
                expireDateDict.updateValue(date, forKey: key)
            } else {
                expireDateDict.removeValue(forKey: key)
            }
            setObject(obj, forKey: key, refreshExpireDate: false)
        }
        
        /// 缓存对象
        ///
        /// - Parameters:
        ///   - obj: 需缓存的对象
        ///   - key: key
        ///   - g: 消耗
        ///   - expire: 过期时长
        open func setObject(_ obj: AnyObject, forKey key: String, cost g: Int, expiresIn expire: TimeInterval) {
            setObject(obj, forKey: key, cost: g, expireDate: Date(timeIntervalSinceNow: expire))
        }
        
        /// 缓存对象
        ///
        /// - Parameters:
        ///   - obj: 需缓存的对象
        ///   - key: key
        ///   - g: 消耗
        ///   - date: 过期日期
        open func setObject(_ obj: AnyObject, forKey key: String, cost g: Int, expireDate date: Date?) {
            if let date = date {
                expireDateDict.updateValue(date, forKey: key)
            } else {
                expireDateDict.removeValue(forKey: key)
            }
            setObject(obj, forKey: key, cost: g, refreshExpireDate: false)
        }
        
        /// 获取未过期的缓存
        ///
        /// - Parameters:
        ///   - key: key
        ///   - expire: 过期时长
        /// - Returns: 缓存对象或nil
        open func object(forKey key: String, expiresIn expire: TimeInterval) -> AnyObject? {
            if let addedDate = updateDateDict[key], (addedDate + expire).timeIntervalSinceNow <= 0 {
                return nil
            }
            return object(forKey: key)
        }
        
        open func updateDate(forKey key: String) -> Date? {
            return updateDateDict[key]
        }
        
    }

    /// 缓存目录名称
    public let nameSpace: String
    
    /// 缓存目录
    public let diskDirectory: String
    
    /// 文件管理
    public let fileManager = FileManager()
    
    /// 缓存key生成器
    public var keyGenerator: KeyGenerator
    
    /// 读写串行Queue
    private let ioQueue = DispatchQueue(label: "com.acnetworking.netcache")
    
    /// 内存缓存
    private let memoryCache = MemoryCache()
    
    /// 初始化
    ///
    /// - Parameters:
    ///   - nameSpace: 缓存目录名称
    ///   - directory: 缓存目录
    public init(nameSpace: String = "defaultCache", diskDirectory directory: String? = nil, keyGenerator: KeyGenerator? = nil) {
        self.nameSpace = nameSpace
        self.memoryCache.name = nameSpace
        let cacheDirectory = directory ?? NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? ""
        self.diskDirectory = (cacheDirectory as NSString).appendingPathComponent("com.acnetworking.netcache." + self.nameSpace)
        self.keyGenerator = keyGenerator ?? DefaultGenerator
    }
    
    //MARK: Check
    
    /// 检查传入key是否存在缓存
    ///
    /// - Parameters:
    ///   - url: url
    ///   - param: param
    ///   - expire: 过期时间
    ///   - generator: 缓存key生成器
    /// - Returns: 是否存在缓存
    open func cacheExists(forUrl url: URLConvertible, param: Parameters? = nil, expirsIn expire: TimeInterval = .never, keyGenerator generator:  KeyGenerator? = nil) -> Bool {
        return memoryCacheExists(forUrl: url, param: param, expirsIn: expire, keyGenerator: generator) || diskCacheExists(forUrl: url, param: param, expirsIn: expire, keyGenerator: generator)
    }
    
    /// 检查传入key是否存在内存缓存
    ///
    /// - Parameters:
    ///   - url: url
    ///   - param: param
    ///   - expire: 过期时间
    ///   - generator: 缓存key生成器
    /// - Returns: 是否存在内存缓存
    open func memoryCacheExists(forUrl url: URLConvertible, param: Parameters? = nil, expirsIn expire: TimeInterval = .never, keyGenerator generator: KeyGenerator? = nil) -> Bool {
        return memoryCacheExists(forKey: (generator ?? keyGenerator)(url, param), expiresIn: expire)
    }
    
    /// 检查传入key是否存在内存缓存
    ///
    /// - Parameters:
    ///   - key: key
    ///   - expire: 过期时间
    /// - Returns: 是否存在内存缓存
    open func memoryCacheExists(forKey key: String, expiresIn expire: TimeInterval = .never) -> Bool {
        return memoryCache.object(forKey: key, expiresIn: expire) != nil
    }
    
    /// 检查传入key是否存在磁盘缓存
    ///
    /// - Parameters:
    ///   - url: url
    ///   - param: param
    ///   - expire: 过期时间
    ///   - generator: 缓存key生成器
    /// - Returns: 是否存在磁盘缓存
    open func diskCacheExists(forUrl url: URLConvertible, param: Parameters?, expirsIn expire: TimeInterval = .never, keyGenerator generator: KeyGenerator? = nil) -> Bool {
        return diskCacheExists(forKey: (generator ?? keyGenerator)(url, param), expiresIn: expire)
    }
    
    /// 检查传入key是否存在磁盘缓存
    ///
    /// - Parameters:
    ///   - key: key
    ///   - expire: 过期时间
    /// - Returns: 是否存在磁盘缓存
    open func diskCacheExists(forKey key: String, expiresIn expire: TimeInterval = .never) -> Bool {
        var exists = false
        ioQueue.sync {
            exists = _diskCacheExists(forKey: key, expiresIn: expire)
        }
        return exists
    }
    
    /// 检查指定路径文件是否过期
    ///
    /// - Parameters:
    ///   - path: 文件路径
    ///   - expire: 过期时间
    /// - Returns: 指定路径文件是否过期
    open func fileExpired(atPath path: String, expiresIn expire: TimeInterval) -> Bool {
        guard let modificationDate = fileModificationDate(atPath: path) else { return true }
        return modificationDate + expire <= Date()
    }
    
    //MARK: Store
    
    /// 存储请求结果
    ///
    /// - Parameters:
    ///   - response: 请求结果
    ///   - url: url
    ///   - param: param
    ///   - toMemory: 是否缓存至内存
    ///   - toDisk: 是否缓存至磁盘
    ///   - generator: 存储key生成器
    open func storeResponse(_ response: Any, forUrl url: URLConvertible, param: Parameters? = nil, toMemory: Bool = true, toDisk: Bool = true, keyGenerator generator: KeyGenerator? = nil) {
        if !toMemory && !toDisk { return }
        let key = (generator ?? keyGenerator)(url, param)
        if toMemory {
            memoryCache.setObject(response as AnyObject, forKey: key)
        }
        if toDisk {
            storeResponseToDisk(response, forKey: key)
        }
    }
    
    
    /// 存储请求结果至磁盘
    ///
    /// - Parameters:
    ///   - response: 请求结果
    ///   - key: key
    open func storeResponseToDisk(_ response: Any, forKey key: String) {
        ioQueue.async {[weak self] in
            guard let path = self?.filePath(forStoreKey: key) else { return }
            do {
                try NSKeyedArchiver.archivedData(withRootObject: response).write(to: URL(fileURLWithPath: path), options: .atomic)
            } catch {
                print("缓存结果:\(response)\n至目标路径:\(path)失败,错误内容:\(error)")
            }
        }
    }
    
    //MARK: Fetch
    
    /// 获取本地缓存
    ///
    /// - Parameters:
    ///   - url: url
    ///   - param: param
    ///   - expire: 过期时间
    ///   - async: 是否异步获取
    ///   - generator: 缓存key生成器
    ///   - completion: 回调
    open func fetchResponse(forUrl url: URLConvertible, param: Parameters?, expiresIn expire: TimeInterval = .never, async: Bool = true, keyGenerator generator: KeyGenerator? = nil, completion: @escaping FetchCompletion) {
        let storeKey = (generator ?? keyGenerator)(url, param)
        if let result = memoryCache.object(forKey: storeKey, expiresIn: expire) {
            return completion(.memory(updateDate: memoryCache.updateDate(forKey: storeKey) ?? .distantPast), result)
        }
        guard let filePath = filePath(forStoreKey: storeKey) else { return completion(.none, nil) }
        var result: Any? = nil
        if async {
            ioQueue.async { [weak self] in
                guard let strongSelf = self else { return }
                if strongSelf.fileExpired(atPath: filePath, expiresIn: expire) {
                    DispatchQueue.main.async {
                        completion(.none, nil)
                    }
                } else {
                    result = NSKeyedUnarchiver.unarchiveObject(withFile: filePath)
                    let date = strongSelf.fileModificationDate(atPath: filePath) ?? .distantPast
                    DispatchQueue.main.async {
                        completion(.disk(updateDate: date), result)
                    }
                }
            }
        } else {
            var type = CacheType.none
            ioQueue.sync { [unowned self] in
                if  !self.fileExpired(atPath: filePath, expiresIn: expire) {
                    let date = self.fileModificationDate(atPath: filePath) ?? .distantPast
                    result = NSKeyedUnarchiver.unarchiveObject(withFile: filePath)
                    type = .disk(updateDate: date)
                }
            }
            completion(type, result)
        }
    }
    
    //MARK: Delete
    
    /// 删除本地缓存
    ///
    /// - Parameters:
    ///   - url: url
    ///   - param: param
    ///   - fromMemory: 是否删除内存缓存
    ///   - fromDisk: 是否删除磁盘缓存
    ///   - generator: 缓存key生成器
    open func deleteResponse(forUrl url: URLConvertible, param: Parameters?, fromMemory: Bool = true, fromDisk: Bool = true, keyGenerator generator: KeyGenerator? = nil) {
        let key = (generator ?? keyGenerator)(url, param)
        if fromMemory && memoryCacheExists(forKey: key) {
            memoryCache.removeObject(forKey: key)
        }
        if fromDisk && diskCacheExists(forKey: key) {
            ioQueue.async {[weak self] in
                if let strongSelf = self, let filePath = strongSelf.filePath(forStoreKey: key), strongSelf.fileManager.fileExists(atPath: filePath) {
                    do {
                        try strongSelf.fileManager.removeItem(atPath: filePath)
                    } catch {
                        print("删除目标路径:\(filePath)缓存失败,错误内容:\(error)")
                    }
                }
            }
        }
    }
    
    //MARK: Private
    
    /// 检查指定key对应缓存是否存在的内部方法,需保证在ioQueue调用
    ///
    /// - Parameters:
    ///   - key: key
    ///   - expire: 过期时间
    /// - Returns: 是否存在
    private func _diskCacheExists(forKey key: String, expiresIn expire: TimeInterval) -> Bool {
        guard let filePath = filePath(forStoreKey: key) else { return false }
        var exists = fileManager.fileExists(atPath: filePath)
        if !exists {
            exists = fileManager.fileExists(atPath: (filePath as NSString).deletingPathExtension)
        }
        if exists {
            exists = !fileExpired(atPath: filePath, expiresIn: expire)
        }
        return exists
    }
    
    /// 获取指定路径最后修改时间
    ///
    /// - Parameter path: 路径
    /// - Returns: 修改时间
    private func fileModificationDate(atPath path: String) -> Date? {
        guard fileManager.fileExists(atPath: path) else { return nil }
        return propertyOfFile(atPath: path, forKey: .modificationDate) as? Date
    }
    
    
    /// 获取文件路径相关属性
    ///
    /// - Parameters:
    ///   - path: 文件路径
    ///   - key: 属性Key
    /// - Returns: 属性Value
    private func propertyOfFile(atPath path: String, forKey key: FileAttributeKey) -> Any? {
        do {
            return (try fileManager.attributesOfItem(atPath: path))[key]
        } catch {
            print("获取目标路径:\(path)相关属性失败:\(key),\n错误内容:\(error)")
            return nil
        }
    }
    
    /// 获取缓存文件存储路径
    ///
    /// - Parameter key: 文件存储key
    /// - Returns: 缓存文件存储路径
    private func filePath(forStoreKey key: String)-> String? {
        if !fileManager.fileExists(atPath: diskDirectory) {
            do {
                try fileManager.createDirectory(atPath: diskDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("缓存目录创建失败:\(diskDirectory)")
                return nil
            }
        }
        return (diskDirectory as NSString).appendingPathComponent(key)
    }
    
}

