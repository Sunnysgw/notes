# JAVA线程

## 一些问题

**CAS涉及到用户模式和内核模式的切换吗？**

cas过程中不涉及**系统调用**、**异常事件**、**设备中断**这些情况

**java的线程和go的携程有什么区别？**

**如何优雅的终止线程？**

**java线程之间如何通信，有哪些方式？**

volatile修饰的变量，保证可见性

## 线程和进程

进程是资源（内存 cpu时间片）分配的最小单位，进程之间不会共享资源

线程是cpu调度的最小单位，一个进程中可以有多个线程，同一个进程之间的线程共享资源的。



**进程间通信**

管道？

**socket**

信号

信号量 

**共享内存**：分布式锁（reids mysql）

**消息队列**：对应的mq 



**线程的同步和互斥**

同步：多个线程之间协作完成一段任务

互斥：对于共享的资源，同一时刻，只有一个线程能够使用

**上下文切换**

程序计数器：记录当前指令执行的行号

用户态 内核态 

上下文切换只能发生在内核态，

**线程生命周期**

操作系统层面：

初始状态 

可运行（就绪）状态 

运行状态 

休眠状态 

终止状态



java层面

- new

  新建了线程

- runnable 

  调用了start

- blocking 

  竞争synchronized 但是没有拿到锁

- waiting timed_waiting 

  被阻塞

  Thread.sleep

  wait

  join

  park

- terminated

  执行完成

**java实现线程的几种方式**

- 继承Thread类

- 实现runnable接口，配合thread实现

  这种机制没有返回值

  异常处理不友好

- callable

  可以返回值

  会抛出异常

- 使用lambda表达式来做

创建线程的方式基本都可以追溯到new Thread()，启动的时候基本都可以追溯到start()方法。

java中线程的创建涉及系统调用，中间会涉及用户态、内核态之间的切换，会有性能损耗。所以会考虑使用线程池的机制，不要频繁创建线程。

**携程**

基于线程的，更轻量级的，对操作系统是不可见的，不涉及系统状态的切换，性能更高。所以go是天然支持网络io密集操作

**线程调度机制**

谁能抢占到时间片不是java自己控制的，java提供了Thread.yield()方法。

**优雅的停止线程**

直接调用stop方法，会直接释放锁。

java给提供了中断机制，执行过程中可以判断 Interrupt 。线程池调用shutdownNow，会给正在运行的线程发送interrupt信号，可以调用Thread.currentThread().isInterrupted()判断是否被中断。

要注意的是，sleep wait的操作会抛出InterruptedException异常，同时清除中断标志位，那么上面的判断就取不到标志位了，所以要在捕捉到该异常之后重设中断标志。

> sleep并不会使当前线程释放锁 wait则会，因为wait涉及管程的概念

**线程之间通信**

- 基于volatile修饰的变量

- 等待唤醒机制

  - wait notify 

    是monitor机制，要集合sync关键做来做

    如果有多个线程wait，不一定唤醒哪个线程

  - park unpark

    