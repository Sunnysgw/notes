# AQS

> 管程是指管理共享变量以及对共享变量操作的过程，让它们支持并发

## CompletionService

管理多个futuretask，按照完成时间放进阻塞队列。juc中实现的一个实现类是ExecutorCompletionService，除了针对runnable和callable的submit方法，就是针对结果阻塞队列的取结果的方法：take poll。

任务执行完成之后就会被放到阻塞队列，等待读取。

### CompletableFuture

提供了一种对future编排的工具，同样是有一个线程池，如果不制定，就用ForkJoin的通用线程池。

使用类似函数式编程的方式编排多个并行的任务。

如果想要把几个离散的同步操作组合成统一的有逻辑的操作，就可以使用其中提供的工具类。

## disruptor

是一个高性能的内存队列。

使用环形的long数组存储数据，使用缓存行填充解决伪共享问题。

使用观察者模式驱动消息的消费，这里是整了一个while循环，基于选择的策略等待，这里实现了一些比lock+condition更高效的设计。

**幂等性**？