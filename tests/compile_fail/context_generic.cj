// expect-error: @JianContext requires a nongeneric class
package fixture

import jian.*
@JianContext
class Context<T> { public let value: T; public init(value: T) { this.value = value } }
