# AQS相关工具类

> AQS本质是协调线程之间同步协作的架构，是jdk方面对MESA模型的实现，它是一个抽象方法，其中实现了线程同步管理的基础，包括提供了协作的标志位state，同时提供了CAS的改动state的方式，以及同步等待队列、入队、阻塞、唤醒的机制。
>
> 线程之间协作有以下几种
>
> - 共享
>
>   - 并发信号量
>
>     semaphore，控制同时运行的线程数量
>
>   - 同步计数器
>
>     countdownlatch，控制一批线程的同步启停
>
> - 独占
>
>   - 独占锁
>
>     reentrantlock，这个是jdk层面实现的可重入，公平/非公平的独占锁

MESA模型

同步等待队列-



## semaphore

这里是实现同**一批**线程之间的同步操作，可以控制线程的并发速度，常用方式如下：

```java
static Semaphore semaphore = new Semaphore(5);
try {
	// 这里获取信号量是放在try中的，因为release允许空跑。
    s.acquire();
} finally {
    s.release(1);
}
```

首先做的是**初始化**一个Semaphore对象，初始化其中的资源state数量，如上是初始化了5个资源。

之后要做一些操作的线程就可以竞争**获取资源**，可以调用的api有：

- public void acquire() throws InterruptedException
- public void acquireUninterruptibly()
- public boolean tryAcquire()
- public boolean tryAcquire(long timeout, TimeUnit unit)

线程可以直接调用默认的acquire方法，不传任何参数，即以可打断的方式获取1个资源，获取不到即阻塞，同时，线程也可以选择获取的资源数量，是否阻塞以及阻塞的时间。

获取资源的方式比较统一，即首先判断还有资源，如果还有，就以cas的方式获取锁，即将state的值减去对应的值，如果失败了，就基于调用线程的选择，入队阻塞、直接返回false或者阻塞一段时间之后再返回。

有线程要释放资源，即调用release()方法，这里是把前面占用的资源还回去，即使用cas的方式把state加回去，之后唤醒等待队列首的线程。这里有一个概念是，被唤醒的线程发现它的模式是shared的时候，就会唤醒它下一个线程，是一种链式唤醒的方式，因为我们不知道线程释放了多少资源，故也不知道能够唤醒多少线程，所以就干脆来做链式的机制，能唤醒就唤醒，断了就继续阻塞。

## countdownlatch

这里是实现**两批**线程之间的同步，使用方式如下：

```java
CountDownLatch countDownLatch = new CountDownLatch(10);

System.out.println("start");
for (int i = 0; i < 10; i++) {
    ExecutorFactory.getThreadPoolExecutor().execute(countDownLatch::countDown);
}
Thread.sleep(100);
for (int i = 0; i < 5; i++) {
    ExecutorFactory.getThreadPoolExecutor().execute(() -> {
        try {
            countDownLatch.await();
            System.out.println(Thread.currentThread().getName() + "wake");
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }

    });
}
System.out.println("end");
```

和semaphore一样，也是初始化的时候声明自己有多少资源。它的使用方式跟普通的加锁解锁方式比起来，倒过来了，首先是有一批线程要等待执行一些逻辑，但是它们要等待前面的线程都操作完，具体要等待的线程数量即开始初始化的资源数。

**先序**的线程执行完特定逻辑之后，调用countDown方法，这个方法中，会使用CAS把state减一，直到减到0，意味着所有的前序工作已经完成，就去唤醒已经调用await方法在等待的**后序**的线程。

这里比较有意思的是，countdownlatch自己实现的tryAcquireShared方法，如下：

```java
protected int tryAcquireShared(int acquires) {
    return (getState() == 0) ? 1 : -1;
}
```

即当state变成0之后，不会再对获取共享锁的操作做任何限制，可以直接取。同时比较核心的性质是，这个东西是**一次性**的，它的一次性是指只会有**一次唤醒操作**，就是第一次调用countdown操作，把state变成0之后，就会唤醒等待队列中的线程。之后再调用countdown，会直接返回false，也就不会唤醒等待的线程，同时执行完唤醒操作，之后再调用tryAcquireShared方法，每次都是返回1，await方法也就不会再阻塞对应线程。

## cyclicBarrier

回环栅栏，可以指定对应线程数，同时可以指定达到指定条件之后要执行的操作。

**和countdownlatch的区别**

- 它是基于独占锁以及条件等待队列实现的。

- 可以循环操作。

大体步骤：

1. 线程依次获取锁，之后调用condition对象的await方法
   1. 如果count不为0，释放锁，之后阻塞
   2. 如果count为0，执行之前**指定的处理逻辑**，并会唤醒当前条件等待队列中的所有线程
      1. 线程被唤醒之后，做的事情是进入同步等待队列，之后再次阻塞，
      2. 同时当前线程执行完业务逻辑之后，会释放锁

2. 前面因为调用await阻塞的线程进入条件等待队列再次阻塞之后，因为其他线程释放锁被唤醒，之后竞争锁，执行之后的逻辑。



await的基本使用逻辑

```java
lock.lock();
try {
    // 此时 进入条件等待队列，同时释放锁
    // 被唤醒之后，进入同步等待队列，同时竞争获取锁，大概率阻塞
    condition.await();
} finally {
    lock.unLock();
}

lock.lock();
try {
    // 这里把条件等待队列头节点唤醒
    condition.singnal();
} finally {
    // 释放锁，唤醒上面再次唤醒的线程
    lock.unLock();
}
```

cyclicBarrier后半段逻辑，即达到目标值，之前await的线程执行的就是标准的独占锁的逻辑。

## ReentrantReadWriteLock

基于AQS实现的读写锁，是针对读多写少的场景做的优化版本。

**使用一个变量维护多个状态。**

分别通过state的高16和低16表示读、写的状态。

**支持写锁的降级**，线程获取写锁，对数据做了改动，如果释放写锁之后还要使用数据，最好在释放写锁之前就获取读锁，保证之后的操作的可见性。

读写锁都是支持重入的，读锁的重入数量是使用ThreadLocal实现的，写锁的重入直接使用state记录。



可能会造成**写饥饿**的场景，每次读都加锁，并且频率较大，可能写锁就要阻塞时间较久。

之后会有一个乐观读的场景，通过时间戳判断读到的数据是否是安全的，如果是安全的，就不需要再获取读锁，如果不安全，再取读锁。这样就是减少加读锁的频率，一定程度上缓解**写饥饿**的场景。

## 阻塞队列

**ArrayBlockingQueue**

只有一个独占锁，和两个条件等待队列。

插入和取出都要获取锁，如果插入的时候队列满了，或者获取的时候队列空了，就进入条件等待队列，之后插入或者删除的时候会调用对应的signal方法。

读取和插入是基于两个index来完成的，它们都是从开头向尾部移动，保证是先进先出。这里把之前的数组展示成了一个**环形数组**，即如果索引到了队尾，直接移动到队头，提升效率。

**LinkedBlockingQueue**

基于双向链表实现，理论上是无界的，同时也可以指定容量。

这里使用了两把独占锁，插入和读取分别一把。相对于前者，因为锁的粒度更小

**线程池中为什么优先选择LinkedBlockingQueue，因为性能问题。**

以上两者的比较：

- 容量：一个是有限容量的，一个是可以无限容量的
- 锁：一个只有一把锁，一个是两把锁
- 容器不同：一个是数组，一个是链表

**LinkedBlockingDeque**

和**LinkedBlockingQueue**对比，支持双端操作，只有一把锁。

容量是0，支持公平/非公平

**SynchronousQueue**

不会存数据，记录的是线程，线程有取数据和放数据两种类型，如果没有消费者，生产者会被阻塞，反之，同样。

这里没有基于AQS实现，直接用的CAS+自旋 park/unpark的方式来实现加锁/解锁 阻塞。

如果我们不确定生产者的数量，但是生产者的数据一定要被消费，可以考虑这种模式。

**PriorityBlockingQueue**

优先队列，使用了堆排序来做排序。

正常堆排序是：

1. 构建二叉堆
2. 取堆顶
3. 重排序

这里有涉及入堆，重调整，出堆的操作。

底层使用数组实现，是一个无界队列，所以入队不会阻塞，出队的时候阻塞。

使用了一把锁，和一个等待对象。

**DelayQueue**

底层使用优先级队列实现，优先级是通过比较过期时间决定的，插入的时候，是直接放到内部的优先级队列中的，实现的是一个小顶堆，每次取的是延时最小的元素，之后判断是否超时。



## 选择策略

1. 功能上

   看是想要一般的阻塞队列，还是要有优先级、延时的需求

2. 容量

   看下是否能预估出对应的容量，如果容量是不能预估的，就不能用定长的阻塞队列

3. 内存结构

   ArrayBlockingQueue是连续存储空间，对空间利用率更高。

4. 性能

如果是线程竞争不是太强，容量确定的情况下，可以使用Array，如果竞争较强，可以考虑使用链表的实现。



## 如何解决死锁

死锁的条件：

1. 互斥
2. 占有且等待
3. 不可强行占有
4. 循环等待

要解决死锁，就是打破这些条件

哲学家就餐问题

1. 取筷子顺序变下，不会发生循环等待

