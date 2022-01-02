// MIT License
//
// Copyright (c) 2020 Point-Free, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// swiftlint:disable all
// Adapted from https://github.com/pointfreeco/swift-case-paths

struct CasePath<Root, Value> {
    private let _embed: (Value) -> Root
    private let _extract: (Root) -> Value?

    init(embed: @escaping (Value) -> Root) {
        self._embed = embed
        self._extract = extractHelp(embed)
    }

    func extract(from root: Root) -> Value? {
        _extract(root)
    }
}

private func extractHelp<Root, Value>(_ embed: @escaping (Value) -> Root) -> (Root) -> Value? {
    guard
        let metadata = EnumMetadata(Root.self),
        metadata.typeDescriptor.fieldDescriptor != nil
    else {
        assertionFailure("embed parameter must be a valid enum case initializer")
        return { _ in nil }
    }

    var cachedTag: UInt32?
    var cachedStrategy: Strategy<Root, Value>?

    return { root in
        let rootTag = metadata.tag(of: root)

        if let cachedTag = cachedTag, let cachedStrategy = cachedStrategy {
            guard rootTag == cachedTag else { return nil }
            return cachedStrategy.extract(from: root, tag: rootTag)
        }

        let rootStrategy = Strategy<Root, Value>(tag: rootTag)
        guard let value = rootStrategy.extract(from: root, tag: rootTag)
        else { return nil }

        let embedTag = metadata.tag(of: embed(value))
        cachedTag = embedTag
        if embedTag == rootTag {
            cachedStrategy = rootStrategy
            return value
        } else {
            cachedStrategy = Strategy<Root, Value>(tag: embedTag)
            return nil
        }
    }
}

// MARK: - Runtime reflection

private enum Strategy<Enum, Value> {
    case direct
    case existential(extract: (Enum) -> Any?)
    case indirect
    case optional(extract: (Enum) -> Value?)
    case unimplemented
    case void
}

extension Strategy {
    init(tag: UInt32, assumedAssociatedValueType: Any.Type? = nil) {
        let metadata = EnumMetadata(assumingEnum: Enum.self)
        let avType = assumedAssociatedValueType ?? metadata.associatedValueType(forTag: tag)

        var shouldWorkAroundSR12044: Bool {
#if compiler(<5.2)
            return true
#else
            return false
#endif
        }

        var isUninhabitedEnum: Bool {
            metadata.typeDescriptor.emptyCaseCount == 0 && metadata.typeDescriptor.payloadCaseCount == 0
        }

        if avType == Value.self {
            self = .init(nonExistentialTag: tag)

        } else if shouldWorkAroundSR12044, MemoryLayout<Value>.size == 0, !isUninhabitedEnum {
            // Workaround for https://bugs.swift.org/browse/SR-12044
            self = .void

        } else if let avMetadata = TupleMetadata(avType), avMetadata.elementCount == 1 {
            // Drop payload label from metadata, e.g., treat `(foo: Foo)` as `Foo`.
            self.init(tag: tag, assumedAssociatedValueType: avMetadata.element(at: 0).type)

        } else if let avMetadata = TupleMetadata(avType),
                  let valueMetadata = TupleMetadata(Value.self),
                  valueMetadata.labels == nil
        {
            // Drop payload labels from metadata, e.g., treat `(foo: Foo, bar: Bar)` as `(Foo, Bar)`.
            guard avMetadata.hasSameLayout(as: valueMetadata) else {
                self = .unimplemented
                return
            }
            self.init(tag: tag, assumedAssociatedValueType: Value.self)

        } else if let avMetadata = ExistentialMetadata(avType) {
            if avType == Error.self || avMetadata.isClassConstrained {
                // For Objective-C interop, the Error existential is a pointer to an NSError-compatible
                // (and thus AnyObject-compatible) object.
                let strategy = Strategy<Enum, AnyObject>(nonExistentialTag: tag)
                self = .existential { strategy.extract(from: $0, tag: tag) }
                return
            }

            // Convert protocol existentials to `Any` so that they can be cast (`as? Value`).
            let anyStrategy = Strategy<Enum, Any>(nonExistentialTag: tag)
            self = .existential { anyStrategy.extract(from: $0, tag: tag) }

        } else if avType == Value?.self {
            // Handle contravariant optional demotion, e.g. embed function
            // `(String?) -> Result<String?, Error>)` interpreted as `(String) -> Result<String?, Error>`
            let wrappedStrategy = Strategy<Enum, Value?>(tag: tag, assumedAssociatedValueType: avType)
            if case .unimplemented = wrappedStrategy {
                self = .unimplemented
            } else {
                self = .optional { wrappedStrategy.extract(from: $0, tag: tag).flatMap { $0 } }
            }
        } else {
            self = .unimplemented
        }
    }

    init(nonExistentialTag tag: UInt32) {
        self =
        EnumMetadata(assumingEnum: Enum.self)
            .typeDescriptor
            .fieldDescriptor!
            .field(atIndex: tag)
            .flags
            .contains(.isIndirectCase)
        ? .indirect
        : .direct
    }

    func extract(from root: Enum, tag: UInt32) -> Value? {
        switch self {
        case .direct:
            return self.withProjectedPayload(of: root, tag: tag) { $0.load(as: Value.self) }

        case let .existential(extract):
            return extract(root) as? Value

        case .indirect:
            return self.withProjectedPayload(of: root, tag: tag) {
                $0
                    .load(as: UnsafeRawPointer.self)  // Load the heap object pointer.
                    .advanced(by: 2 * pointerSize)  // Skip the heap object header.
                    .load(as: Value.self)
            }

        case let .optional(extract):
            return extract(root)

        case .unimplemented:
            return nil

        case .void:
            return .some(unsafeBitCast((), to: Value.self))
        }
    }

    private func withProjectedPayload<Answer>(
        of root: Enum,
        tag: UInt32,
        do body: (UnsafeRawPointer) -> Answer
    ) -> Answer {
        var root = root
        return withUnsafeMutableBytes(of: &root) { rawBuffer in
            let pointer = rawBuffer.baseAddress!
            let metadata = EnumMetadata(assumingEnum: Enum.self)
            metadata.destructivelyProjectPayload(of: pointer)
            defer { metadata.destructivelyInjectTag(tag, intoPayload: pointer) }
            return body(pointer)
        }
    }
}

private protocol Metadata {
    var ptr: UnsafeRawPointer { get }
}

extension Metadata {
    var valueWitnessTable: ValueWitnessTable {
        ValueWitnessTable(
            ptr: self.ptr.load(fromByteOffset: -pointerSize, as: UnsafeRawPointer.self)
        )
    }

    var kind: MetadataKind { self.ptr.load(as: MetadataKind.self) }
}

private struct MetadataKind: Equatable {
    var rawValue: UInt

    // https://github.com/apple/swift/blob/main/include/swift/ABI/MetadataValues.h
    // https://github.com/apple/swift/blob/main/include/swift/ABI/MetadataKind.def
    static var enumeration: Self { .init(rawValue: 0x201) }
    static var optional: Self { .init(rawValue: 0x202) }
    static var tuple: Self { .init(rawValue: 0x301) }
    static var existential: Self { .init(rawValue: 0x303) }
}

private struct EnumMetadata: Metadata {
    let ptr: UnsafeRawPointer

    init(assumingEnum type: Any.Type) {
        self.ptr = unsafeBitCast(type, to: UnsafeRawPointer.self)
    }

    init?(_ type: Any.Type) {
        self.init(assumingEnum: type)
        guard self.kind == .enumeration || self.kind == .optional else { return nil }
    }

    var genericArguments: GenericArgumentVector? {
        guard typeDescriptor.flags.contains(.isGeneric) else { return nil }
        return .init(ptr: self.ptr.advanced(by: 2 * pointerSize))
    }

    var typeDescriptor: EnumTypeDescriptor {
        EnumTypeDescriptor(
            ptr: self.ptr.load(fromByteOffset: pointerSize, as: UnsafeRawPointer.self)
        )
    }

    func tag<Enum>(of value: Enum) -> UInt32 {
        withUnsafePointer(to: value) {
            self.valueWitnessTable.getEnumTag($0, self.ptr)
        }
    }
}

extension EnumMetadata {
    func associatedValueType(forTag tag: UInt32) -> Any.Type {
        guard
            let typeName = self.typeDescriptor.fieldDescriptor?.field(atIndex: tag).typeName,
            let type = swift_getTypeByMangledNameInContext(
                typeName.ptr, typeName.length,
                genericContext: self.typeDescriptor.ptr,
                genericArguments: self.genericArguments?.ptr
            )
        else {
            return Void.self
        }

        return type
    }
}

@_silgen_name("swift_getTypeByMangledNameInContext")
private func swift_getTypeByMangledNameInContext(
    _ name: UnsafePointer<UInt8>,
    _ nameLength: UInt,
    genericContext: UnsafeRawPointer?,
    genericArguments: UnsafeRawPointer?
) -> Any.Type?

extension EnumMetadata {
    func destructivelyProjectPayload(of value: UnsafeMutableRawPointer) {
        self.valueWitnessTable.destructiveProjectEnumData(value, ptr)
    }

    func destructivelyInjectTag(_ tag: UInt32, intoPayload payload: UnsafeMutableRawPointer) {
        self.valueWitnessTable.destructiveInjectEnumData(payload, tag, ptr)
    }
}

private struct EnumTypeDescriptor: Equatable {
    let ptr: UnsafeRawPointer

    var flags: Flags { Flags(rawValue: self.ptr.load(as: UInt32.self)) }

    var fieldDescriptor: FieldDescriptor? {
        self.ptr
            .advanced(by: 4 * 4)
            .loadRelativePointer()
            .map(FieldDescriptor.init)
    }

    var payloadCaseCount: UInt32 { self.ptr.load(fromByteOffset: 5 * 4, as: UInt32.self) & 0xFFFFFF }

    var emptyCaseCount: UInt32 { self.ptr.load(fromByteOffset: 6 * 4, as: UInt32.self) }
}

extension EnumTypeDescriptor {
    struct Flags: OptionSet {
        let rawValue: UInt32

        static var isGeneric: Self { .init(rawValue: 0x80) }
    }
}

private struct TupleMetadata: Metadata {
    let ptr: UnsafeRawPointer

    init?(_ type: Any.Type) {
        self.ptr = unsafeBitCast(type, to: UnsafeRawPointer.self)
        guard self.kind == .tuple else { return nil }
    }

    var elementCount: UInt {
        self.ptr
            .advanced(by: pointerSize)  // kind
            .load(as: UInt.self)
    }

    var labels: UnsafePointer<UInt8>? {
        self.ptr
            .advanced(by: pointerSize)  // kind
            .advanced(by: pointerSize)  // elementCount
            .load(as: UnsafePointer<UInt8>?.self)
    }

    func element(at i: Int) -> Element {
        Element(
            ptr:
                self.ptr
                .advanced(by: pointerSize)  // kind
                .advanced(by: pointerSize)  // elementCount
                .advanced(by: pointerSize)  // labels pointer
                .advanced(by: i * 2 * pointerSize)
        )
    }
}

extension TupleMetadata {
    struct Element: Equatable {
        let ptr: UnsafeRawPointer

        var type: Any.Type { self.ptr.load(as: Any.Type.self) }

        var offset: UInt { self.ptr.load(fromByteOffset: pointerSize, as: UInt.self) }

        static func == (lhs: Element, rhs: Element) -> Bool {
            lhs.type == rhs.type && lhs.offset == rhs.offset
        }
    }
}

extension TupleMetadata {
    func hasSameLayout(as other: TupleMetadata) -> Bool {
        self.elementCount == other.elementCount
        && (0..<Int(self.elementCount)).allSatisfy { self.element(at: $0) == other.element(at: $0) }
    }
}

private struct ExistentialMetadata: Metadata {
    let ptr: UnsafeRawPointer

    init?(_ type: Any.Type?) {
        self.ptr = unsafeBitCast(type, to: UnsafeRawPointer.self)
        guard self.kind == .existential else { return nil }
    }

    var isClassConstrained: Bool { self.ptr.advanced(by: pointerSize).load(as: UInt32.self) & 0x8000_0000 == 0 }
}

private struct FieldDescriptor {
    let ptr: UnsafeRawPointer

    /// The size of a FieldRecord as stored in the executable.
    var recordSize: Int { Int(self.ptr.advanced(by: 2 * 4 + 2).load(as: UInt16.self)) }

    func field(atIndex i: UInt32) -> FieldRecord {
        FieldRecord(
            ptr: self.ptr.advanced(by: 2 * 4 + 2 * 2 + 4).advanced(by: Int(i) * recordSize)
        )
    }
}

private struct FieldRecord {
    let ptr: UnsafeRawPointer

    var flags: Flags { Flags(rawValue: self.ptr.load(as: UInt32.self)) }

    var typeName: MangledTypeName? {
        self.ptr
            .advanced(by: 4)
            .loadRelativePointer()
            .map { MangledTypeName(ptr: $0.assumingMemoryBound(to: UInt8.self)) }
    }
}

extension FieldRecord {
    struct Flags: OptionSet {
        var rawValue: UInt32

        static var isIndirectCase: Self { .init(rawValue: 1) }
    }
}

private struct MangledTypeName {
    let ptr: UnsafePointer<UInt8>

    var length: UInt {
        // https://github.com/apple/swift/blob/main/docs/ABI/Mangling.rst
        var ptr = self.ptr
        while true {
            switch ptr.pointee {
            case 0:
                return UInt(bitPattern: ptr - self.ptr)
            case 0x01...0x17:
                // Relative symbolic reference
                ptr = ptr.advanced(by: 5)
            case 0x18...0x1f:
                // Absolute symbolic reference
                ptr = ptr.advanced(by: 1 + pointerSize)
            default:
                ptr = ptr.advanced(by: 1)
            }
        }
    }
}

private struct ValueWitnessTable {
    let ptr: UnsafeRawPointer

    var getEnumTag: @convention(c) (_ value: UnsafeRawPointer, _ metadata: UnsafeRawPointer) -> UInt32 {
        self.ptr.advanced(by: 10 * pointerSize + 2 * 4).loadInferredType()
    }

    // This witness transforms an enum value into its associated value, in place.
    var destructiveProjectEnumData:
    @convention(c) (_ value: UnsafeMutableRawPointer, _ metadata: UnsafeRawPointer) -> Void {
        self.ptr.advanced(by: 11 * pointerSize + 2 * 4).loadInferredType()
    }

    // This witness transforms an associated value into its enum value, in place.
    var destructiveInjectEnumData:
    @convention(c) (_ value: UnsafeMutableRawPointer, _ tag: UInt32, _ metadata: UnsafeRawPointer) -> Void {
        self.ptr.advanced(by: 12 * pointerSize + 2 * 4).loadInferredType()
    }
}

private struct GenericArgumentVector {
    let ptr: UnsafeRawPointer
}

extension GenericArgumentVector {
    func type(atIndex i: Int) -> Any.Type {
        return ptr.load(fromByteOffset: i * pointerSize, as: Any.Type.self)
    }
}

extension UnsafeRawPointer {
    fileprivate func loadInferredType<Type>() -> Type {
        self.load(as: Type.self)
    }

    fileprivate func loadRelativePointer() -> UnsafeRawPointer? {
        let offset = Int(load(as: Int32.self))
        return offset == 0 ? nil : self + offset
    }
}

// This is the size of any Unsafe*Pointer and also the size of Int and UInt.
private let pointerSize = MemoryLayout<UnsafeRawPointer>.size
