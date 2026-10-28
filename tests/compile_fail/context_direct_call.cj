// expect-error: missing argument
package fixture

import jian.*
@JianContext
class Context { public let value: ?String = None }
@JianCommand
func bad(value!: ?String = JianFromContext<Context>()): Unit {}
func direct(): Unit { bad() }
