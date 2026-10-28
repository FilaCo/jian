// expect-error: expected
package fixture

import jian.*

@Command
func example(value!: Int64 = Argument(hidden: "yes")) {}
