public enum MD {
  public enum Align {
    case left, right, center
  }
  
  public enum HeaderLevel: String {
    case h1 = "#"
    case h2 = "##"
    case h3 = "###"
    case h4 = "####"
  }
}

extension MD {
  
  static func header(_ text: String, level: HeaderLevel = .h1) -> String {
    "\(level.rawValue) \(text)\n"
  }
  
  static func h1(_ text: String) -> String {
    header(text, level: .h1)
  }
  
  static func h2(_ text: String) -> String {
    header(text, level: .h2)
  }
  
  static func h3(_ text: String) -> String {
    header(text, level: .h3)
  }
  
  static func h4(_ text: String) -> String {
    header(text, level: .h4)
  }
  
}

fileprivate extension Optional where Wrapped == String {
  var tableValue: String {
    switch self {
    case .none: return ""
    case .some(let str): return str.replacingOccurrences(of: "|", with: "\\|")
    }
  }
}

extension MD {
  
  static func table(_ headers: String?..., aligns: [Align] = [], rows: [[String?]]) -> String {
    table(headers: headers, aligns: aligns, rows: rows)
  }
  
  static func table(headers: [String?], aligns: [Align] = [], rows: [[String?]]) -> String {
    var lengths = Array<Int>(repeating: 0, count: headers.count)
    let headersCount = headers.count
    for i in 0..<headersCount {
      var len = headers[i].tableValue.utf8.count
      for row in rows {
        if i >= row.count {
          continue
        }
        
        len = max(len, row[i].tableValue.utf8.count)
      }
      lengths[i] = len
    }
    
    var result = "|"
    // Header
    for (i, h) in headers.enumerated() {
      let len = lengths[i]
      let padded = h.tableValue.padding(toLength: len, withPad: " ", startingAt: 0)
      result += " \(padded) |"
    }
    result += "\n"
    
    // align
    result += "|"
    
    for (i, _) in headers.enumerated() {
      let len = lengths[i]
      var align: Align = .left
      if i < aligns.count {
        align = aligns[i]
      }
      
      let padded = "-".padding(toLength: len - 2, withPad: "-", startingAt: 0)
      
      switch align {
      case .left:
        result += " -\(padded)- |"
      case .right:
        result += " -\(padded): |"
      case .center:
        result += " :\(padded): |"
      }
    }
    result += "\n"
    
    // values
    
    
    for row in rows {
      result += "|"
      for (i, v) in row.enumerated() {
        var padded = v.tableValue
        var len = padded.utf8.count
        if i < lengths.count {
          len = lengths[i]
        }
        
        padded = padded.padding(toLength: len, withPad: " ", startingAt: 0)
        result += " \(padded) |"
      }
      result += "\n"
    }
    
    return result
  }
}

/*
| Header 1 | Header 2 |
| -------- | -------- |
| 1        | 2        |

| Header 1 | Header 2 |
| -------- | -------- |
| 1        | 2        |
 */

