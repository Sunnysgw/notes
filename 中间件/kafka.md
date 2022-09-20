# kafka

- 注册消费者的时候不指定group，那么就会分配到默认的group，那么能否这样理解，所有不指定group的消费者都属于一个group

  > 不是的，没有指定group，会随机分配，但是决不会和现有的一致

- zookeeper上存放的kafka的结构数据大体上是怎样看的

- 