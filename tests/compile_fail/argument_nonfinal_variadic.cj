// expect-error: variadic Array parameter must be the last positional parameter
package fixture

import jian.*

@Command
func example(files!: Array<String> = Argument(), destination!: String = Argument()) {}
