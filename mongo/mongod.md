# mongo连接配置

> 本文诣在分析spring-data-mongo中的连接参数，并分析整个请求过程
>
> ```xml-dtd
>   <dependency>
>     <groupId>org.springframework.boot</groupId>
>     <artifactId>spring-boot-starter-data-mongodb</artifactId>
>     <version>2.6.2</version>
>   </dependency>
> 
> ```

## clusterSettings

集群配置

- serverSelectionTimeout

  > Sets the timeout to apply when selecting a server. If the timeout expires before a server is found to handle a request, a com.mongodb.MongoTimeoutException will be thrown. The default value is 30 seconds.

  服务不可用的时候，等待的时间，如果超过这个时间还没找到可用的服务，那么就会抛出异常，如果不想让查询时间太长，阻塞主流程，这个时间最好配置短一些

- ClusterConnectionMode

  连接模式 SINGLE MULTIPLE LOAD_BALANCED

  

## socketSetting

套接字连接配置

- connectTimeout

  > Sets the socket connect timeout.

  socket连接超时时间，这个是连接池中维护socket连接时候关注的？

- readtimeout

  读的最大超时，根据具体业务配置

- receiveBufferSize
- sendBufferSize