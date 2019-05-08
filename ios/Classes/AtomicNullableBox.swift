import Foundation
import NIOConcurrencyHelpers

public final class AtomicNullableBox<T: AnyObject> {
  private let storage: Atomic<UInt>

  public convenience init() {
    self.init(nil)
  }

  public init(_ value: T?) {
    if let value = value {
      let ptr = Unmanaged<T>.passRetained(value)
      self.storage = Atomic(value: UInt(bitPattern: ptr.toOpaque()))
    } else {
      self.storage = Atomic(value: 0)
    }
  }

  deinit {
    let oldPtrBits = self.storage.exchange(with: 0xB00DEAD)
    let oldPtr = Unmanaged<T>.fromOpaque(UnsafeRawPointer(bitPattern: oldPtrBits)!)
    oldPtr.release()
  }

  public func compareAndExchange(expected: T?, desired: T?) -> Bool {
    func perform() -> Bool {
      let expectedPtr = expected == nil ? nil : Unmanaged<T>.passUnretained(expected!)
      let desiredPtr = desired == nil ? nil : Unmanaged<T>.passUnretained(desired!)

      if self.storage.compareAndExchange(
        expected: expectedPtr == nil ? 0 : UInt(bitPattern: expectedPtr!.toOpaque()),
        desired: desiredPtr == nil ? 0 : UInt(bitPattern: desiredPtr!.toOpaque())
    )
      {
        _ = desiredPtr?.retain()
        expectedPtr?.release()
        return true
      } else {
        return false
      }
    }

    return desired == nil ? perform() : withExtendedLifetime(desired!, perform)
  }

  public func exchange(with value: T?) -> T? {
    let newPtr = value == nil ? nil : Unmanaged<T>.passRetained(value!)
    let oldPtrBits = self.storage.exchange(with: newPtr == nil ? 0 : UInt(bitPattern: newPtr!.toOpaque()))


    let oldPtr = oldPtrBits == 0 ? nil : Unmanaged<T>.fromOpaque(UnsafeRawPointer(bitPattern: oldPtrBits)!)
    return oldPtr?.takeRetainedValue()
  }

  public func load() -> T? {
    let ptrBits = self.storage.load()
    let ptr = ptrBits == 0 ? nil : Unmanaged<T>.fromOpaque(UnsafeRawPointer(bitPattern: ptrBits)!)
    return ptr?.takeUnretainedValue()
  }

  public func store(_ value: T?) -> Void {
    _ = self.exchange(with: value)
  }
}
