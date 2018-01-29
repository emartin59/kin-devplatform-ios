// AlamofireImplementations.swift
//
// Generated by swagger-codegen
// https://github.com/swagger-api/swagger-codegen
//

import Foundation
import Alamofire

class AlamofireRequestBuilderFactory: RequestBuilderFactory {
    func getBuilder<T>() -> RequestBuilder<T>.Type {
        return AlamofireRequestBuilder<T>.self
    }
}

private struct SynchronizedDictionary<K: Hashable, V> {

    private var dictionary = [K: V]()
    private let queue = DispatchQueue(
        label: "SynchronizedDictionary",
        qos: DispatchQoS.userInitiated,
        attributes: [DispatchQueue.Attributes.concurrent],
        autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
        target: nil
    )

    public subscript(key: K) -> V? {
        get {
            var value: V?

            queue.sync {
                value = self.dictionary[key]
            }

            return value
        }
        set {
            queue.sync(flags: DispatchWorkItemFlags.barrier) {
                self.dictionary[key] = newValue
            }
        }
    }

}

class JSONEncodingWrapper: ParameterEncoding {
    var bodyParameters: Any?
    var encoding: JSONEncoding = JSONEncoding()

    public init(parameters: Any?) {
        self.bodyParameters = parameters
    }

    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        return try encoding.encode(urlRequest, withJSONObject: bodyParameters)
    }
}

// Store manager to retain its reference
private var managerStore = SynchronizedDictionary<String, Alamofire.SessionManager>()

open class AlamofireRequestBuilder<T>: RequestBuilder<T> {
    required public init(method: String, URLString: String, parameters: Any?, isBody: Bool, headers: [String : String] = [:]) {
        super.init(method: method, URLString: URLString, parameters: parameters, isBody: isBody, headers: headers)
    }

    /**
     May be overridden by a subclass if you want to control the session
     configuration.
     */
    open func createSessionManager() -> Alamofire.SessionManager {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = buildHeaders()
        return Alamofire.SessionManager(configuration: configuration, serverTrustPolicyManager: ServerTrustPolicyManager(policies: [
            "marketplace-726855629.us-east-1.elb.amazonaws.com": .disableEvaluation
            ]))
    }

    /**
     May be overridden by a subclass if you want to control the Content-Type
     that is given to an uploaded form part.

     Return nil to use the default behavior (inferring the Content-Type from
     the file extension).  Return the desired Content-Type otherwise.
     */
    open func contentTypeForFormPart(fileURL: URL) -> String? {
        return nil
    }

    /**
     May be overridden by a subclass if you want to control the request
     configuration (e.g. to override the cache policy).
     */
    open func makeRequest(manager: SessionManager, method: HTTPMethod, encoding: ParameterEncoding, headers: [String:String]) -> DataRequest {
        return manager.request(URLString, method: method, parameters: parameters as? Parameters, encoding: encoding, headers: headers)
    }

    override open func execute(_ completion: @escaping (_ response: Response<T>?, _ error: ErrorResponse?) -> Void) {
        let managerId:String = UUID().uuidString
        // Create a new manager for each request to customize its request header
        let manager = createSessionManager()
        managerStore[managerId] = manager

        let encoding:ParameterEncoding = isBody ? JSONEncodingWrapper(parameters: parameters) : URLEncoding()

        let xMethod = Alamofire.HTTPMethod(rawValue: method)

        let param = parameters as? Parameters
        let fileKeys = param == nil ? [] : param!.filter { $1 is NSURL }
                                                           .map { $0.0 }

        if fileKeys.count > 0 {
            manager.upload(multipartFormData: { mpForm in
                for (k, v) in param! {
                    switch v {
                    case let fileURL as URL:
                        if let mimeType = self.contentTypeForFormPart(fileURL: fileURL) {
                            mpForm.append(fileURL, withName: k, fileName: fileURL.lastPathComponent, mimeType: mimeType)
                        }
                        else {
                            mpForm.append(fileURL, withName: k)
                        }
                    case let string as String:
                        mpForm.append(string.data(using: String.Encoding.utf8)!, withName: k)
                    case let number as NSNumber:
                        mpForm.append(number.stringValue.data(using: String.Encoding.utf8)!, withName: k)
                    default:
                        fatalError("Unprocessable value \(v) with key \(k)")
                    }
                }
                }, to: URLString, method: xMethod!, headers: nil, encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    if let onProgressReady = self.onProgressReady {
                        onProgressReady(upload.uploadProgress)
                    }
                    self.processRequest(request: upload, managerId, completion)
                case .failure(let encodingError):
                    completion(nil, ErrorResponse.HttpError(statusCode: 415, data: nil, error: encodingError))
                }
            })
        } else {
            let request = makeRequest(manager: manager, method: xMethod!, encoding: encoding, headers: headers)
            if let onProgressReady = self.onProgressReady {
                onProgressReady(request.progress)
            }
            processRequest(request: request, managerId, completion)
        }

    }

    private func processRequest(request: DataRequest, _ managerId: String, _ completion: @escaping (_ response: Response<T>?, _ error: ErrorResponse?) -> Void) {
        if let credential = self.credential {
            request.authenticate(usingCredential: credential)
        }

        let cleanupRequest = {
            managerStore[managerId] = nil
        }

        let validatedRequest = request.validate()

        switch T.self {
        case is String.Type:
            validatedRequest.responseString(completionHandler: { (stringResponse) in
                cleanupRequest()

                if stringResponse.result.isFailure {
                    completion(
                        nil,
                        ErrorResponse.HttpError(statusCode: stringResponse.response?.statusCode ?? 500, data: stringResponse.data, error: stringResponse.result.error as Error!)
                    )
                    return
                }

                completion(
                    Response(
                        response: stringResponse.response!,
                        body: ((stringResponse.result.value ?? "") as! T)
                    ),
                    nil
                )
            })
        case is Void.Type:
            validatedRequest.responseData(completionHandler: { (voidResponse) in
                cleanupRequest()

                if voidResponse.result.isFailure {
                    completion(
                        nil,
                        ErrorResponse.HttpError(statusCode: voidResponse.response?.statusCode ?? 500, data: voidResponse.data, error: voidResponse.result.error!)
                    )
                    return
                }

                completion(
                    Response(
                        response: voidResponse.response!,
                        body: nil),
                    nil
                )
            })
        case is Data.Type:
            validatedRequest.responseData(completionHandler: { (dataResponse) in
                cleanupRequest()

                if dataResponse.result.isFailure {
                    completion(
                        nil,
                        ErrorResponse.HttpError(statusCode: dataResponse.response?.statusCode ?? 500, data: dataResponse.data, error: dataResponse.result.error!)
                    )
                    return
                }

                completion(
                    Response(
                        response: dataResponse.response!,
                        body: (dataResponse.data as! T)
                    ),
                    nil
                )
            })
        case is URL.Type:
            validatedRequest.responseData(completionHandler: { (dataResponse) in
                cleanupRequest()

                do {

                    guard !dataResponse.result.isFailure else {
                        throw DownloadException.responseFailed
                    }

                    guard let data = dataResponse.data else {
                        throw DownloadException.responseDataMissing
                    }

                    guard let request = request.request else {
                        throw DownloadException.requestMissing
                    }

                    let fileManager = FileManager.default
                    let urlRequest = try request.asURLRequest()
                    let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let requestURL = try self.getURL(from: urlRequest)

                    var requestPath = try self.getPath(from: requestURL)

                    if let headerFileName = self.getFileName(fromContentDisposition: dataResponse.response?.allHeaderFields["Content-Disposition"] as? String) {
                        requestPath = requestPath.appending("/\(headerFileName)")
                    }

                    let filePath = documentsDirectory.appendingPathComponent(requestPath)
                    let directoryPath = filePath.deletingLastPathComponent().path

                    try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
                    try data.write(to: filePath, options: .atomic)

                    completion(
                        Response(
                            response: dataResponse.response!,
                            body: (filePath as! T)
                        ),
                        nil
                    )

                } catch let requestParserError as DownloadException {
                    completion(nil, ErrorResponse.HttpError(statusCode: 400, data:  dataResponse.data, error: requestParserError))
                } catch let error {
                    completion(nil, ErrorResponse.HttpError(statusCode: 400, data: dataResponse.data, error: error))
                }
                return
            })
        default:
            validatedRequest.responseJSON(options: .allowFragments) { response in
                cleanupRequest()

                if response.result.isFailure {
                    completion(nil, ErrorResponse.HttpError(statusCode: response.response?.statusCode ?? 500, data: response.data, error: response.result.error!))
                    return
                }

                // handle HTTP 204 No Content
                // NSNull would crash decoders
                if response.response?.statusCode == 204 && response.result.value is NSNull{
                    completion(nil, nil)
                    return
                }

                if () is T {
                    completion(Response(response: response.response!, body: (() as! T)), nil)
                    return
                }
                if let json: Any = response.result.value {
                    let decoded = Decoders.decode(clazz: T.self, source: json as AnyObject, instance: nil)
                    switch decoded {
                    case let .success(object): completion(Response(response: response.response!, body: object), nil)
                    case let .failure(error): completion(nil, ErrorResponse.DecodeError(response: response.data, decodeError: error))
                    }
                    return
                } else if "" is T {
                    // swagger-parser currently doesn't support void, which will be fixed in future swagger-parser release
                    // https://github.com/swagger-api/swagger-parser/pull/34
                    completion(Response(response: response.response!, body: ("" as! T)), nil)
                    return
                }

                completion(nil, ErrorResponse.HttpError(statusCode: 500, data: nil, error: NSError(domain: "localhost", code: 500, userInfo: ["reason": "unreacheable code"])))
            }
        }
    }

    open func buildHeaders() -> [String: String] {
        var httpHeaders = SessionManager.defaultHTTPHeaders
        for (key, value) in self.headers {
            httpHeaders[key] = value
        }
        return httpHeaders
    }

    fileprivate func getFileName(fromContentDisposition contentDisposition : String?) -> String? {

        guard let contentDisposition = contentDisposition else {
            return nil
        }

        let items = contentDisposition.components(separatedBy: ";")

        var filename : String? = nil

        for contentItem in items {

            let filenameKey = "filename="
            guard let range = contentItem.range(of: filenameKey) else {
                break
            }

            filename = contentItem
            return filename?
                .replacingCharacters(in: range, with:"")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return filename

    }

    fileprivate func getPath(from url : URL) throws -> String {

        guard var path = NSURLComponents(url: url, resolvingAgainstBaseURL: true)?.path else {
            throw DownloadException.requestMissingPath
        }

        if path.hasPrefix("/") {
            path.remove(at: path.startIndex)
        }

        return path

    }

    fileprivate func getURL(from urlRequest : URLRequest) throws -> URL {

        guard let url = urlRequest.url else {
            throw DownloadException.requestMissingURL
        }

        return url
    }
}

fileprivate enum DownloadException : Error {
    case responseDataMissing
    case responseFailed
    case requestMissing
    case requestMissingPath
    case requestMissingURL
}
