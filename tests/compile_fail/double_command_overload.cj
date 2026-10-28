// expect-error: redefinition
package fixture

import jian.*

@Command
func example(value: String): Unit {}
@Command
func example(value: Int64): Unit {}
