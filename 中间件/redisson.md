# redisson分布式锁的一些思考

## 锁的几个性质

- 公平锁

  获取锁的顺序是否根据申请的顺序来的

- 共享？

  自己获取之后，其他人是否还能获取

- 可重入

  取得锁之后，是否还能再次获取该锁

- 自旋锁

  获取不到锁的时候，是直接阻塞，放弃cpu时间片，还是一直自旋（一直轮询锁是否被释放）



redisson默认获取的锁是非公平的，可重入的，其中可重入是基于获取锁以及释放锁的时候维护的map来实现的



redis集群提供了如下性质

- 自动把数据分布于不同的节点
- 当一部分节点挂掉了，仍然具有一定的可用性

redis不像memcached使用一致性hash，而是使用类似于hash桶的方式，如下

> There are 16384 hash slots in Redis Cluster, and to compute what is the hash slot of a given key, we simply take the **CRC16 of the key modulo 16384**.

着重看下这里的**crc16**

append only 这个选项



## 一些收获

一般对于集群中的redis节点，会有两个端口，一个是监听客户端的请求，例如6379，另一个是用于node节点之间的沟通，一般是之前的节点加上1

基于超时时间判断节点是否挂掉

可以使用rdis-cli来创建集群

