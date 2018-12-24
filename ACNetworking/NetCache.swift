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
        case memory
        case disk
        case net
    }
    
    public typealias FetchCompletion = (CacheType, Any?) -> Void

    open class MemoryCache: NSCache<NSString, AnyObject>  {
        
        var expireDateDict: [NSString: Date] = [:]
        
        var addedDateDict: [NSString: Date] = [:]

        //MARK: Override
        
        override open func object(forKey key: NSString) -> AnyObject? {
            if let expireDate = expireDateDict[key], expireDate.timeIntervalSinceNow <= 0 {
                return nil
            }
            return super.object(forKey: key)
        }
        
        override open func setObject(_ obj: AnyObject, forKey key: NSString) {
            setObject(obj, forKey: key, refreshExpireDate: true)
        }
        
        override open func setObject(_ obj: AnyObject, forKey key: NSString, cost g: Int) {
            setObject(obj, forKey: key, cost: g, refreshExpireDate: true)
        }
        
        /// 缓存对象
        ///
        /// - Parameters:
        ///   - obj: 需缓存的对象
        ///   - key: key
        ///   - refresh: 是否要刷新过期时间(如果有)
        func setObject(_ obj: AnyObject, forKey key: NSString, refreshExpireDate refresh: Bool) {
            super.setObject(obj, forKey: key)
            addedDateDict.updateValue(Date(), forKey: key)
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
        func setObject(_ obj: AnyObject, forKey key: NSString, cost g: Int, refreshExpireDate refresh: Bool) {
            super.setObject(obj, forKey: key, cost: g)
            addedDateDict.updateValue(Date(), forKey: key)
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
        func setObject(_ obj: AnyObject, forKey key: NSString, expiresIn expire: TimeInterval) {
            setObject(obj, forKey: key, expireDate: Date(timeIntervalSinceNow: expire))
        }
        
        /// 缓存对象
        ///
        /// - Parameters:
        ///   - obj: 需缓存的对象
        ///   - key: key
        ///   - date: 过期日期
        func setObject(_ obj: AnyObject, forKey key: NSString, expireDate date: Date?) {
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
        func setObject(_ obj: AnyObject, forKey key: NSString, cost g: Int, expiresIn expire: TimeInterval) {
            setObject(obj, forKey: key, cost: g, expireDate: Date(timeIntervalSinceNow: expire))
        }
        
        /// 缓存对象
        ///
        /// - Parameters:
        ///   - obj: 需缓存的对象
        ///   - key: key
        ///   - g: 消耗
        ///   - date: 过期日期
        func setObject(_ obj: AnyObject, forKey key: NSString, cost g: Int, expireDate date: Date?) {
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
        func object(forKey key: NSString, expiresIn expire: TimeInterval) -> AnyObject? {
            if let addedDate = addedDateDict[key], (addedDate + expire).timeIntervalSinceNow <= 0 {
                return nil
            }
            return object(forKey: key)
        }
        
    }

    /// 缓存目录名称
    let nameSpace: String
    
    /// 缓存目录
    let diskDirectory: String
    
    /// 文件管理
    let fileManager = FileManager()
    
    /// 读写串行Queue
    let ioQueue = DispatchQueue(label: "com.acnetworking.netcache")
    
    /// 内存缓存
    private let memoryCache = MemoryCache()
    
    /// 初始化
    ///
    /// - Parameters:
    ///   - nameSpace: 缓存目录名称
    ///   - directory: 缓存目录
    init(nameSpace: String = "defaultCache", diskDirectory directory: String? = nil) {
        self.nameSpace = nameSpace
        self.memoryCache.name = nameSpace
        if let cacheDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
            self.diskDirectory = (("com.acnetworking.netcache." + cacheDirectory) as NSString).appendingPathComponent(self.nameSpace)
        } else {
            self.diskDirectory = self.nameSpace
        }
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
    open func cacheExists(forUrl url: URLConvertible, param: Parameters? = nil, expirsIn expire: TimeInterval = .never, keyGenerator generator: KeyGenerator = DefaultGenerator) -> Bool {
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
    open func memoryCacheExists(forUrl url: URLConvertible, param: Parameters? = nil, expirsIn expire: TimeInterval = .never, keyGenerator generator: KeyGenerator = DefaultGenerator) -> Bool {
        return memoryCacheExists(forKey: generator(url, param), expiresIn: expire)
    }
    
    /// 检查传入key是否存在内存缓存
    ///
    /// - Parameters:
    ///   - key: key
    ///   - expire: 过期时间
    /// - Returns: 是否存在内存缓存
    open func memoryCacheExists(forKey key: String, expiresIn expire: TimeInterval = .never) -> Bool {
        return memoryCache.object(forKey: key as NSString, expiresIn: expire) != nil
    }
    
    /// 检查传入key是否存在磁盘缓存
    ///
    /// - Parameters:
    ///   - url: url
    ///   - param: param
    ///   - expire: 过期时间
    ///   - generator: 缓存key生成器
    /// - Returns: 是否存在磁盘缓存
    open func diskCacheExists(forUrl url: URLConvertible, param: Parameters?, expirsIn expire: TimeInterval = .never, keyGenerator generator: KeyGenerator = DefaultGenerator) -> Bool {
        return diskCacheExists(forKey: generator(url, param), expiresIn: expire)
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
    open func storeResponse(_ response: Any, forUrl url: URLConvertible, param: Parameters? = nil, toMemory: Bool = true, toDisk: Bool = true, keyGenerator generator: KeyGenerator = DefaultGenerator) {
        if !toMemory && !toDisk { return }
        let key = generator(url, param)
        if toMemory {
            memoryCache.setObject(response as AnyObject, forKey: key as NSString)
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
            try? NSKeyedArchiver.archivedData(withRootObject: response).write(to: URL(fileURLWithPath: path), options: .atomic)
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
    open func fetchResponse(forUrl url: URLConvertible, param: Parameters?, expiresIn expire: TimeInterval = .never, async: Bool = true, keyGenerator generator: KeyGenerator = DefaultGenerator, completion: @escaping FetchCompletion) {
        let storeKey = generator(url, param)
        if let result = memoryCache.object(forKey: storeKey as NSString, expiresIn: expire) {
            return completion(.memory, result)
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
                    DispatchQueue.main.async {
                        completion(.disk, result)
                    }
                }
            }
        } else {
            var type = CacheType.none
            ioQueue.sync { [unowned self] in
                if  !self.fileExpired(atPath: filePath, expiresIn: expire) {
                    result = NSKeyedUnarchiver.unarchiveObject(withFile: filePath)
                    type = .disk
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
    open func deleteResponse(forUrl url: URLConvertible, param: Parameters?, fromMemory: Bool = true, fromDisk: Bool = true, keyGenerator generator: KeyGenerator = DefaultGenerator) {
        let key = generator(url, param)
        if fromMemory && memoryCacheExists(forKey: key) {
            memoryCache.removeObject(forKey: key as NSString)
        }
        if fromDisk && diskCacheExists(forKey: key) {
            ioQueue.async {[weak self] in
                if let strongSelf = self, let filePath = strongSelf.filePath(forStoreKey: key), strongSelf.fileManager.fileExists(atPath: filePath) {
                    try? strongSelf.fileManager.removeItem(atPath: filePath)
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
            exists = fileExpired(atPath: key, expiresIn: expire)
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
        guard let attributes = try? fileManager.attributesOfItem(atPath: path) else { return nil }
        return attributes[key]
    }
    
    /// 获取缓存文件存储路径
    ///
    /// - Parameter key: 文件存储key
    /// - Returns: l缓存文件存储路径
    private func filePath(forStoreKey key: String)-> String? {
        if !fileManager.fileExists(atPath: diskDirectory) {
            do {
                try fileManager.createDirectory(atPath: diskDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return nil
            }
        }
        return (diskDirectory as NSString).appendingPathComponent(key)
    }
    
}

