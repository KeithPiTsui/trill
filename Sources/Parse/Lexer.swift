//
//  Lexer.swift
//  Trill
//

import Foundation

enum TokenKind: Equatable {
  case number(value: IntMax, raw: String)
  case identifier(value: String)
  case unknown(char: String)
  case char(value: UInt8)
  case `operator`(op: BuiltinOperator)
  case stringLiteral(value: String)
  case semicolon
  case newline
  case leftParen
  case rightParen
  case leftBrace
  case rightBrace
  case leftBracket
  case rightBracket
  case comma
  case colon
  case questionMark
  case arrow
  case ellipsis
  case dot
  case `func`
  case Init
  case `deinit`
  case `extension`
  case sizeOf
  case type
  case `while`
  case `for`
  case `nil`
  case `if`
  case `in`
  case `else`
  case `var`
  case `let`
  case `return`
  case `case`
  case `default`
  case `switch`
  case `break`
  case `continue`
  case `true`
  case `false`
  case poundFunction
  case poundFile
  case poundLine
  case poundWarning
  case poundError
  case eof
  case underscore
  
  init(op: String) {
    switch op {
    case ":": self = .colon
    case ";": self = .semicolon
    case "\n": self = .newline
    case ",": self = .comma
    case "(": self = .leftParen
    case ")": self = .rightParen
    case "{": self = .leftBrace
    case "}": self = .rightBrace
    case ".": self = .dot
    case "?": self = .questionMark
    case "->": self = .arrow
    case "...": self = .ellipsis
    case "[": self = .leftBracket
    case "]": self = .rightBracket
    case "": self = .eof
    default: self = .unknown(char: op)
    }
  }
  
  init(identifier: String) {
    switch identifier {
    case "func": self = .func
    case "init": self = .Init
    case "deinit": self = .deinit
    case "type": self = .type
    case "extension": self = .extension
    case "sizeof": self = .sizeOf
    case "while": self = .while
    case "if": self = .if
    case "in": self = .in
    case "else": self = .else
    case "true": self = .true
    case "false": self = .false
    case "var": self = .var
    case "let": self = .let
    case "return": self = .return
    case "switch": self = .switch
    case "case": self = .case
    case "break": self = .break
    case "continue": self = .continue
    case "default": self = .default
    case "for": self = .for
    case "nil": self = .nil
    case "as": self = .operator(op: .as)
    case "#function": self = .poundFunction
    case "#file": self = .poundFile
    case "#line": self = .poundLine
    case "#warning": self = .poundWarning
    case "#error": self = .poundError
    case "_": self = .underscore
    default: self = .identifier(value: identifier)
    }
  }
  
  var text: String {
    switch self {
    case .number(let value): return "\(value)"
    case .identifier(let value): return value
    case .unknown(let char): return char
    case .char(let value): return String(UnicodeScalar(value))
    case .operator(let op): return "\(op)"
    case .stringLiteral(let value): return value.escaped()
    case .semicolon: return ";"
    case .newline: return "\\n"
    case .leftParen: return "("
    case .rightParen: return ")"
    case .leftBrace: return "{"
    case .rightBrace: return "}"
    case .comma: return ","
    case .questionMark: return "?"
    case .colon: return ":"
    case .dot: return "."
    case .func: return "func"
    case .extension: return "extension"
    case .type: return "type"
    case .while: return "while"
    case .for: return "for"
    case .nil: return "nil"
    case .if: return "if"
    case .in: return "in"
    case .else: return "else"
    case .var: return "var"
    case .let: return "let"
    case .return: return "return" // ha
    case .break: return "break"
    case .continue: return "continue"
    case .true: return "true"
    case .false: return "false"
    case .eof: return "EOF"
    case .arrow: return "->"
    case .underscore: return "_"
    case .ellipsis: return "..."
    case .leftBracket: return "["
    case .rightBracket: return "]"
    case .Init: return "init"
    case .deinit: return "deinit"
    case .sizeOf: return "sizeof"
    case .case: return "case"
    case .switch: return "switch"
    case .default: return "default"
    case .poundFunction: return "#function"
    case .poundFile: return "#file"
    case .poundLine: return "#line"
    case .poundWarning: return "#warning"
    case .poundError: return "#error"
    }
  }
  
  var isKeyword: Bool {
    switch self {
    case .func, .while, .if, .in, .else, .for, .nil, .break, .case, .switch,
         .default, .continue, .return, .underscore, .extension, .sizeOf, .var,
         .let, .type, .true, .false, .Init, .deinit, .poundFunction, .poundFile,
         .poundLine, .poundWarning, .poundError:
         return true
    case .identifier(let value):
      return DeclAttribute(rawValue: value) != nil || value == "self"
    case .operator(op: .as): return true
    default: return false
    }
  }
  
  var isLiteral: Bool {
    switch self {
    case .number: return true
    case .char: return true
    default: return false
    }
  }
  
  var isString: Bool {
    if case .stringLiteral = self { return true }
    return false
  }
  
  var isEOF: Bool {
    if case .eof = self { return true }
    return false
  }
  
  var isLineSeparator: Bool {
    if case .newline = self { return true }
    if case .semicolon = self { return true }
    return false
  }
}

func ==(lhs: TokenKind, rhs: TokenKind) -> Bool {
  switch (lhs, rhs) {
  case (.number(let value, let raw), .number(let otherValue, let otherRaw)):
    return value == otherValue && raw == otherRaw
  case (.identifier(let value), .identifier(let otherValue)):
    return value == otherValue
  case (.unknown(let v), .unknown(let v2)):
    return v == v2
  case (.char(let v), .char(let v2)):
    return v == v2
  case (.operator(let v), .operator(let v2)):
    return v == v2
  case (.stringLiteral(let v), .stringLiteral(let v2)):
    return v == v2
  case (.semicolon, .semicolon): return true
  case (.newline, .newline): return true
  case (.leftParen, .leftParen): return true
  case (.rightParen, .rightParen): return true
  case (.leftBrace, .leftBrace): return true
  case (.rightBrace, .rightBrace): return true
  case (.leftBracket, .leftBracket): return true
  case (.rightBracket, .rightBracket): return true
  case (.comma, .comma): return true
  case (.colon, .colon): return true
  case (.arrow, .arrow): return true
  case (.ellipsis, .ellipsis): return true
  case (.dot, .dot): return true
  case (.questionMark, .questionMark): return true
  case (.func, .func): return true
  case (.Init, .Init): return true
  case (.deinit, .deinit): return true
  case (.extension, .extension): return true
  case (.sizeOf, .sizeOf): return true
  case (.type, .type): return true
  case (.while, .while): return true
  case (.for, .for): return true
  case (.nil, .nil): return true
  case (.if, .if): return true
  case (.in, .in): return true
  case (.else, .else): return true
  case (.var, .var): return true
  case (.let, .let): return true
  case (.return, .return): return true
  case (.case, .case): return true
  case (.switch, .switch): return true
  case (.default, .default): return true
  case (.break, .break): return true
  case (.continue, .continue): return true
  case (.true, .true): return true
  case (.false, .false): return true
  case (.eof, .eof): return true
  case (.poundFunction, .poundFunction): return true
  case (.poundFile, .poundFile): return true
  case (.poundLine, .poundLine): return true
  case (.poundWarning, .poundWarning): return true
  case (.poundError, .poundError): return true
  case (.underscore, .underscore): return true
  default: return false
  }
}

struct Token {
  let kind: TokenKind
  let range: SourceRange
  
  var length: Int {
    return range.end.charOffset - range.start.charOffset
  }
  
  var isKeyword: Bool { return kind.isKeyword }
  var isLiteral: Bool { return kind.isLiteral }
  var isString: Bool { return kind.isString }
  var isLineSeparator: Bool { return kind.isLineSeparator }
  var isEOF: Bool { return kind.isEOF }
}

extension UnicodeScalar {
  static let operatorChars: Set<UnicodeScalar> = Set("~*+-/<>=%^|&!".unicodeScalars)
  var isNumeric: Bool {
    return isnumber(Int32(self.value)) != 0
  }
  var isSpace: Bool {
    return isspace(Int32(self.value)) != 0 && self != "\n"
  }
  var isLineSeparator: Bool {
    return self == "\n" || self == ";"
  }
  var isIdentifier: Bool {
    return isalnum(Int32(self.value)) != 0 || self == "_"
  }
  var isOperator: Bool {
    return UnicodeScalar.operatorChars.contains(self)
  }
  var isHexadecimal: Bool {
    return ishexnumber(Int32(self.value)) != 0
  }
}

enum LexError: Error, CustomStringConvertible {
  case invalidCharacter(char: UnicodeScalar)
  case invalidCharacterLiteral(literal: String)
  case invalidEscape(escapeChar: UnicodeScalar)
  case unexpectedEOF
  var description: String {
    switch self {
    case .invalidCharacter(let char):
      return "invalid character \(char) in source file"
    case .invalidCharacterLiteral(let literal):
      return "invalid character literal '\(literal)' in source file"
    case .invalidEscape(let escapeChar):
      return "invalid character escape '\(escapeChar)'"
    case .unexpectedEOF:
      return "unexpected EOF"
    }
  }
}

class Lexer {
  var sourceLoc = SourceLocation(line: 1, column: 1)
  var characters = [UnicodeScalar]()
  var tokenIndex = 0
  
  func range(start: SourceLocation) -> SourceRange {
    return SourceRange(start: start, end: sourceLoc)
  }
  
  init(input: String) {
    characters = Array(input.unicodeScalars)
  }
  
  func lex() throws -> [Token] {
    var tokens = [Token]()
    while true {
      do {
        let tok = try advanceToNextToken()
        if case .eof = tok.kind {
          break
        }
        tokens.append(tok)
      } catch {
        throw Diagnostic.error(error, loc: sourceLoc)
      }
    }
    return tokens
  }
  
  func advance(_ n: Int = 1) {
    guard let c = currentChar() else { return }
    for _ in 0..<n {
      if c == "\n" {
        sourceLoc.line += 1
        sourceLoc.column = 1
      } else {
        sourceLoc.column += 1
      }
      sourceLoc.charOffset += 1
      tokenIndex += 1
    }
  }
  
  func currentChar() -> UnicodeScalar? {
    return charAt(0)
  }
  
  func charAt(_ index: Int) -> UnicodeScalar? {
    guard tokenIndex + index < characters.endIndex else { return nil }
    return characters[tokenIndex + index]
  }
  
  func currentSubstring(_ length: Int) -> String {
    var s = ""
    for index in 0..<length {
      guard let c = charAt(index) else { continue }
      s.append(String(c))
    }
    return s
  }
  
  func advanceIf(_ f: (UnicodeScalar) -> Bool, perform: () -> Void = {}) -> Bool {
    guard let c = currentChar() else { return false }
    if f(c) {
      perform()
      advance()
      return true
    }
    return false
  }
  
  func advanceWhile(_ f: (UnicodeScalar) -> Bool, perform: () -> Void = {}) {
    while advanceIf(f, perform: perform) {}
  }
  
  func collectWhile(_ f: (UnicodeScalar) -> Bool) -> String {
    var s = ""
    advanceWhile(f) {
      guard let c = currentChar() else { return }
      s.append(String(c))
    }
    return s
  }
  
  func readCharacter() throws -> UnicodeScalar {
    if currentChar() == "\\" {
      advance()
      switch currentChar() {
      case "n"?:
        advance()
        return "\n" as UnicodeScalar
      case "t"?:
        advance()
        return "\t" as UnicodeScalar
      case "r"?:
        advance()
        return "\r" as UnicodeScalar
      case "x"?:
        advance()
        guard currentChar() == "{" else {
          throw LexError.invalidCharacter(char: currentChar()!)
        }
        advance()
        let literal = collectWhile { $0.isHexadecimal }
        guard currentChar() == "}" else {
          throw LexError.invalidCharacter(char: currentChar()!)
        }
        advance()
        guard let lit = UInt8(literal, radix: 16) else {
          throw LexError.invalidCharacterLiteral(literal: "\\x{\(literal)}")
        }
        return UnicodeScalar(lit)
      case "\""?:
        advance()
        return "\"" as UnicodeScalar
      default:
        throw LexError.invalidEscape(escapeChar: currentChar()!)
      }
    } else if let c = currentChar() {
      advance()
      return c
    } else {
      throw LexError.unexpectedEOF
    }
  }
  
  func advanceToNextToken() throws -> Token {
    advanceWhile({ $0.isSpace })
    guard let c = currentChar() else {
      return Token(kind: .eof, range: range(start: sourceLoc))
    }
    if c == "\n" {
      defer { advanceWhile({ $0.isSpace || $0.isLineSeparator }) }
      return Token(kind: .newline, range: range(start: sourceLoc))
    }
    
    if c == ";" {
      defer { advanceWhile({ $0.isSpace || $0.isLineSeparator }) }
      return Token(kind: .semicolon, range: range(start: sourceLoc))
    }
    
    // skip comments
    if c == "/" {
      if charAt(1) == "/" {
        advanceWhile({
          return $0 != "\n"
        })
        return try advanceToNextToken()
      } else if charAt(1) == "*" {
        advanceWhile({ _ in
          return currentSubstring(2) != "*/"
        })
        advance()
        advance()
        return try advanceToNextToken()
      }
    }
    
    let startLoc = sourceLoc
    if c == "'" {
      advance()
      let scalar = try readCharacter()
      let value = UInt8(scalar.value & 0xff)
      guard currentChar() == "'" else {
        throw LexError.invalidCharacterLiteral(literal: "\(value)")
      }
      advance()
      return Token(kind: .char(value: value), range: range(start: startLoc))
    }
    if c == "\"" {
      advance()
      var str = ""
      while currentChar() != "\"" {
        str.append(String(try readCharacter()))
      }
      advance()
      return Token(kind: .stringLiteral(value: str), range: range(start: startLoc))
    }
    if c.isIdentifier {
      let id = collectWhile { $0.isIdentifier }
      if let numVal = id.asNumber() {
        return Token(kind: .number(value: numVal, raw: id), range: range(start: startLoc))
      } else {
        return Token(kind: TokenKind(identifier: id), range: range(start: startLoc))
      }
    }
    if currentSubstring(3) == "..." {
      advance(3)
      return Token(kind: .ellipsis, range: range(start: startLoc))
    }
    if c == "[" {
      advance()
      return Token(kind: .leftBracket, range: range(start: startLoc))
    }
    if c == "]" {
      advance()
      return Token(kind: .rightBracket, range: range(start: startLoc))
    }
    if c == "#" {
      advance()
      let id = collectWhile { $0.isIdentifier }
      return Token(kind: TokenKind(identifier: "#\(id)"), range: range(start: startLoc))
    }
    if c.isOperator {
      let opStr = collectWhile { $0.isOperator }
      if let op = BuiltinOperator(rawValue: opStr) {
        return Token(kind: .operator(op: op), range: range(start: startLoc))
      } else {
        return Token(kind: TokenKind(op: opStr), range: range(start: startLoc))
      }
    }
    advance()
    return Token(kind: TokenKind(op: String(c)), range: range(start: startLoc))
  }
}

extension String {
  func removing(_ string: String) -> String {
    return self.replacingOccurrences(of: string, with: "")
  }
  
  func asNumber() -> IntMax? {
    let prefixMap = ["0x": 16, "0b": 2, "0o": 8]
    if characters.count <= 2 {
      return IntMax(self, radix: 10)
    }
    let prefix = substring(to: characters.index(startIndex, offsetBy: 2))
    guard let radix = prefixMap[prefix] else {
      return IntMax(removing("_"), radix: 10)
    }
    let suffix = removing("_").substring(from: characters.index(startIndex, offsetBy: 2))
    return IntMax(suffix, radix: radix)
  }
  
  func escaped() -> String {
    var s = ""
    for c in characters {
      switch c {
      case "\n": s += "\\n"
      case "\t": s += "\\t"
      case "\"": s += "\\\""
      default: s.append(c)
      }
    }
    return s
  }
  
  func unescaped() -> String {
    var s = ""
    var nextCharIsEscaped = false
    for c in characters {
      if c == "\\" {
        nextCharIsEscaped = true
        continue
      }
      if nextCharIsEscaped {
        switch c {
        case "n": s.append("\n")
        case "t": s.append("\t")
        case "\"": s.append("\"")
        default: s.append(c)
        }
      } else {
        s.append(c)
      }
      nextCharIsEscaped = false
    }
    return s
  }
}
