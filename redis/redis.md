# redis

## 1. 常用数据结构

### 1.1 string

常用命令 

- set 

- get 

  spring session就是利用redis的string来存的

- del 

- setnx 

  分布式锁使用的命令

- mset 

- mget

- incr

  原子性+1，类似于juc的atomic机制

  场景：

  统计阅读量

  批量生成序列号

- decr

  原子性-1



### 1.2 hash

是一个 key -> value 的结构，其中value同样是key-value的结构

不同于string，hash的value也是一系列key-value的对，对于其中value的操作类似于string的操作，同样可以做原子加减

**场景**

对象缓存，存放对象的不同字段，如果key比较大，redis会比较麻烦

**优点**

相对string ，数据管理更紧凑，存储空间、性能方面更优

**缺点**

过期功能只能用到key中，不能用到field中

集群架构下不适合大规模使用？

### 1.3 列表list

**常用操作**

lpush

rpush

lpop

rpop

blpop

brpop

使用这些基本命令可以实现队列、栈以及阻塞队列、阻塞栈的形式。

常用的场景，例如消息队列

todo消息队列实现方式，自己是这么想的

消费者要订阅消息，可以这么定义list的key，topic-consumer，有消息，就把消息push进去，消费者可以使用blpop类似的命令持续监听队列，这种是推的模式。

还可以采用拉的方式，消息放在一个list中，订阅者主动去拉其中的消息，如果拉取的人太多，感觉可以考虑多放几个key，把压力分散出去，就是对于微博的大v，首先对他们来说，主动推不是太现实，粉丝太多了，可以把消息发布到几个key中，粉丝基于一定路由访问这些key，做负载均衡的方式。

### 1.4 集合 set

常用操作

sadd

smembers

srandmember

spop

sinter 交集

sunion 并集

sdiff 差集

基于这些操作实现关注列表的操作。

可以利用set实现随机抽取的操作，srandmember和spop都是随机抽取元素的操作，不同的是前者会把元素放回去，后者会删除对应的元素。

- 有序集合 zset