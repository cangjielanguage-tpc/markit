package commandline.utils

import commandline.exceptions.NotImplementedException

/**
 * 占位函数，用于标记尚未实现的功能
 * 
 * @throws NotImplementedException 调用时抛出
 */
/* cjlint-ignore -start !G.NAM.04 */
public func TODO<T>(): T {
    throw NotImplementedException("Not implemented yet")
}
/* cjlint-ignore -end */
