//
//  Type.swift
//  Trill
//

import Foundation

enum FloatingPointType {
  case float, double, float80
}

enum DataType: CustomStringConvertible, Hashable {
  case int(width: Int)
  case floating(type: FloatingPointType)
  case bool
  case void
  case custom(name: String)
  case any
  indirect case function(args: [DataType], returnType: DataType)
  indirect case pointer(type: DataType)
  indirect case tuple(fields: [DataType])
  
  static let int64 = DataType.int(width: 64)
  static let int32 = DataType.int(width: 32)
  static let int16 = DataType.int(width: 16)
  static let int8 = DataType.int(width: 8)
  static let float = DataType.floating(type: .float)
  static let double = DataType.floating(type: .double)
  static let float80 = DataType.floating(type: .float80)
  
  init(name: String) {
    switch name {
    case "Int8": self = .int8
    case "Int16": self = .int16
    case "Int32": self = .int32
    case "Int": self = .int64
    case "Bool": self = .bool
    case "Void": self = .void
    case "Float": self = .float
    case "Double": self = .double
    case "Float80": self = .float80
    case "Any": self = .any
    default: self = .custom(name: name)
    }
  }
  
  var rootType: DataType {
    guard case .pointer(let type) = self else { return self }
    return type.rootType
  }
  
  var description: String {
    switch self {
    case .int(width: 64): return "Int"
    case .int(let width): return "Int\(width)"
    case .bool: return "Bool"
    case .void: return "Void"
    case .custom(let name): return name
    case .pointer(let type):
      return "*\(type)"
    case .floating(let type):
      switch type {
      case .float:
        return "Float"
      case .double:
        return "Double"
      case .float80:
        return "Float80"
      }
    case .tuple(let fields):
      return "(\(fields.map { $0.description }.joined(separator: ", ")))"
    case .function(let args, let ret):
      let args = args.map { $0.description }.joined(separator: ", ")
      return "(\(args)) -> \(ret)"
    case .any: return "Any"
    }
  }
  
  var hashValue: Int {
    return self.description.hashValue ^ 0x09ad3f14
  }
  
  var isPointer: Bool {
    if case .pointer = self { return true }
    return false
  }
  
  func pointerLevel() -> Int {
    guard case .pointer(let t) = self else { return 0 }
    return t.pointerLevel() + 1
  }
  
  func canCoerceTo(_ type: DataType) -> Bool {
    if self == type { return true }
    switch (self, type) {
    case (.int, .int): return true
    case (.int, .floating): return true
    case (.floating, .int): return true
    case (.int, .pointer): return true
    case (.pointer, .int): return true
    case (.pointer, .pointer): return true
    default: return false
    }
  }
}

func ==(lhs: DataType, rhs: DataType) -> Bool {
  switch (lhs, rhs) {
  case (.int(let width), .int(let otherWidth)): return width == otherWidth
  case (.bool, .bool): return true
  case (.void, .void): return true
  case (.custom(let lhsName), .custom(let rhsName)):
    return lhsName == rhsName
  case (.pointer(let lhsType), .pointer(let rhsType)):
    return lhsType == rhsType
  case (.floating(let double), .floating(let rhsDouble)):
    return double == rhsDouble
  case (.any, .any): return true
  case (.function(let args, let ret), .function(let args2, let ret2)):
    return args == args2 && ret == ret2
  case (.tuple(let fields), .tuple(let fields2)):
    return fields == fields2
  default: return false
  }
}

class DeclExpr: BindingExpr {
  var type: DataType
  let attributes: Set<DeclAttribute>
  func has(attribute: DeclAttribute) -> Bool {
    return attributes.contains(attribute)
  }
  init(name: Identifier, type: DataType, attributes: [DeclAttribute], sourceRange: SourceRange?) {
    self.type = type
    self.attributes = Set(attributes)
    super.init(name: name, sourceRange: sourceRange)
  }
}

class TypeDeclExpr: DeclExpr {
  private(set) var fields: [VarAssignExpr]
  private(set) var methods = [FuncDeclExpr]()
  private(set) var initializers = [FuncDeclExpr]()
  private var fieldDict = [String: DataType]()
  private var methodDict = [String: [FuncDeclExpr]]()
  
  let deinitializer: FuncDeclExpr?
  
  func indexOf(fieldName: Identifier) -> Int? {
    return fields.index { field in
      field.name == fieldName
    }
  }
  
  func addInitializer(_ expr: FuncDeclExpr) {
    self.initializers.append(expr)
  }
  
  func addMethod(_ expr: FuncDeclExpr, named name: String) {
    let decl = expr.hasImplicitSelf ? expr : expr.addingImplicitSelf(self.type)
    self.methods.append(decl)
    var methods = methodDict[name] ?? []
    methods.append(decl)
    methodDict[name] = methods
  }
  
  func addField(_ field: VarAssignExpr) {
    fields.append(field)
    fieldDict[field.name.name] = field.type
  }
  
  func methods(named name: String) -> [FuncDeclExpr] {
    return methodDict[name] ?? []
  }
  
  func field(named name: String) -> VarAssignExpr? {
    for field in fields where field.name.name == name { return field }
    return nil
  }
  
  func typeOf(_ field: String) -> DataType? {
    return fieldDict[field]
  }
  
  func createRef() -> TypeRefExpr {
    return TypeRefExpr(type: self.type, name: self.name)
  }
  
  static func synthesizeInitializer(fields: [VarAssignExpr], name: Identifier, attributes: [DeclAttribute]) -> FuncDeclExpr {
    let type = DataType(name: name.name)
    let typeRef = TypeRefExpr(type: type, name: name)
    let initFields = fields.map { field in
      FuncArgumentAssignExpr(name: field.name, type: field.typeRef, externalName: field.name)
    }
    return FuncDeclExpr(
      name: name,
      returnType: typeRef,
      args: initFields,
      kind: .initializer(type: type),
      body: CompoundExpr(exprs: []),
      attributes: attributes)
  }
  
  init(name: Identifier,
       fields: [VarAssignExpr],
       methods: [FuncDeclExpr] = [],
       initializers: [FuncDeclExpr] = [],
       attributes: [DeclAttribute] = [],
       deinit: FuncDeclExpr? = nil,
       sourceRange: SourceRange? = nil) {
    self.fields = fields
    self.initializers = initializers
    let type = DataType(name: name.name)
    self.deinitializer = `deinit`?.addingImplicitSelf(type)
    let synthInit = TypeDeclExpr.synthesizeInitializer(fields: fields,
                                                       name: name,
                                                       attributes: attributes)
    self.initializers.append(synthInit)
    super.init(name: name, type: type,
               attributes: attributes, sourceRange: sourceRange)
    for method in methods {
      self.addMethod(method, named: method.name.name)
    }
    for field in fields {
      fieldDict[field.name.name] = field.type
    }
  }
  
  var isIndirect: Bool {
    return has(attribute: .indirect)
  }
  
  override func equals(_ rhs: Expr) -> Bool {
    guard let rhs = rhs as? TypeDeclExpr else { return false }
    guard type == rhs.type else { return false }
    guard fields == rhs.fields else { return false }
    guard methods == rhs.methods else { return false }
    return true
  }
}

class TypeAliasExpr: DeclRefExpr<TypeDeclExpr> {
  let name: Identifier
  let bound: TypeRefExpr
  init(name: Identifier, bound: TypeRefExpr, sourceRange: SourceRange? = nil) {
    self.name = name
    self.bound = bound
    super.init(sourceRange: sourceRange)
  }
  override func equals(_ rhs: Expr) -> Bool {
    guard let rhs = rhs as? TypeAliasExpr else { return false }
    return name == rhs.name && bound == rhs.bound
  }
}

class DeclRefExpr<DeclType: DeclExpr>: ValExpr {
  weak var decl: DeclType? = nil
  override init(sourceRange: SourceRange?) {
    super.init(sourceRange: sourceRange)
  }
}

class TypeRefExpr: DeclRefExpr<TypeDeclExpr> {
  let name: Identifier
  init(type: DataType, name: Identifier, sourceRange: SourceRange? = nil) {
    self.name = name
    super.init(sourceRange: sourceRange)
    self.type = type
  }
}

extension DataType {
  func ref() -> TypeRefExpr {
    return TypeRefExpr(type: self, name: Identifier(name: "\(self)"))
  }
}

class FuncTypeRefExpr: TypeRefExpr {
  let argNames: [TypeRefExpr]
  let retName: TypeRefExpr
  init(argNames: [TypeRefExpr], retName: TypeRefExpr, sourceRange: SourceRange? = nil) {
    self.argNames = argNames
    self.retName = retName
    let argTypes = argNames.map { $0.type! }
    let argStrings = argNames.map { $0.name.name }
    var fullName = "(" + argStrings.joined(separator: ", ") + ")"
    if retName != .void {
      fullName += " -> " + retName.name.name
    }
    let fullId = Identifier(name: fullName, range: sourceRange)
    super.init(type: .function(args: argTypes, returnType: retName.type!), name: fullId, sourceRange: sourceRange)
  }
}

class PointerTypeRefExpr: TypeRefExpr {
  let pointed: TypeRefExpr
  init(pointedTo: TypeRefExpr, level: Int, sourceRange: SourceRange? = nil) {
    self.pointed = pointedTo
    let fullName = String(repeating: "*", count: level) + pointedTo.name.name
    let fullId = Identifier(name: fullName, range: sourceRange)
    var type = pointedTo.type!
    for _ in 0..<level {
      type = .pointer(type: type)
    }
    super.init(type: type, name: fullId, sourceRange: sourceRange)
  }
}

class TupleTypeRefExpr: TypeRefExpr {
  let fieldNames: [TypeRefExpr]
  init(fieldNames: [TypeRefExpr], sourceRange: SourceRange? = nil) {
    self.fieldNames = fieldNames
    let argTypes = fieldNames.map { $0.type! }
    let fullName = "(\(fieldNames.map { $0.name.name }.joined(separator: ", ")))"
    super.init(type: .tuple(fields: argTypes),
               name: Identifier(name: fullName, range: sourceRange),
               sourceRange: sourceRange)
  }
}

func ==(lhs: TypeRefExpr, rhs: DataType) -> Bool {
  return lhs.type == rhs
}
func !=(lhs: TypeRefExpr, rhs: DataType) -> Bool {
  return lhs.type != rhs
}
func ==(lhs: DataType, rhs: TypeRefExpr) -> Bool {
  return lhs == rhs.type
}
func !=(lhs: DataType, rhs: TypeRefExpr) -> Bool {
  return lhs != rhs.type
}

class FieldLookupExpr: ValExpr {
  let lhs: ValExpr
  var decl: Expr? = nil
  var typeDecl: TypeDeclExpr? = nil
  let name: Identifier
  init(lhs: ValExpr, name: Identifier, sourceRange: SourceRange? = nil) {
    self.lhs = lhs
    self.name = name
    super.init(sourceRange: sourceRange)
  }
  override func equals(_ rhs: Expr) -> Bool {
    guard let rhs = rhs as? FieldLookupExpr else { return false }
    guard name == rhs.name else { return false }
    guard lhs == rhs.lhs else { return false }
    return true
  }
}

