# AQS-reentrantlock

> 管程是指管理共享变量以及对共享变量操作的过程，让它们支持并发

sync加锁解锁是jvm自动实现的，并且是重量级的锁。



**为什么reentrantlock在高并发场景比sycn高效？**

这个问题不是太好，换个问题，它们两个的区别

 

|              | reentrantlock                                    | sync                                  |
| ------------ | ------------------------------------------------ | ------------------------------------- |
| 实现层面     | jdk基于aqs实现的                                 | jvm基于monitor机制实现的              |
| 获取锁的方式 | 支持尝试获取锁、超时获取锁、获取锁的过程中可中断 | 由jvm管理，获取锁的过程不可控         |
| 重入         | 支持                                             | 支持                                  |
| 公平？       | 都可以实现                                       | 非公平                                |
| 条件队列     | 支持多个条件队列                                 | 只支持一个条件队列                    |
| 释放锁       | 手工完成，在finally块中                          | jvm管理                               |
| 性能         |                                                  | 经过优化，已经和reentrantlock基本一致 |

场景比较简单的时候优先使用sync，场景复杂、并发大，优先用reentryantlock。



等待队列中node的wait_status什么时候为0



java实现临界区访问的机制基本是参照MESA模型实现的，如下

![image-20220819145155950](..\image-20220819145155950.png)

要访问临界资源的线程要在等待队列排队进入，同时还提供了条件等待队列，条件等待队列是为了方便多线程之间同步解决问题。

jvm层面实现了MESA机制，为我们提供了sync锁，是基于monitor来实现的，之后的jdk版本对之做了优化，提出了偏向锁和轻量锁，在竞争不是太激烈的时候，不需要切换到重量级锁，不要切换到内核态，提升效率。

jdk层面同样也实现了MESA模型，即AQS，这是一个抽象类，其中天然实现了等待队列入队、出队，线程竞争获取锁以及线程阻塞、唤醒的机制，它的子类要在其的基础上实现获取锁、释放锁的接口即可。

以上是一种管程的概念，即管理线程。

------------------

## 问题

1. 为什么reentrantlock在高并发场景比sync高效？

## reentrantlock的性质

- 可重入

  已经拿到锁的线程，之后是可以再次获取锁的

- 公平/非公平

  可以基于获取锁的动作决定是否是公平，默认是非公平，这样在高并发情况下效率更高，非公平的时候，线程刚获取锁的时候，就可以尝试CAS取锁，如果是公平的，就只能乖乖排队。

- 独占锁

- 悲观锁

## 代码分析

- 获取锁

  ```java
  final void lock() {
      if (compareAndSetState(0, 1))
          setExclusiveOwnerThread(Thread.currentThread());
      else
          acquire(1);
  }
  ```

  如上，是非公平锁的加锁代码，所有线程在申请锁的时候，就直接基于CAS来一波申请锁的操作，申请成功，直接返回，不成功的再调用acqire()方法，这里会再次尝试一下：

  ```java
  final boolean nonfairTryAcquire(int acquires) {
      final Thread current = Thread.currentThread();
      int c = getState();
      if (c == 0) {
          if (compareAndSetState(0, acquires)) {
              setExclusiveOwnerThread(current);
              return true;
          }
      }
      else if (current == getExclusiveOwnerThread()) {
          int nextc = c + acquires;
          if (nextc < 0) // overflow
              throw new Error("Maximum lock count exceeded");
          setState(nextc);
          return true;
      }
      return false;
  }
  ```

  首先判断标注位是否为0，为0则再次尝试获取，获取失败判断是否当前线程已经取到锁了，这里是判断是否会有**线程重入**的场景，是允许重入的，这里会把标志位加1，表示线程又加了一次。如果不存在这种场景，直接返回false，走入队流程，如下：

  ```java
  private Node addWaiter(Node mode) {
      Node node = new Node(Thread.currentThread(), mode);
      // Try the fast path of enq; backup to full enq on failure
      Node pred = tail;
      if (pred != null) {
          node.prev = pred;
          if (compareAndSetTail(pred, node)) {
              pred.next = node;
              return node;
          }
      }
      enq(node);
      return node;
  }
  ```

  首先判断队列是否已经初始化了，是的话，就直接cas尾插，插入成功，返回当前节点，没有初始化或者插入失败则进入enq做自旋，知道插入成功：

  ```java
  private Node enq(final Node node) {
      for (;;) {
          Node t = tail;
          if (t == null) { // Must initialize
              if (compareAndSetHead(new Node()))
                  tail = head;
          } else {
              node.prev = t;
              if (compareAndSetTail(t, node)) {
                  t.next = node;
                  return t;
              }
          }
      }
  }
  ```

  首先cas竞争初始化，之后cas竞争尾插。**这里为什么要用for，直接用while(true)不香吗。**入队成功之后，就开始要准备阻塞了，如下：

  ```java
  final boolean acquireQueued(final Node node, int arg) {
      boolean failed = true;
      try {
          boolean interrupted = false;
          for (;;) {
              final Node p = node.predecessor();
              if (p == head && tryAcquire(arg)) {
                  setHead(node);
                  p.next = null; // help GC
                  failed = false;
                  return interrupted;
              }
              if (shouldParkAfterFailedAcquire(p, node) &&
                  parkAndCheckInterrupt())
                  interrupted = true;
          }
      } finally {
          if (failed)
              cancelAcquire(node);
      }
  }
  ```

  这里，还是不死心，如果当前节点是头节点，会再次尝试获取锁。之后调用park阻塞线程，直到被唤醒，继续尝试获取锁，没获取到，还是阻塞。