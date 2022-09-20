# redis

## redis-cluster

文档应该是基于3.0的版本实现的

设计目标

- 高延展性，支持1000+节点
- 可以调节的写入安全
- 高可用，基于主备节点实现的



部分在单点应用中的命令在集群中不再可用，但是如果多个key是在一个slot（桶）中的，其实一般来说还是可以用的

集群中有hashtag的概念，这样强制让多个key存储在一个桶中

集群中不存在多数据库的概念

集群中节点之间的通信基于二进制通信协议实现 



client理论上是可以不用保存集群状态的，因为client理论上可以请求集群中的任意节点，并基于返回的结果来做决定，如果key不在该节点，即返回错误，错误信息中包含key所在的真正节点，所以用redis-cli请求的时候，会看到redirect，但是client也可以自己缓存key和node之间的关系，这样就可以带来更好的使用体验和效率



写入安全

> Redis Cluster tries harder to retain writes that are performed by clients connected to the majority of masters, compared to writes performed in the minority side.

**怎么理解呢？**

> master nodes unable to communicate with the majority of the other masters for enough time to be failed over will no longer accept writes, and when the partition is fixed writes are still refused for a small amount of time to allow other nodes to inform about configuration changes. 

一个节点发现自己不能跟大多数其他节点通信了，就不会再接受数据写入了

可用性

集群中会尽可能为每个master节点安排备份节点

> Very high performance and scalability while preserving weak but reasonable forms of data safety and availability is the main goal of Redis Cluster.



### 基本构造

16384 2^14 个slot

使用crc16的校验码 mod 16384，即知道在哪个桶，再根据node跟桶之间的关系，知道是在哪个节点

key hash tag

可以理解为hash标签，有时候为了能在cluster上执行多key多操作，就要求一些key在同一个桶中？是基于{}来做的，即找到出现的第一对{}，其中的内容用来计算crc16校验码

