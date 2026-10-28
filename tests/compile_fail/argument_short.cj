// expect-error: unknown Argument setting 'short'
package fixture

import jian.*

@Command
func example(value!: String = Argument(short: 'v')) {}
