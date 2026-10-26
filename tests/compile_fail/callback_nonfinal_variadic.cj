// expect-error: variadic Array parameter must be the last positional parameter
package fixture

import jian.*

@Callback
func example(files: Array<String>, destination: String): Unit {}
