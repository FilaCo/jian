// expect-error: option name '--help' is reserved
package fixture

import jian.*

@JianCommand
func example(help!: Bool): Unit {}
