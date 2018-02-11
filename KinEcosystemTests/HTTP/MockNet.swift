//
//
//  MockNet.swift
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//
//  kinecosystem.org
//


import Foundation
@testable import KinEcosystem

class MockNet {
    
    let baseURL: URL
    
    init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    func start() {
        Hippolyte.shared.start()
    }
    
    func stop() {
        Hippolyte.shared.stop()
    }
    
    func stubRequest(_ path: String, method: HTTPMethod, statusCode: Int, responseFilename: String? = nil, error: Error? = nil) {
       
        var response:StubResponse!
        if let responseError = error {
            response = StubResponse(error: responseError as NSError)
        } else {
            response = StubResponse(statusCode: statusCode)
        }
        
        if let responseBodyFile = responseFilename {
            response.body = try! Data(contentsOf: Bundle(for: MockNet.self).url(forResource: responseBodyFile, withExtension: "json")!)
        }
        
        let request = StubRequest.Builder().stubRequest(withMethod: method, url: baseURL.appendingPathComponent(path)).addResponse(response).build()
        
        Hippolyte.shared.add(stubbedRequest: request)
    }
    
    func stubImage(_ name: String, imageBundleURL: URL) {
       
        var response:StubResponse!
        
        response = StubResponse()
        response.headers = ["Content-Type": "image/png"]
        response.body = try! Data(contentsOf: imageBundleURL)
        let url = baseURL.appendingPathComponent(name)
        let request = StubRequest.Builder().stubRequest(withMethod: .GET, url: url).addResponse(response).build()
        
        Hippolyte.shared.add(stubbedRequest: request)
    }
}

struct ESConfigProduction: EcosystemConfiguration {
    let baseURL = URL(string: "http://api.kinmarketplace.com/v1")!
}

extension StubResponse {
    var data: Data? {
        return self.body
    }
}

