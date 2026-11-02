// expect-error: duplicate enum CLI spelling 'deep-blue'
package fixture

import jian.*

@JianDerive[JianArgValue]
enum Value { | DeepBlue | Deep_Blue }
