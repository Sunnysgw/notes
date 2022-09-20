# 并发容器

> list set concurrenthashmap

容量是一个比较重要的点，初始化一个容器的时候，最好赋予其初始大小，防止后面扩容浪费时间、空间

## List

底层使用数组实现

常用的实现是ArrayList，存取的时间复杂度是o（1）

size 容量 

## LinkedList

底层使用链表实现

插入删除会比较快，查询比较慢

## HashMap

hashset就是用hashmap来做存储的

链表长度大于8，并且size大于64的时候，把链表转化为红黑树。

当红黑树节点数量小于6的时候，会退化成链表。

## concurrenthashmap

另外一个是hashtable，这是一个同步容器。

1.8的concurrenthashmap中间大量使用了cas的机制，加锁的粒度放小到单个node节点。



## Deque

![image-20220816093644537](E:\Document\work\笔记\image-20220816093644537.png)

Deque接口提供了两套方法，一套是失败了返回特定的值，一套是失败了抛异常。

注释里面是说不建议实现类支持空值，因为空值在例如pop poll peek等方法中，是当作特殊值返回的，表示队列为空。

