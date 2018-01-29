//
// MultiChoicePoll.swift
//
// Generated by swagger-codegen
// https://github.com/swagger-api/swagger-codegen
//

import Foundation


open class MultiChoicePoll: JSONEncodable {

    public enum ContentType: String { 
        case multiChoicePoll = "MultiChoicePoll"
    }
    public var contentType: ContentType?
    public var questions: [Question]?

    public init() {}

    // MARK: JSONEncodable
    open func encodeToJSON() -> Any {
        var nillableDictionary = [String:Any?]()
        nillableDictionary["content_type"] = self.contentType?.rawValue
        nillableDictionary["questions"] = self.questions?.encodeToJSON()

        let dictionary: [String:Any] = APIHelper.rejectNil(nillableDictionary) ?? [:]
        return dictionary
    }
}

