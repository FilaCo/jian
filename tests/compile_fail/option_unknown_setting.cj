// expect-error: unknown Option setting 'other'
package fixture

import jian.*

@Command
func example(value!: Bool = Option(other: true)) {}
