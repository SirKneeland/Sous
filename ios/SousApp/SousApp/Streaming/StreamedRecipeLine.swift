import Foundation

/// A single parsed line from the streaming recipe creation NDJSON feed.
enum StreamedRecipeLine {
    case chat(text: String)
    case meta(title: String, servings: Int?)
    case ingredientGroup(header: String?)
    case ingredient(id: String, text: String)
    case step(id: String, parentId: String?, text: String)
    case note(id: String, title: String?, body: String)

    static func parse(_ jsonString: String) -> StreamedRecipeLine? {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return nil }

        switch type {
        case "chat":
            guard let text = obj["text"] as? String else { return nil }
            return .chat(text: text)

        case "meta":
            guard let title = obj["title"] as? String else { return nil }
            let servings = obj["servings"] as? Int
            return .meta(title: title, servings: servings)

        case "ingredientGroup":
            let header = obj["header"] as? String
            return .ingredientGroup(header: header)

        case "ingredient":
            guard let id = obj["id"] as? String,
                  let text = obj["text"] as? String else { return nil }
            return .ingredient(id: id, text: text)

        case "step":
            guard let id = obj["id"] as? String,
                  let text = obj["text"] as? String else { return nil }
            let parentId = obj["parentId"] as? String
            return .step(id: id, parentId: parentId, text: text)

        case "note":
            guard let id = obj["id"] as? String,
                  let body = obj["body"] as? String else { return nil }
            let title = obj["title"] as? String
            return .note(id: id, title: title, body: body)

        default:
            return nil
        }
    }
}
