// expect-error: variadic Array argument must be the last positional argument
package fixture

import jian.*

@JianCallback
func example(files: Array<String>, destination: String): Unit {}
