// expect-error: duplicate short name '-v'
package fixture

import jian.*

@Command
func example(@Param[short: 'v'] verbose!: Bool, @Param[short: 'v'] version!: Bool) {}
