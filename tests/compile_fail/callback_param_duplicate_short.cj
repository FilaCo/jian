// expect-error: duplicate short name '-v'
package fixture

import jian.*

@Callback
func example(@Param[short: 'v'] verbose!: Bool, @Param[short: 'v'] version!: Bool) {}
