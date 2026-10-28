// expect-error: Option settings must be named
package fixture

import jian.*

@Command
func example(value!: Bool = Option('v')) {}
