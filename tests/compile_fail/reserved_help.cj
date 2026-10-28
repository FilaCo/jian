// expect-error: parameter name '--help' is reserved
package fixture

import jian.*

@Command
func example(help!: Bool): Unit {}
