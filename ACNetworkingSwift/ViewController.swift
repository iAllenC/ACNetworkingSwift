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
    
    private let networking: Networking = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 5
        return Networking(configuration: configuration)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        let url = "https://free-api.heweather.com/v5/weather"
        let param = ["key": "d9c261ebfe4644aeaea3028bcf10e149", "city": "32,118.5"]
        networking.getNet(fromUrl: url, parameters: param) { (request, cacheType, response, error) in
            print("Request:\n\(request),\nResposne:\n\(response),\n Error:\n\(error)")
        }
    }
}

