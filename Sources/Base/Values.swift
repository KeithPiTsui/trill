//
//  Value.swift
//  Trill
//

import Foundation

class Expr: ASTNode {
  var type: DataType? = nil
  override func attributes() -> [String : Any] {
    var attrs = super.attributes()
    if let type = type {
      attrs["type"] = "\(type)"
    }
    return attrs
  }
}

class ConstantExpr: Expr {
  override init(sourceRange: SourceRange? = nil) {
    super.init(sourceRange: sourceRange)
  }
  var text: String { return "" }
}

class VoidExpr: Expr {
  override init(sourceRange: SourceRange? = nil) {
    super.init(sourceRange: sourceRange)
    self.type = .void
  }
  override func equals(_ node: ASTNode) -> Bool {
    return node is VoidExpr
  }
}

class NilExpr: Expr {
  override init(sourceRange: SourceRange? = nil) {
    super.init(sourceRange: sourceRange)
    self.type = .pointer(type: .int8)
  }
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? NilExpr else { return false }
    return node.type == type
  }
}

class NumExpr: ConstantExpr { // 1234567
  let value: IntMax
  let raw: String
  init(value: IntMax, raw: String, sourceRange: SourceRange? = nil) {
    self.value = value
    self.raw = raw
    super.init(sourceRange: sourceRange)
    self.type = .int64
  }
  override var text: String {
    return raw
  }
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? NumExpr else { return false }
    return value == node.value
  }
  override func attributes() -> [String : Any] {
    var superAttrs = super.attributes()
    superAttrs["value"] = value
    superAttrs["raw"] = raw
    return superAttrs
  }
}

class ParenExpr: Expr {
  let value: Expr
  init(value: Expr, sourceRange: SourceRange? = nil) {
    self.value = value
    super.init(sourceRange: sourceRange)
  }
  
  var rootExpr: Expr {
    if let paren = value as? ParenExpr {
      return paren.rootExpr
    }
    return value
  }
  
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? ParenExpr else { return false }
    return value == node.value
  }
}

class TupleExpr: Expr {
  let values: [Expr]
  init(values: [Expr], sourceRange: SourceRange? = nil) {
    self.values = values
    super.init(sourceRange: sourceRange)
  }
  
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? TupleExpr else { return false }
    return values == node.values
  }
}

class ArrayExpr: Expr {
  let values: [Expr]
  init(values: [Expr], sourceRange: SourceRange? = nil) {
    self.values = values
    super.init(sourceRange: sourceRange)
  }
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? ArrayExpr else { return false }
    return values == node.values
  }
}

class TupleFieldLookupExpr: Expr {
  let lhs: Expr
  var decl: ASTNode? = nil
  let field: Int
  let fieldRange: SourceRange
  init(lhs: Expr, field: Int, fieldRange: SourceRange, sourceRange: SourceRange? = nil) {
    self.lhs = lhs
    self.field = field
    self.fieldRange = fieldRange
    super.init(sourceRange: sourceRange)
  }
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? TupleFieldLookupExpr else { return false }
    guard field == node.field else { return false }
    guard lhs == node.lhs else { return false }
    return true
  }
  
  override func attributes() -> [String : Any] {
    var superAttrs = super.attributes()
    superAttrs["field"] = field
    return superAttrs
  }
}

class FloatExpr: ConstantExpr {
  override var type: DataType? {
    get { return .double } set { }
  }
  let value: Double
  let raw: String
  init(value: Double, raw: String, sourceRange: SourceRange? = nil) {
    self.value = value
    self.raw = raw
    super.init(sourceRange: sourceRange)
  }
  override var text: String {
    return raw
  }
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? FloatExpr else { return false }
    return value == node.value
  }
  override func attributes() -> [String : Any] {
    var superAttrs = super.attributes()
    superAttrs["value"] = value
    superAttrs["raw"] = raw
    return superAttrs
  }
}

class BoolExpr: ConstantExpr {
  override var type: DataType? {
    get { return .bool } set { }
  }
  let value: Bool
  init(value: Bool, sourceRange: SourceRange? = nil) {
    self.value = value
    super.init(sourceRange: sourceRange)
  }
  override var text: String {
    return "\(value)"
  }
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? BoolExpr else { return false }
    return value == node.value
  }
  override func attributes() -> [String : Any] {
    var superAttrs = super.attributes()
    superAttrs["value"] = value
    return superAttrs
  }
}

class StringExpr: ConstantExpr {
  override var type: DataType? {
    get { return .pointer(type: .int8) } set { }
  }
  var value: String
  init(value: String, sourceRange: SourceRange? = nil) {
    self.value = value
    super.init(sourceRange: sourceRange)
  }
  override var text: String {
    return value
  }
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? StringExpr else { return false }
    return value == node.value
  }
  override func attributes() -> [String : Any] {
    var superAttrs = super.attributes()
    superAttrs["value"] = value
    return superAttrs
  }
}

class PoundFunctionExpr: StringExpr {
  init(sourceRange: SourceRange? = nil) {
    super.init(value: "", sourceRange: sourceRange)
  }
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? PoundFunctionExpr else { return false }
    return value == node.value
  }
  override func attributes() -> [String : Any] {
    var superAttrs = super.attributes()
    superAttrs["value"] = value
    return superAttrs
  }
}

class CharExpr: ConstantExpr {
  override var type: DataType? {
    get { return .int8 } set { }
  }
  let value: UInt8
  init(value: UInt8, sourceRange: SourceRange? = nil) {
    self.value = value
    super.init(sourceRange: sourceRange)
  }
  override var text: String {
    return "\(value)"
  }
  
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? CharExpr else { return false }
    return value == node.value
  }
  override func attributes() -> [String : Any] {
    var superAttrs = super.attributes()
    superAttrs["value"] = value
    return superAttrs
  }
}

protocol LValue {}

class VarExpr: Expr, LValue {
  let name: Identifier
  var isTypeVar = false
  var isSelf = false
  var decl: Decl? = nil
  init(name: Identifier, sourceRange: SourceRange? = nil) {
    self.name = name
    super.init(sourceRange: sourceRange)
  }
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? VarExpr else { return false }
    return name == node.name
  }
  override func attributes() -> [String : Any] {
    var superAttrs = super.attributes()
    superAttrs["name"] = name.name
    if isTypeVar {
      superAttrs["isTypeVar"] = true
    }
    return superAttrs
  }
}

class SizeofExpr: Expr {
  var value: Expr?
  var valueType: DataType?
  init(value: Expr, sourceRange: SourceRange? = nil) {
    self.value = value
    super.init(sourceRange: sourceRange)
    self.type = .int64
  }
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? SizeofExpr else { return false }
    return value == node.value
  }
}

class SubscriptExpr: FuncCallExpr, LValue {}

class FieldLookupExpr: Expr, LValue {
  let lhs: Expr
  var decl: ASTNode? = nil
  var typeDecl: TypeDecl? = nil
  let name: Identifier
  init(lhs: Expr, name: Identifier, sourceRange: SourceRange? = nil) {
    self.lhs = lhs
    self.name = name
    super.init(sourceRange: sourceRange)
  }
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? FieldLookupExpr else { return false }
    guard name == node.name else { return false }
    guard lhs == node.lhs else { return false }
    return true
  }
  
  
  override func attributes() -> [String : Any] {
    var superAttrs = super.attributes()
    superAttrs["fieldName"] = name.name
    return superAttrs
  }
}

class TernaryExpr: Expr {
  let condition: Expr
  let trueCase: Expr
  let falseCase: Expr
  init(condition: Expr, trueCase: Expr, falseCase: Expr, sourceRange: SourceRange? = nil) {
    self.condition = condition
    self.trueCase = trueCase
    self.falseCase = falseCase
    super.init(sourceRange: sourceRange)
  }
  override func equals(_ node: ASTNode) -> Bool {
    guard let node = node as? TernaryExpr else { return false }
    return condition == node.condition && trueCase == node.trueCase && falseCase == node.falseCase
  }
}
