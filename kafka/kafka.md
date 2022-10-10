集群启动之后，会有一个controller的概念



consumer自己维护offset



怎么控制消息发布到哪个topic



为什么会有流式的设计

# kafka

## 1. 基本架构

kafka一个分布式消息中间件，主要用于数据量较大的场景，由多个节点构成，在kafka中被称为broker，多个broker之间依赖zk组成架构。基本组成如下：

### 1.1 消息生产

大体上就是由消息生产者发布消息，之后由消息消费者接收。

消息是由**topic**做分类的，不同的消息生产者注册的时候会指定其topic。生产者会把消息推送到服务端，即**broker**中，broker是kafka集群中的节点，对于每个topic，考虑到吞吐量的要求，一般会分成多个分区，即**partition**，而为了保证数据的安全，每个partition会有多个备份节点，即构成主备的结构，为了保证数据安全，一般partition的leader和follwer会在不同的broker中。

消息发布到broker中，之后存储到对应partition中，其实是存放到日志文件中的，为了提升写入、读取速度，这里是顺序写入的，即对于每个日志文件，是提前申请一段连续的空间。日志文件中，包含每条消息的索引，以及对应消息的内容，消息的编号这里称之为offset。

所以消息被创建之后，就一直放在磁盘中，默认保存一周。

具体发消息的时候，是基于配置的broker，找到存配置的zk，之后从zk上面取具体的连接信息。

发送消息的时候，可以选择具体的partition，如果选定了，就直接用给的值，没有选定，则看对应的key，如果有key，则计算key的hash，之后对总的分区数量取模，得到分区号，没有key，则采用轮询的方式，具体是用atomicinteger来实现的。

### 1.2 消息消费

对于消息的消费者，有一个消费者组的概念，即同一个消费者组中的消费者不会消费同样的信息，不同消费者组的消费者会消费同样的信息。更具体的，kafka中注册的消费者是和partition对应的，同一个消费者组中的消费者会消费不同partition中的消息，这种设计会保证对于每个partition，肯定会有消费者与之对应，并且是一个组中只会有一个消费者消费器中的消息，所以如果一个组中消费者的数量比partition要少，那么肯定会出现一个消费者消费多个分区的情况，如果要多，那么肯定会有消费者是空闲的状态。

目前消费者消费是采用拉的方式来取消息，即pull。

## 2. 分布式一致性




