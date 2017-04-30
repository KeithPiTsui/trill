///
/// Types.swift
///
/// Copyright 2016-2017 the Trill project authors.
/// Licensed under the MIT License.
///
/// Full license text available at https://github.com/trill-lang/trill
///

import Foundation
import Source

public enum FloatingPointType {
  case float, double, float80
}

public enum DataType: CustomStringConvertible, Hashable {
  /// A signed or unsigned integer type of an arbitrary width.
  case int(width: Int, signed: Bool)

  /// A floating-point type of one of the types specified in `FloatingPointType`
  case floating(FloatingPointType)

  /// A boolean value, either true or false.
  case bool

  /// A type representing nothing
  case void

  /// A named structure type.
  case custom(String)

  /// A type variable that must be reified to a concrete type.
  case typeVariable(String)

  /// The default type. This should not survive past semantic analysis.
  case error

  /// A data type representing a floating-point literal that hasn't been
  /// resolved to a concrete floating-point type.
  case floatingLiteral

  /// A data type representing a string literal that hasn't been resolved to
  /// a concrete String or *Int8 type.
  case stringLiteral

  /// A data type representing an integer literal that hasn't been resolved to
  /// a concrete integer type.
  case integerLiteral

  /// A data type representing a `nil` literal that hasn't been resolved to
  /// an `indirect` or reference type.
  case nilLiteral

  /// A function from <params> -> <returnType>
  indirect case function(args: [DataType], returnType: DataType, hasVarArgs: Bool)

  /// A pointer to a specified type.
  indirect case pointer(DataType)

  /// An explicitly-sized array of a given type.
  indirect case array(DataType, length: Int?)

  /// A tuple of arbitrary fields.
  indirect case tuple([DataType])

  indirect case protocolComposition([DataType])

  /// A special type that can encompass any value. Represented as the
  /// composition of 0 protocols.
  static let any = DataType.protocolComposition([])

  /// A 64-bit signed integer type.
  public static let int64 = DataType.int(width: 64, signed: true)

  /// A 32-bit signed integer type.
  public static let int32 = DataType.int(width: 32, signed: true)

  /// A 16-bit signed integer type.
  public static let int16 = DataType.int(width: 16, signed: true)

  /// An 8-bit signed integer type.
  public static let int8 = DataType.int(width: 8, signed: true)

  /// A 64-bit unsigned integer type.
  public static let uint64 = DataType.int(width: 64, signed: false)

  /// A 32-bit unsigned integer type.
  public static let uint32 = DataType.int(width: 32, signed: false)

  /// A 16-bit unsigned integer type.
  public static let uint16 = DataType.int(width: 16, signed: false)

  /// An 8-bit unsigned integer type.
  public static let uint8 = DataType.int(width: 8, signed: false)

  /// A 32-bit floating-point type.
  public static let float = DataType.floating(type: .float)

  /// A 64-bit floating-point type.
  public static let double = DataType.floating(type: .double)

  /// An 80-bit floating-point type.
  public static let float80 = DataType.floating(type: .float80)

  /// An array type with no explicit length.
  public static func incompleteArray(field: DataType) -> DataType {
    return .array(field: field, length: nil)
  }

  /// The standard-library String type.
  public static let string = DataType.custom(name: "String")

  /// Creates a type from a parsed identifier.
  public init(name: String) {
    switch name {
    case "Int8": self = .int8
    case "Int16": self = .int16
    case "Int32": self = .int32
    case "Int": self = .int64
    case "UInt8": self = .uint8
    case "UInt16": self = .uint16
    case "UInt32": self = .uint32
    case "UInt": self = .uint64
    case "Bool": self = .bool
    case "Void": self = .void
    case "Float": self = .float
    case "Double": self = .double
    case "Float80": self = .float80
    case "Any": self = .any
    default: self = .custom(name)
    }
  }

  /// If this is a container type of one other type, this returns the
  /// contained type.
  public var elementType: DataType {
    switch self {
    case .array(let field, _):
      return field
    case .pointer(let type):
      return type.elementType
    default:
      return self
    }
  }

  /// Determine if a type is cyclically dependent on itself.
  public func contains(_ x: String) -> Bool {
    switch self {
    case let .function(args, returnType, _):
      return args.reduce(false, { (acc, t) in acc || t.contains(x) })
          || returnType.contains(x)
    case let .tuple(fields):
      return fields.reduce(false, { (acc, t) in acc || t.contains(x) })
    case let .pointer(pointee):
      return pointee.contains(x)
    case let .array(field, _):
      return field.contains(x)
    case let .typeVariable(name):
      return name == x
    case let .protocolComposition(types):
      return types.contains { $0.contains(x) }
    default:
      return false
    }
  }

  /// The type that a Literal type should fall back to if it doesn't
  /// get replaced by context.
  var literalFallback: DataType {
    switch self {
    case .integerLiteral:
      return .int64
    case .floatingLiteral:
      return .double
    case .stringLiteral:
      return .string
    default:
      return self
    }
  }

  /// Pretty-prints the receiver.
  public var description: String {
    switch self {
    case .integerLiteral: return "IntegerLiteral"
    case .floatingLiteral: return "FloatingLiteral"
    case .stringLiteral: return "StringLiteral"
    case .nilLiteral: return "NilLiteral"
    case .int(width: 64, let signed):
      return "\(signed ? "" : "U")Int"
    case .int(let width, let signed):
      return "\(signed ? "" : "U")Int\(width)"
    case .bool: return "Bool"
    case .void: return "Void"
    case .array(let field, let length):
      var s = "[\(field)"
      if let length = length {
        s += "; \(length)"
      }
      return s + "]"
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
    case .function(let args, let ret, let hasVarArgs):
      var argValues = args.map { $0.description }
      if hasVarArgs {
        argValues.append("...")
      }
      let args = argValues.joined(separator: ", ")
      return "(\(args)) -> \(ret)"
    case .protocolComposition(let types):
      if types.isEmpty { return "Any" }
      return types.map { $0.description }.joined(separator: " & ")
    case .typeVariable(let name): return name
    case .error: return "<<error type>>"
    }
  }

  public var hashValue: Int {
    return self.description.hashValue ^ 0x09ad3f14
  }

  public var isPointer: Bool {
    if case .pointer = self { return true }
    return false
  }

  public var isFunction: Bool {
    if case .function = self { return true }
    return false
  }

  public func pointerLevel() -> Int {
    guard case .pointer(let t) = self else { return 0 }
    return t.pointerLevel() + 1
  }

  public func canCoerceTo(_ type: DataType) -> Bool {
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

<<<<<<< HEAD:Sources/AST/Types.swift
  public var freeTypeVariables : [String] {
    switch self {
    case let .array(fields, _):
      return fields.freeTypeVariables
    case let .function(args, returnType, _):
      return args.flatMap({ $0.freeTypeVariables }) + returnType.freeTypeVariables
    case let .pointer(type):
      return type.freeTypeVariables
    case let .tuple(fields):
      return fields.flatMap({ $0.freeTypeVariables })
    case let .typeVariable(name):
      return [name]
    case let .protocolComposition(types):
      return types.flatMap { $0.freeTypeVariables }
    default:
      return []
    }
  }

  public func substitute(_ s: [String: DataType]) -> DataType {
    switch self {
    case let .array(fields, l):
      return .array(fields.substitute(s), length: l)
    case let .function(args, returnType, hasVarArgs):
      return .function(args: args.map { $0.substitute(s) },
                       returnType: returnType.substitute(s),
                       hasVarArgs: hasVarArgs)
    case let .pointer(type):
      return .pointer(type.substitute(s))
    case let .tuple(fields):
      return .tuple(fields.map { $0.substitute(s) })
    case let .typeVariable(n):
      // If it's a type variable, look it up in the substitution map to
      // find a replacement.
      if let t = s[n] {
        // If we get replaced with ourself we've reached the desired fixpoint.
        if t == self {
          return t
        }
        // Otherwise keep substituting.
        return t.substitute(s)
      }
      return self
    case let .protocolComposition(types):
      return .protocolComposition(types.map { $0.substitute(s) })
    default:
      return self
    }
  }

  public func substitute(_ name : String, for type: DataType) -> DataType {
    switch self {
    case let .array(fields, l):
      return .array(fields.substitute(name, for: type), length: l)
    case let .function(args, returnType, hasVarArgs):
      return .function(args: args.map { $0.substitute(name, for: type) },
                       returnType: returnType.substitute(name, for: type),
                       hasVarArgs: hasVarArgs)
    case let .pointer(type):
      return .pointer(type.substitute(name, for: type))
    case let .tuple(fields):
      return .tuple(fields.map { $0.substitute(name, for: type) })
    case let .typeVariable(tvn):
      if tvn == name {
        return type
      }
      return self
    case let .protocolComposition(types):
      return .protocolComposition(types.map { $0.substitute(name, for: type) })
    default:
      fatalError()
    }
  }

  public static func ==(lhs: DataType, rhs: DataType) -> Bool {
    switch (lhs, rhs) {
    case (.integerLiteral, .integerLiteral): return true
    case (.floatingLiteral, .floatingLiteral): return true
    case (.stringLiteral, .stringLiteral): return true
    case (.int(let width, let signed), .int(let otherWidth, let otherSigned)):
      return width == otherWidth && signed == otherSigned
    case (.bool, .bool): return true
    case (.void, .void): return true
    case (.custom(let lhsName), .custom(let rhsName)):
      return lhsName == rhsName
    case (.pointer(let lhsType), .pointer(let rhsType)):
      return lhsType == rhsType
    case (.floating(let double), .floating(let rhsDouble)):
      return double == rhsDouble
    case (.array(let field, _), .array(let field2, _)):
      return field == field2
    case (.function(let args, let ret, let hasVarArgs),
          .function(let args2, let ret2, let hasVarArgs2)):
      return args == args2 && ret == ret2 && hasVarArgs == hasVarArgs2
    case (.tuple(let fields), .tuple(let fields2)):
      return fields == fields2
    case (.typeVariable(let name1), .typeVariable(let name2)):
      return name1 == name2
    case let (.protocolComposition(types1), .protocolComposition(types2)):
      return types1 == types2
    default: return false
    }
  }
}

public class Decl: ASTNode {
  public var type: DataType = .error
  public let modifiers: Set<DeclModifier>
  public func has(attribute: DeclModifier) -> Bool {
    return modifiers.contains(attribute)
  }
  public init(type: DataType, modifiers: [DeclModifier], sourceRange: SourceRange?) {
    self.modifiers = Set(modifiers)
    self.type = type
    super.init(sourceRange: sourceRange)
  }

  public override func attributes() -> [String : Any] {
    var attrs = super.attributes()
    attrs["type"] = "\(type)"
    if !modifiers.isEmpty {
      attrs["modifiers"] = modifiers.map { "\($0)" }.sorted().joined(separator: ", ")
    }
    return attrs
  }
}

public class TypeDecl: Decl {
  private(set) public var genericParams: [GenericParamDecl]
  private(set) public var properties: [PropertyDecl]
  private(set) public var methods = [MethodDecl]()
  private(set) public var staticMethods = [MethodDecl]()
  private(set) public var subscripts = [SubscriptDecl]()
  private(set) public var initializers = [InitializerDecl]()
  private var propertyDict = [String: DataType]()
  private var methodDict = [String: [MethodDecl]]()
  private var staticMethodDict = [String: [MethodDecl]]()
  private(set) public var conformances: [TypeRefExpr]

  public let name: Identifier
  public let deinitializer: DeinitializerDecl?

  public func indexOfProperty(named name: Identifier) -> Int? {
    return properties.lazy
                     .filter { !$0.isComputed }
                     .index { $0.name == name }
  }

  public func addInitializer(_ decl: InitializerDecl) {
    self.initializers.append(decl)
  }

  public func addMethod(_ decl: MethodDecl, named name: String) {
    self.methods.append(decl)
    var methods = methodDict[name] ?? []
    methods.append(decl)
    methodDict[name] = methods
  }

  public func addStaticMethod(_ decl: MethodDecl, named name: String) {
    self.staticMethods.append(decl)
    var methods = staticMethodDict[name] ?? []
    methods.append(decl)
    staticMethodDict[name] = methods
  }

  public func addSubscript(_ decl: SubscriptDecl) {
    self.subscripts.append(decl)
  }

  public func addProperty(_ property: PropertyDecl) {
    properties.append(property)
    propertyDict[property.name.name] = property.type
  }

  public func methods(named name: String) -> [MethodDecl] {
    return methodDict[name] ?? []
  }

  public func staticMethods(named name: String) -> [MethodDecl] {
    return staticMethodDict[name] ?? []
  }

  public func property(named name: String) -> PropertyDecl? {
    for property in properties where property.name.name == name {
      return property
    }
    return nil
  }

  public func typeOf(_ field: String) -> DataType? {
    return propertyDict[field]
  }

  public func createRef() -> TypeRefExpr {
    return TypeRefExpr(type: self.type, name: self.name)
  }

  public func methodsSatisfyingRequirements(of proto: ProtocolDecl) -> [MethodDecl] {
    return methods.filter { $0.satisfiedProtocols.contains(proto) }
  }

  public static func synthesizeInitializer(properties: [PropertyDecl],
                                           genericParams: [GenericParamDecl],
                                           type: DataType) -> InitializerDecl {
    let initProperties = properties.lazy
                                   .filter { !$0.isComputed }
                                   .map { ParamDecl(name: $0.name,
                                                    type: $0.typeRef!,
                                                    externalName: $0.name) }
    return InitializerDecl(parentType: type,
                           args: Array(initProperties),
                           genericParams: genericParams,
                           returnType: type.ref(),
                           body: CompoundStmt(stmts: []),
                           modifiers: [.implicit])
  }

  public init(name: Identifier,
              properties: [PropertyDecl],
              methods: [MethodDecl] = [],
              staticMethods: [MethodDecl] = [],
              initializers: [InitializerDecl] = [],
              subscripts: [SubscriptDecl] = [],
              modifiers: [DeclModifier] = [],
              conformances: [TypeRefExpr] = [],
              deinit: DeinitializerDecl? = nil,
              genericParams: [GenericParamDecl] = [],
              sourceRange: SourceRange? = nil) {
    self.properties = properties
    self.initializers = initializers
    let type = DataType(name: name.name)
    self.deinitializer = `deinit`
    let synthInit = TypeDecl.synthesizeInitializer(properties: properties,
                                                   genericParams: genericParams,
                                                   type: type)
    self.initializers.append(synthInit)
    self.name = name
    self.conformances = conformances
    self.genericParams = genericParams
    super.init(type: type, modifiers: modifiers, sourceRange: sourceRange)
    for method in methods {
      self.addMethod(method, named: method.name.name)
    }
    for method in staticMethods {
      self.addStaticMethod(method, named: method.name.name)
    }
    for subscriptDecl in subscripts {
      self.addSubscript(subscriptDecl)
    }
    for property in properties {
      propertyDict[property.name.name] = property.type
    }
  }

  /// Finds all properties that are not computed and actually contribute
  /// to the size of this type.
  public var storedProperties: [PropertyDecl] {
    return properties.filter { !$0.isComputed }
  }

  public var isIndirect: Bool {
    return has(attribute: .indirect)
  }
}

public protocol DeclRef {
  weak var decl: Decl? { get set }
}

public class PropertyDecl: VarAssignDecl {
  public let getter: PropertyGetterDecl?
  public let setter: PropertySetterDecl?

  public var isComputed: Bool {
    return getter != nil || setter != nil
  }

  public init(name: Identifier, type: TypeRefExpr,
              mutable: Bool, rhs: Expr?, modifiers: [DeclModifier],
              getter: PropertyGetterDecl?, setter: PropertySetterDecl?,
              sourceRange: SourceRange? = nil) {
    self.getter = getter
    self.setter = setter

    super.init(name: name, typeRef: type,
               rhs: rhs, modifiers: modifiers,
               mutable: mutable, sourceRange: sourceRange)!
  }
}

public class PropertyGetterDecl: MethodDecl {
  public let propertyName: Identifier
  public init(parentType: DataType,
              propertyName: Identifier,
              type: TypeRefExpr,
              body: CompoundStmt,
              sourceRange: SourceRange? = nil) {
    self.propertyName = propertyName
    super.init(name: "",
               parentType: parentType,
               args: [],
               genericParams: [],
               returnType: type,
               body: body,
               modifiers: [],
               hasVarArgs: false,
               sourceRange: sourceRange)
  }
}

public class PropertySetterDecl: MethodDecl {
  public let propertyName: Identifier
  public init(parentType: DataType,
              propertyName: Identifier,
              type: TypeRefExpr,
              body: CompoundStmt,
              sourceRange: SourceRange? = nil) {
    self.propertyName = propertyName
    super.init(name: "",
               parentType: parentType,
               args: [ParamDecl(name: "newValue", type: type)],
               genericParams: [],
               returnType: DataType.void.ref(),
               body: body,
               modifiers: [],
               hasVarArgs: false,
               sourceRange: sourceRange)
  }
}

public class TypeAliasDecl: Decl {
  public let name: Identifier
  public let bound: TypeRefExpr
  public var decl: TypeDecl?
  public init(name: Identifier,
              bound: TypeRefExpr,
              modifiers: [DeclModifier] = [],
              sourceRange: SourceRange? = nil) {
    self.name = name
    self.bound = bound
    super.init(type: bound.type, modifiers: modifiers, sourceRange: sourceRange)
  }
  public override func attributes() -> [String : Any] {
    var superAttrs = super.attributes()
    superAttrs["name"] = name.name
    return superAttrs
  }
}

public class TypeRefExpr: Expr, DeclRef {
  public var decl: Decl?
  public let name: Identifier
  public init(type: DataType, name: Identifier, sourceRange: SourceRange? = nil) {
    self.name = name
    super.init(sourceRange: sourceRange ?? name.range)
    self.type = type
  }
}

extension DataType {
  public func ref(range: SourceRange? = nil) -> TypeRefExpr {
    let expr = TypeRefExpr(type: self,
                           name: Identifier(name: "\(self)", range: range),
                           sourceRange: range)
    expr.type = self
    return expr
  }
}

public class FuncTypeRefExpr: TypeRefExpr {
  public let argNames: [TypeRefExpr]
  public let retName: TypeRefExpr
  public init(argNames: [TypeRefExpr],
              retName: TypeRefExpr,
              sourceRange: SourceRange? = nil) {
    self.argNames = argNames
    self.retName = retName
    let argTypes = argNames.map { $0.type }
    let argStrings = argNames.map { $0.name.name }
    var fullName = "(" + argStrings.joined(separator: ", ") + ")"
    if retName != .void {
      fullName += " -> " + retName.name.name
    }
    let fullId = Identifier(name: fullName, range: sourceRange)
    super.init(type: .function(args: argTypes, returnType: retName.type, hasVarArgs: false), name: fullId, sourceRange: sourceRange)
  }
}

public class PointerTypeRefExpr: TypeRefExpr {
  public let pointed: TypeRefExpr
  public init(pointedTo: TypeRefExpr, level: Int, sourceRange: SourceRange? = nil) {
    self.pointed = pointedTo
    let fullName = String(repeating: "*", count: level) + pointedTo.name.name
    let fullId = Identifier(name: fullName, range: sourceRange)
    var type = pointedTo.type
    for _ in 0..<level {
      type = .pointer(type)
    }
    super.init(type: type, name: fullId, sourceRange: sourceRange)
  }
}

public class GenericTypeRefExpr: TypeRefExpr {
  public let unspecializedType: TypeRefExpr
  public let args: [GenericParam]

  public init(unspecializedType: TypeRefExpr, args: [GenericParam], sourceRange: SourceRange? = nil) {
    self.unspecializedType = unspecializedType
    self.args = args
    let commaSepArgs = args.map { $0.typeName.name.name }
                           .joined(separator: ", ")
    let fullName = Identifier(name: "\(unspecializedType.name)<\(commaSepArgs)>",
                              range: sourceRange)
    super.init(type: unspecializedType.type,
               name: fullName,
               sourceRange: sourceRange)
  }
}

public class ArrayTypeRefExpr: TypeRefExpr {
  public let element: TypeRefExpr
  public init(element: TypeRefExpr, length: Int? = nil, sourceRange: SourceRange? = nil) {
    self.element = element
    let fullId = Identifier(name: "[\(element.name.name)]",
                            range: sourceRange)
    super.init(type: .array(element.type, length: length),
               name: fullId,
               sourceRange: sourceRange)
  }
}

public class TupleTypeRefExpr: TypeRefExpr {
  public let fieldNames: [TypeRefExpr]
  public init(fieldNames: [TypeRefExpr], sourceRange: SourceRange? = nil) {
    self.fieldNames = fieldNames
    let argTypes = fieldNames.map { $0.type }
    let fullName = "(\(fieldNames.map { $0.name.name }.joined(separator: ", ")))"
    super.init(type: .tuple(argTypes),
               name: Identifier(name: fullName, range: sourceRange),
               sourceRange: sourceRange)
  }
}

public func ==(lhs: TypeRefExpr, rhs: DataType) -> Bool {
  return lhs.type == rhs
}
public func !=(lhs: TypeRefExpr, rhs: DataType) -> Bool {
  return lhs.type != rhs
}
public func ==(lhs: DataType, rhs: TypeRefExpr) -> Bool {
  return lhs == rhs.type
}
public func !=(lhs: DataType, rhs: TypeRefExpr) -> Bool {
  return lhs != rhs.type
}
