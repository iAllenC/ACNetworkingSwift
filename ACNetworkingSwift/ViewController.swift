//
//  ViewController.swift
//  ACNetworkingSwift
//
//  Created by 陈元兵 on 2018/12/19.
//  Copyright © 2018 Allen. All rights reserved.
//

import UIKit
import Alamofire

class ViewController: UIViewController {
    
    @IBOutlet weak var methodSegment: UISegmentedControl!
    
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var expireTimeField: UITextField!
    
    @IBOutlet var optionButtons: [UIButton]!
    
    @IBOutlet weak var longField: UITextField!
    
    @IBOutlet weak var latField: UITextField!
    
    var options: Networking.FetchOptions {
        var targetOptions: Networking.FetchOptions = []
        for btn in optionButtons {
            if !btn.isSelected { continue }
            targetOptions.insert(options(forTag: btn.tag))
        }
        return targetOptions
    }
    
    var requst: DataRequest?
    
    private let networking: Networking = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 5
        return Networking(configuration: configuration, cacheDirectory: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func options(forTag tag: Int) -> Networking.FetchOptions {
        switch tag {
        case 0:
            return .netFirst
        case 1:
            return .netOnly
        case 2:
            return .localOnly
        case 3:
            return .localFirst
        case 4:
            return .localAndNet
        case 5:
            return .notUpdateCache
        case 6:
            return .deleteCache
        default:
            return .netFirst
        }
    }
    
    @IBAction func optionAction(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
    }
    
    @IBAction func sendAction(_ sender: UIButton) {
        /** 天气接口场景并不适合做缓存,本demo只是用作示例. */
        let url = "https://free-api.heweather.com/v5/weather"
        let lat = latField.text!.isEmpty ? "32" : latField.text!
        let long = longField.text!.isEmpty ? "118.5" : longField.text!
        let param = ["key": "d9c261ebfe4644aeaea3028bcf10e149", "city": "\(lat),\(long)"]
        var expire: TimeInterval
        if let text = self.expireTimeField.text, let expireTime = Double(text) {
            expire = expireTime <= 0 ? .always : expireTime
        } else {
            expire = .never
        }
        /** 示例只演示了一个主要方法的调用,实际上针对不同场景,本框架都做了一定的便利封装,使用者可根据需要调用 */
        requst = networking.fetch(url: url, options: options, method: methodSegment.selectedSegmentIndex == 0 ? .get : .post, parameters: param, expiresIn: expire, completion: { [weak self](request, cacheType, response, error) in
            self?.processNetCache(cacheType: cacheType, response: response, error: error)
        })
    }
    
    func processNetCache(cacheType: NetCache.CacheType, response: Any?, error: Error?) {
        if let response = response, let jsonData = try? JSONSerialization.data(withJSONObject: response, options: JSONSerialization.WritingOptions(rawValue: 0)), let jsonString = String(data: jsonData, encoding: .utf8) {
            textView.text = "\(typeName(forCacheType: cacheType)):\n \(jsonString)"
        } else if let error = error {
            textView.text = "\(typeName(forCacheType: cacheType)):\n \(error.localizedDescription)"
        }
    }
    
    func typeName(forCacheType type: NetCache.CacheType) -> String {
        switch type {
        case .net:
            return "网络返回结果"
        case .memory(let date):
            return "内存缓存结果缓存于: + \(date.description(with:.current))"
        case .disk(let date):
            return "磁盘缓存结果缓存于 + \(date.description(with:.current))"
        case .none:
            return "无结果"
        }
    }
    
}

