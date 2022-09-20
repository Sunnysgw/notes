## spring cloud组件

### 1. 注册中心

> 这里讲的是nacos
>
> 有些坑，使用mysql8数据库，死活连不上

#### 1.1 常用配置

| 配置项                | Key                                              | 默认值                       | 说明                                                         |
| --------------------- | ------------------------------------------------ | ---------------------------- | ------------------------------------------------------------ |
| `服务端地址`          | `spring.cloud.nacos.discovery.server-addr`       | `无`                         | `Nacos Server 启动监听的ip地址和端口`                        |
| `服务名`              | `spring.cloud.nacos.discovery.service`           | `${spring.application.name}` | `给当前的服务命名`                                           |
| `服务分组`            | `spring.cloud.nacos.discovery.group`             | `DEFAULT_GROUP`              | `设置服务所处的分组`                                         |
| `权重`                | `spring.cloud.nacos.discovery.weight`            | `1`                          | `取值范围 1 到 100，数值越大，权重越大`                      |
| `网卡名`              | `spring.cloud.nacos.discovery.network-interface` | `无`                         | `当IP未配置时，注册的IP为此网卡所对应的IP地址，如果此项也未配置，则默认取第一块网卡的地址` |
| `注册的IP地址`        | `spring.cloud.nacos.discovery.ip`                | `无`                         | `优先级最高`                                                 |
| `注册的端口`          | `spring.cloud.nacos.discovery.port`              | `-1`                         | `默认情况下不用配置，会自动探测`                             |
| `命名空间`            | `spring.cloud.nacos.discovery.namespace`         | `无`                         | `常用场景之一是不同环境的注册的区分隔离，例如开发测试环境和生产环境的资源（如配置、服务）隔离等。` |
| `AccessKey`           | `spring.cloud.nacos.discovery.access-key`        | `无`                         | `当要上阿里云时，阿里云上面的一个云账号名`                   |
| `SecretKey`           | `spring.cloud.nacos.discovery.secret-key`        | `无`                         | `当要上阿里云时，阿里云上面的一个云账号密码`                 |
| `Metadata`            | `spring.cloud.nacos.discovery.metadata`          | `无`                         | `使用Map格式配置，用户可以根据自己的需要自定义一些和服务相关的元数据信息` |
| `日志文件名`          | `spring.cloud.nacos.discovery.log-name`          | `无`                         |                                                              |
| `集群`                | `spring.cloud.nacos.discovery.cluster-name`      | `DEFAULT`                    | `配置成Nacos集群名称`                                        |
| `接入点`              | `spring.cloud.nacos.discovery.enpoint`           | `UTF-8`                      | `地域的某个服务的入口域名，通过此域名可以动态地拿到服务端地址` |
| `是否集成Ribbon`      | `ribbon.nacos.enabled`                           | `true`                       | `一般都设置成true即可`                                       |
| `是否开启Nacos Watch` | `spring.cloud.nacos.discovery.watch.enabled`     | `true`                       | `可以设置成false来关闭 watch`                                |

#### 1.2 服务划分

从上而下是

- 命名空间

  用于环境/权限隔离

- 分组

  同样可以起到隔离的作用，不同分组的服务之间不能互相调用，调用方请求服务信息的时候，是会加上自己的group的，所以不同分组之间不能相互调用

- 服务

  到这一步，就是选择怎么调用的问题了

- 集群

  不同集群可以采用不同的健康检查策略，是大型服务多机房部署的具体落地实现

- 实例

同时，实例有临时/持久之分，临时是服务主动上报心跳，如果没有定点上报，即删掉实例，但是对于mysql这种不能主动上报的实例，可以申请成为持久化实例（？TODO 这种有啥应用场景，为啥mysql还要给放到nacos中）

#### 1.3 源码实现

> 一些思路
>
> 1. 优先看主干逻辑

##### 1.3.1 服务注册思路

先看客户端：

是基于applicationcontext的listener的机制来注册服务的。

1. 基于spring.factory注册启动监听配置类

   ![](E:\Document\work\笔记\nacos自动配置.png)

   其中会注册`NacosAutoServiceRegistration`这个bean，它是一个`applicationlistener`，监听的是`WebServerInitializedEvent`，之后在spring boot启动流程中，启动了webserver之后，就会启动注册流程。

2. 注册服务

   之后就会调用registry方法，如下：

   ```java
   @Override
   public void register(Registration registration) {
   
      if (StringUtils.isEmpty(registration.getServiceId())) {
         log.warn("No service to register for nacos client...");
         return;
      }
   
      NamingService namingService = namingService();
      String serviceId = registration.getServiceId();
      String group = nacosDiscoveryProperties.getGroup();
   
      Instance instance = getNacosInstanceFromRegistration(registration);
   
      try {
         namingService.registerInstance(serviceId, group, instance);
         log.info("nacos registry, {} {} {}:{} register finished", group, serviceId,
               instance.getIp(), instance.getPort());
      }
      catch (Exception e) {
         if (nacosDiscoveryProperties.isFailFast()) {
            log.error("nacos registry, {} register failed...{},", serviceId,
                  registration.toString(), e);
            rethrowRuntimeException(e);
         }
         else {
            log.warn("Failfast is false. {} register failed...{},", serviceId,
                  registration.toString(), e);
         }
      }
   }
   ```

   这里注册进去的servicename是groupname + @@ + servicename，这么整，所以就实现了group之间的隔离。



-------

更具体的，之后就是调用服务端提供的接口，1.x版本是基于http请求做的，之后的2.x是基于grpc来做的。

> 之后看服务端：
>
> 服务端的设计考虑了很多高并发的需求。
>
> 注册表的结构<namespace, <group, service>>，这里对应的数据结构是 ServiceManager - Service - Cluster
>
> 使用了copyonwrite的设计模式
>
> 最终的注册逻辑使用了异步实现，使用一个阻塞队列异步完成

1.  首先是服务端的接口收到服务要注册的请求，如下：

   ```java
   /**
    * Register new instance.
    *
    * @param request http request
    * @return 'ok' if success
    * @throws Exception any error during register
    */
   @CanDistro
   @PostMapping
   @Secured(parser = NamingResourceParser.class, action = ActionTypes.WRITE)
   public String register(HttpServletRequest request) throws Exception {
       
       final String namespaceId = WebUtils
               .optional(request, CommonParams.NAMESPACE_ID, Constants.DEFAULT_NAMESPACE_ID);
       final String serviceName = WebUtils.required(request, CommonParams.SERVICE_NAME);
       NamingUtils.checkServiceNameFormat(serviceName);
       
       final Instance instance = parseInstance(request);
       
       serviceManager.registerInstance(namespaceId, serviceName, instance);
       return "ok";
   }
   ```

2. 在从请求中解析出注册的实例之后，调用serviceManager发起真正的注册请求，即把实例注册到serviceMap中，它的结构是Map(namespace, Map(group::serviceName, Service))，即首先基于namespace做隔离，之后就是group，之后就是每个service中会划分集群。以下是具体执行的逻辑：

   ```java
   /**
    * Register an instance to a service in AP mode.
    *
    * <p>This method creates service or cluster silently if they don't exist.
    *
    * @param namespaceId id of namespace
    * @param serviceName service name
    * @param instance    instance to register
    * @throws Exception any error occurred in the process
    */
   public void registerInstance(String namespaceId, String serviceName, Instance instance) throws NacosException {
       // 首先看是否有对应的service，没有的话，就执行创建逻辑
       createEmptyService(namespaceId, serviceName, instance.isEphemeral());
       
       Service service = getService(namespaceId, serviceName);
       
       if (service == null) {
           throw new NacosException(NacosException.INVALID_PARAM,
                   "service not found, namespace: " + namespaceId + ", service: " + serviceName);
       }
       
       addInstance(namespaceId, serviceName, instance.isEphemeral(), instance);
   }
   ```

3. 之后做的就是把新注册的instance添加到对应的service中，即addInstance方法：

   ```java
   /**
    * Add instance to service.
    *
    * @param namespaceId namespace
    * @param serviceName service name
    * @param ephemeral   whether instance is ephemeral
    * @param ips         instances
    * @throws NacosException nacos exception
    */
   public void addInstance(String namespaceId, String serviceName, boolean ephemeral, Instance... ips)
           throws NacosException {
       
       String key = KeyBuilder.buildInstanceListKey(namespaceId, serviceName, ephemeral);
       
       Service service = getService(namespaceId, serviceName);
       
       synchronized (service) {
           List<Instance> instanceList = addIpAddresses(service, ephemeral, ips);
           
           Instances instances = new Instances();
           instances.setInstanceList(instanceList);
           // 这里是持久/临时 节点处理的分叉点
           consistencyService.put(key, instances);
       }
   }
   ```

   如果是持久化节点，采用的CP的模式来做的，由主节点去操作写数据库，并通知其他子节点更新，必须半数以上子节点写入成功，才算ok了；

   如果是临时节点，采用的是AP模式，当前节点把改动更新到内存，之后异步通知给订阅的节点，但凡是查询过该服务列表的节点都算是订阅节点。同时也会异步推送给集群中其他nacos节点。


##### 1.3.2 服务发现思路

客户端调用服务端的服务发现接口，取对应server的列表，同时也会起一个定时查询任务，更新缓存。

同时调用服务发现接口的时候，会传递过去udp端口，当对应service有变动的时候，就会主动发送udp的push消息。

##### 1.3.3 心跳机制

nacos运行过程中AP集群的信息同步主要是通过定时心跳任务完成的，所以定时线程池还是用的比较广泛的。

客户端注册的时候，就会起一个定时的**心跳任务**，同时服务端收到注册请求之后，如果是第一个注册的实例，就开启健康检查的**定时任务**，即轮询service中的所有实例是否心跳超时。

默认如果15s以上没有反应，就置为unhealthy，超过30s就删除实例。

当检查到某个服务的健康状态有变化时，即同步到其他服务。



服务端做健康检查的时候，就基于servicename的hash对服务的数量取模，确定对这个service做健康检查的机器。

同样，集群之间也会有**心跳检测**机制，这样才能保证多台机器对于service健康检查hash的一致。

##### 1.3.4 AP架构实现

是基于阿里整的distro协议实现的。

对于临时节点，集群中的每个服务都可以对节点做更新，更新完成之后会起一个异步的更新任务，同时不等信息同步结果，即返回给客户端，这种实现有利于高可用场景，但是牺牲了一些一致性，只能提供最终一致性。

##### 1.3.5 CP架构实现

对于持久节点的同步使用了CP架构，具体是基于raft协议来实现的。

https://www.cnblogs.com/luckygxf/p/9137841.html

raft和zab是paxos的简化，两者很类似，主要有两部分：

- 两阶段写入

  所有的leader以及follower之间的通信会以心跳的机制传递。

  leader收到请求，会先写入log，之后再执行和follower之间的同步操作

  更新操作会指向leader，首先leader向每个follower发送写入指令

  之后follower收到请求之后，写入数据，写入成功之后返回ack确认

  leader收到半数以上（包括自己）确认之后，即返回写入成功

- leader选举

  zk中每个节点都会参与选举，同时选票的权重不一致，事务编号越大，权重越大，节点id越大，权重越大，获取超过半数选票，则成为leader。

  raft没有那么复杂：

  每个节点进入随机的休眠状态，休眠150-300ms，节点醒过来之后，就发起投票，其他节点收到选票，即无条件同意，这样首先获取半数选票的节点即成为leader。之后leader开启数据同步指令，保证follower数据和leader保证同步。

https://thesecretlivesofdata.com/raft/

极致的一致性协议是等所有节点都写入成功才返回给客户端，但是这样牺牲了太多的可用性，性能太低，raft的设计中，只要半数以上节点写入成功，即返回成功。

**脑裂**

当一个集群出现网络分区，可能分出来的每个区都会选出一个新的leader，这样就出现数据不一致的情况。但是raft和zab都限制，只有获得半数以上选票才能成为新的leader，这就保证只能有一个leader产生，其他的被分区的节点不会对外提供服务，直到网络恢复。

**集群数量**

集群数量最好整成奇数，这样保证投票过程正常进行，以及出现分区的时候，能及时选举出新的leader。如果是偶数，并且恰好对半分，这样每一半都不能及时选举出新的leader。

**nacos源码CP实现**

之前的版本（1.4.x）具体是在`RaftConsistencyServiceImpl`实现的，持久化到文件。

是基于countdownlatch来实现半数以上写的。

**nacos心跳数据同步**

leader会定期把自己的数据key以及版本发送给集群中其他节点。

follower收到心跳数据之后，会比对发送过来的key以及版本，批量请求过期的key对应的数据，并做同步，同时删除不存在的key。

##### 1.3.6 nacos2.x实现

集群通信，集群客户端通信切换成为grpc，相对于1.x中基于udp的push服务，2.x中基于grpc的push服务更加健壮，客户端的轮询定时任务的重要性也就降低了。

大量使用事件驱动，事件处理本质是基于阻塞队列实现的，会有一个轮询的线程，从queue中取对应的事件，这样大量降低了代码的重复率，同样的逻辑就放到同样的event中，类似的event一起处理。

关键操作使用MetricsMonitor监听



**注册-查询逻辑**

1. 注册的时候，客户端把自己的连接信息放到请求中，并调用服务端注册接口
2. 服务端收到请求，从中解析到一个Service对象，主要用作索引，它的equals、hash方法已经被重写，之后就是数据检查：
   1. ServiceManager.getInstance().getSingleton(service)中，如果是第一个实例，即初始化singletonRepository以及namespaceSingletonMaps，第一个结构是service->service，第二个结构是namespace->set<service>
   2. 之后基于clientid初始化对应的client，存放客户端的连接信息，具体存放在`clientManager`中
   3. 发布了`ClientRegisterServiceEvent`事件，其中建立service和clientid之间的关联，具体是放在map中，结构为service->set<clientid>

3. 注册完成，有客户端想要订阅服务，其中一步就是基于前1 2步存放的信息，找到可用的服务，核心逻辑是在serviceStorage.getData(service)中实现的
   1. 首先基于构建的service对象，从单例池中找到对应service的单例对象
   2. 从前面存的service->set<clientid>结构中，找到所有的clientid
   3. 从clientManager从基于clientid获取具体的连接信息

4. 这样找到所有的原始信息，之后做的就是基于健康状态做进一步过滤。

这里是把1.x中那个大的map分散开了，之前是<namespace, < servicename, set<instance>>>。我理解的是，大概是为了分散大量并发请求的压力吧。前面每次查询之后，会把查询结果缓存下来。

**事件订阅**

- 客户端订阅

  客户端订阅的时候，会开启一个定时更新服务列表缓存的任务，默认间隔6s，如报错失败，则下次间隔逐步增加，最大到60s；同时调用服务端订阅接口，服务端收到请求之后，会记录订阅者信息，服务有变动的时候即主动推动。客户端取到服务列表之后，会缓存到本地文件。

- 服务端处理订阅

  对于一个服务，会维护一个订阅者的列表。对于列表中的client，当服务有变动的时候，会向订阅者推送变动之后的信息。

对于事件订阅有个问题，客户端发出订阅请求之后，服务端会首先查一下最新的列表，之后还会向订阅的client推一下信息，这样子就是主动推了两次，单就这里的逻辑而言，看起来第二次推送是没有必要的，因为列表已经在返回数据里面就有了。

**健康检查&连接建立**

- 服务端

  定期检查所有连接，依次检查是否有超过20s没有联系的连接，之后对这些连接做探活操作，之后就删掉确认失效的节点。1.4.x版本也这么整的话，会更加频繁地创建、关闭连接，对性能有影响，但是2.x的长连接就不会有太大的损耗。

  删除无效连接，有两部分：

  1. 删除该连接的所有订阅信息
  2. 删除该连接发布的所有服务，并push到订阅服务的节点

  之后做的是同步到集群中的其他节点。这里同步的时候看起来会有点疑惑，同步到其他节点，其他节点收到数据之后，发起ServiceChangedEvent的事件，这里又会push到订阅节点，这里会重复push吗。TODO 应该不会这个样子

- 客户端

  客户端连接服务启动的时候，会启动一个健康检查的线程，定期检查当前连接状态，做健康检查，或者重连。

### 2. 配置中心

这里同样是基于nacos来做的，2.x同样是基于grpc实现客户端服务端通信

#### 2.1 核心接口

基本配置中心的功能就是这个接口定义的，核心接口ConfigService

```java
/*
 * Copyright 1999-2018 Alibaba Group Holding Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.alibaba.nacos.api.config;

import com.alibaba.nacos.api.config.listener.Listener;
import com.alibaba.nacos.api.exception.NacosException;

/**
 * Config Service Interface.
 *
 * @author Nacos
 */
public interface ConfigService {
    
    /**
     * Get config.
     *
     * @param dataId    dataId
     * @param group     group
     * @param timeoutMs read timeout
     * @return config value
     * @throws NacosException NacosException
     */
    String getConfig(String dataId, String group, long timeoutMs) throws NacosException;
    
    /**
     * Get config and register Listener.
     *
     * <p>If you want to pull it yourself when the program starts to get the configuration for the first time, and the
     * registered Listener is used for future configuration updates, you can keep the original code unchanged, just add
     * the system parameter: enableRemoteSyncConfig = "true" ( But there is network overhead); therefore we recommend
     * that you use this interface directly
     *
     * @param dataId    dataId
     * @param group     group
     * @param timeoutMs read timeout
     * @param listener  {@link Listener}
     * @return config value
     * @throws NacosException NacosException
     */
    String getConfigAndSignListener(String dataId, String group, long timeoutMs, Listener listener)
            throws NacosException;
    
    /**
     * Add a listener to the configuration, after the server modified the configuration, the client will use the
     * incoming listener callback. Recommended asynchronous processing, the application can implement the getExecutor
     * method in the ManagerListener, provide a thread pool of execution. If not provided, use the main thread callback, May
     * block other configurations or be blocked by other configurations.
     *
     * @param dataId   dataId
     * @param group    group
     * @param listener listener
     * @throws NacosException NacosException
     */
    void addListener(String dataId, String group, Listener listener) throws NacosException;
    
    /**
     * Publish config.
     *
     * @param dataId  dataId
     * @param group   group
     * @param content content
     * @return Whether publish
     * @throws NacosException NacosException
     */
    boolean publishConfig(String dataId, String group, String content) throws NacosException;
    
    
    /**
     * Publish config.
     *
     * @param dataId  dataId
     * @param group   group
     * @param content content
     * @param type    config type {@link ConfigType}
     * @return Whether publish
     * @throws NacosException NacosException
     */
    boolean publishConfig(String dataId, String group, String content, String type) throws NacosException;
    
    /**
     * Cas Publish config.
     *
     * @param dataId  dataId
     * @param group   group
     * @param content content
     * @param casMd5  casMd5 prev content's md5 to cas.
     * @return Whether publish
     * @throws NacosException NacosException
     */
    boolean publishConfigCas(String dataId, String group, String content, String casMd5) throws NacosException;
    
    /**
     * Cas Publish config.
     *
     * @param dataId  dataId
     * @param group   group
     * @param content content
     * @param casMd5  casMd5 prev content's md5 to cas.
     * @param type    config type {@link ConfigType}
     * @return Whether publish
     * @throws NacosException NacosException
     */
    boolean publishConfigCas(String dataId, String group, String content, String casMd5, String type)
            throws NacosException;
    
    /**
     * Remove config.
     *
     * @param dataId dataId
     * @param group  group
     * @return whether remove
     * @throws NacosException NacosException
     */
    boolean removeConfig(String dataId, String group) throws NacosException;
    
    /**
     * Remove listener.
     *
     * @param dataId   dataId
     * @param group    group
     * @param listener listener
     */
    void removeListener(String dataId, String group, Listener listener);
    
    /**
     * Get server status.
     *
     * @return whether health
     */
    String getServerStatus();
    
    /**
     * Shutdown the resource service.
     *
     * @throws NacosException exception.
     */
    void shutDown() throws NacosException;
}
```

#### 2.2 配置优先级

往env中加的时候，是有一个优先级的。

想要添加多个配置文件，有两种方式

- sharedConfigs

  逻辑语义上是公共配置，是先拉取的，优先级低

- extensionConfigs

  是本应用自己的配置，优先级高

这里的优先级是根据加载顺序体现的，加载越靠后，配置就优先级越高，这里从上到下是：

1. applicationname-profile.file-extension
2. applicationname.file-extension
3. applicationname
4. extensionConfigs
5. shardConfigs

其中file-extension是配置的后缀

#### 2.3 配置加载

> 这里来还前面没好好看environment的债了，太多了

**spring cloud父容器启动**

如果引入了spring cloud context，在run方法的prepareEnvironment方法中，会嵌套启动一个spring cloud容器，它会作为spring boot容器的父容器。

```java
private ConfigurableEnvironment prepareEnvironment(SpringApplicationRunListeners listeners,
      ApplicationArguments applicationArguments) {
   // Create and configure the environment
   ConfigurableEnvironment environment = getOrCreateEnvironment();
   configureEnvironment(environment, applicationArguments.getSourceArgs());
   ConfigurationPropertySources.attach(environment);
    // 这里会发布ApplicationEnvironmentPreparedEvent事件
   listeners.environmentPrepared(environment);
   bindToSpringApplication(environment);
   if (!this.isCustomEnvironment) {
      environment = new EnvironmentConverter(getClassLoader()).convertEnvironmentIfNecessary(environment,
            deduceEnvironmentClass());
   }
   ConfigurationPropertySources.attach(environment);
   return environment;
}
```

springboot容器发布ApplicationEnvironmentPreparedEvent事件之后，BootstrapApplicationListener监听到事件之后，即初始化spring cloud容器，具体是在bootstrapServiceContext方法中实现。基于springapplicationbuilder构建，代码如下：

```java
SpringApplicationBuilder builder = new SpringApplicationBuilder()
      .profiles(environment.getActiveProfiles()).bannerMode(Mode.OFF)
      .environment(bootstrapEnvironment)
      // Don't use the default properties in this builder
      .registerShutdownHook(false).logStartupInfo(false)
      .web(WebApplicationType.NONE);
final SpringApplication builderApplication = builder.application();
if (builderApplication.getMainApplicationClass() == null) {
   // gh_425:
   // SpringApplication cannot deduce the MainApplicationClass here
   // if it is booted from SpringBootServletInitializer due to the
   // absense of the "main" method in stackTraces.
   // But luckily this method's second parameter "application" here
   // carries the real MainApplicationClass which has been explicitly
   // set by SpringBootServletInitializer itself already.
   builder.main(application.getMainApplicationClass());
}
if (environment.getPropertySources().contains("refreshArgs")) {
   // If we are doing a context refresh, really we only want to refresh the
   // Environment, and there are some toxic listeners (like the
   // LoggingApplicationListener) that affect global static state, so we need a
   // way to switch those off.
   builderApplication
         .setListeners(filterListeners(builderApplication.getListeners()));
}
builder.sources(BootstrapImportSelectorConfiguration.class);
final ConfigurableApplicationContext context = builder.run();
// gh-214 using spring.application.name=bootstrap to set the context id via
// `ContextIdApplicationContextInitializer` prevents apps from getting the actual
// spring.application.name
// during the bootstrap phase.
context.setId("bootstrap");
// Make the bootstrap context a parent of the app context
addAncestorInitializer(application, context);
// It only has properties in it now that we don't want in the parent so remove
// it (and it will be added back later)
bootstrapProperties.remove(BOOTSTRAP_PROPERTY_SOURCE_NAME);
mergeDefaultProperties(environment.getPropertySources(), bootstrapProperties);
```

这里，把source配置成了BootstrapImportSelectorConfiguration，这里source参数即springboot启动时传入的主类，这里传入的是一个使用Import注解修饰的配置类，从spring.factory以及环境变量中取要加载的配置类，如下：

```java
ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
// Use names and ensure unique to protect against duplicates
List<String> names = new ArrayList<>(SpringFactoriesLoader
      .loadFactoryNames(BootstrapConfiguration.class, classLoader));
names.addAll(Arrays.asList(StringUtils.commaDelimitedListToStringArray(
      this.environment.getProperty("spring.cloud.bootstrap.sources", ""))));

List<OrderedAnnotatedElement> elements = new ArrayList<>();
for (String name : names) {
   try {
      elements.add(
            new OrderedAnnotatedElement(this.metadataReaderFactory, name));
   }
   catch (IOException e) {
      continue;
   }
}
AnnotationAwareOrderComparator.sort(elements);

String[] classNames = elements.stream().map(e -> e.name).toArray(String[]::new);

return classNames;
```

而nacos的一些初始化类也就在其中，中间有两个很有意思的东西：

- com.alibaba.cloud.nacos.NacosConfigBootstrapConfiguration
- com.alibaba.cloud.nacos.discovery.configclient.NacosDiscoveryClientConfigServiceBootstrapConfiguration

这俩一个是配置中心一个是服务发现的配置类。

在看environment之前，先做个有意思的东西，猜一下这俩东西会做什么事情，先看config好了

- [ ] 这两部分应该都是这一版nacos启动的入口，因为目前只有这俩被加载了，spring boot的容器还没有refresh
- [ ] config这边要做的第一件事情应该就是启动configservice客户端，方便之后从远端拉取配置
- [ ] 还有一个不确定的，就是注册监听器，这个是在spring boot刷新完成之后，发布一个事件，之后就启动监听，不过这一步可能是基于springboot自动配置来做的

之后就是走的正常的environment准备、applicationcontext准备、refresh工作，完成之后，把spring cloud容器配置成spring boot容器的父容器，之后即返回。

**配置加载**

nacos应该觉得本地配置就放在父容器中，其他的部分都是可以考虑放到nacos配置中心的，所以才考虑这么做的吧。但是后面的版本中就不用这种设计思路了，没有强依赖spring cloud context做处理，直接在spring boot 容器中处理就完了，应该是考虑到执行效率的问题，容器启动应该是一个很重的操作，其中包括了大量文件扫描、反射等消耗事件的部分，所以nacos就不依赖spring cloud的上下文了。

nacos是依赖PropertySourceLocator接口加载云端的配置的，具体是在PropertySourceBootstrapConfiguration中初始化容器的时候被加载进来的。

这里是有一个加载顺序：

```java
// 加载共享配置
loadSharedConfiguration(composite);
// 加载自己的其他配置
loadExtConfiguration(composite);
// 加载基于spring.application.name解析出来的配置，它也会有一个顺序
// application.name
// application.name.格式
// application.name-profile.格式
loadApplicationConfiguration(composite, dataIdPrefix, nacosConfigProperties, env);
```

这里的加载顺序和它们的优先级相反。加载的过程中，会优先使用本地缓存，缓存没有，则从云端请求。

#### 2.4 配置刷新

想要bean动态感知配置的变化，可以使用refreshscope

**refreshscope和schedule注解一起使用的时候会有些问题**

因为刷新配置本质上是把cache中的bean清空，这样直到bean下次被调用，其中的定时任务不会被启动。

**refreshscope**

scope即表明bean存活的作用域，spring中已经声明的scope有

- request

- session

- application

  前三者分别是保证同一个request、session、applicationcontext中的bean是同一个

- refresh

  表示bean是可以在spring运行中刷新，具体逻辑是getBean的时候是把bean放到一个map中，而map可以清空的，清空之后，其中的bean就要重新create

- singleton

  单例bean

- prototype

  原型bean

`refreshscope`是spring中的概念，applicationcontext刷新完毕，会在finishRefresh中发布ContextRefreshedEvent事件，之后RefreshScope监听到该事件，即初始化所有scope为refresh的bean，这里是把对应的bean放到refreshscope的map中，缓存下来。

针对refreshscope注解修饰的bean，在会注册一个对应的factorybean，其getarget方法返回的是一个代理对象，代理对象每次执行方法的时候，都会从beanfactory中重新取bean，就是从缓存中取。

这样，nacos更新了配置，就刷新了缓存，那么注入的对象再次执行方法的时候，就取到了一个新的对象。

配置刷新的时候

#### 2.5 refreshscope加载过程

这里具体整理下refreshscope的加载过程，包括从bean扫描，到依赖注入，到刷新。

首先是扫描bean的时候，发现scope的proxyMode是ScopedProxyMode.TARGET_CLASS的时候，使用原bean的名称注册一个factorybean，其getObject是利用ProxyFactroy构建的代理bean，下面是解析method bean时候对scope的处理，代理bean的作用是调用bean对象的时候，会首先从cache中取bean，如果没有即构建。

```java
// Consider scoping
// 首先取proxymode
ScopedProxyMode proxyMode = ScopedProxyMode.NO;
AnnotationAttributes attributes = AnnotationConfigUtils.attributesFor(metadata, Scope.class);
if (attributes != null) {
   beanDef.setScope(attributes.getString("value"));
   proxyMode = attributes.getEnum("proxyMode");
   if (proxyMode == ScopedProxyMode.DEFAULT) {
      proxyMode = ScopedProxyMode.NO;
   }
}

// Replace the original bean definition with the target one, if necessary
BeanDefinition beanDefToRegister = beanDef;
if (proxyMode != ScopedProxyMode.NO) {
  // 如果是代理bean，这里基于原有的beandefinition构造一个代理bd，构造的过程中会把原有的代理bd注册到registry中，并把autowiredcandidate配置为false，防止属性注入的时候找到了原bean
   BeanDefinitionHolder proxyDef = ScopedProxyCreator.createScopedProxy(
         new BeanDefinitionHolder(beanDef, beanName), this.registry,
         proxyMode == ScopedProxyMode.TARGET_CLASS);
   beanDefToRegister = new ConfigurationClassBeanDefinition(
         (RootBeanDefinition) proxyDef.getBeanDefinition(), configClass, metadata, beanName);
}

if (logger.isTraceEnabled()) {
   logger.trace(String.format("Registering bean definition for @Bean method %s.%s()",
         configClass.getMetadata().getClassName(), beanName));
}
// 注册配置好的代理bean
this.registry.registerBeanDefinition(beanName, beanDefToRegister);
```

之后，在applicaitoncontext刷新的过程中，刷新完，会发布ContextRefreshedEvent事件，事件被RefreshScope捕捉到，会初始化所有scope为refresh的bean，具体调用getbean。

```java
private void eagerlyInitialize() {
   for (String name : this.context.getBeanDefinitionNames()) {
      BeanDefinition definition = this.registry.getBeanDefinition(name);
      if (this.getName().equals(definition.getScope())
            && !definition.isLazyInit()) {
         Object bean = this.context.getBean(name);
         if (bean != null) {
            bean.getClass();
         }
      }
   }
}
```

之后就到了beanfactory中获取bean，对于scope不是原型和单里的bean，创建交给了对应的scope对象，具体如下：

```java
Scope scope = this.scopes.get(scopeName);
if (scope == null) {
   throw new IllegalStateException("No Scope registered for scope name '" + scopeName + "'");
}
try {
   Object scopedInstance = scope.get(beanName, () -> {
      beforePrototypeCreation(beanName);
      try {
         return createBean(beanName, mbd, args);
      }
      finally {
         afterPrototypeCreation(beanName);
      }
   });
   bean = getObjectForBeanInstance(scopedInstance, name, beanName, mbd);
}
```

而对于refreshscope，getbean的时候，会从cache中取，如果cache中没有，再走正常的构建流程，如下：

```java
@Override
public Object get(String name, ObjectFactory<?> objectFactory) {
   BeanLifecycleWrapper value = this.cache.put(name,
         new BeanLifecycleWrapper(name, objectFactory));
   this.locks.putIfAbsent(name, new ReentrantReadWriteLock());
   try {
     // 这里涉及bean的缓存，如果有就返回没有就构建
      return value.getBean();
   }
   catch (RuntimeException e) {
      this.errors.put(name, e);
      throw e;
   }
}
```

这样走了一圈，对于refreshscope的bean，如果缓存没有刷新，具体使用体验跟单例bean没有太大的区别，但是如果env刷新了，那么上面的cache就要被清空，之后再调用代理bean的时候，就会重新创建bean。

另外，有一点要注意的是，这种刷新机制是针对依赖注入的场景做的，原始bean的autowiredcandidacate被配置成了false，这样就不会被注入，如果是通过getBeanz这种方式直接取bean，大概率会取到原始bean，如下：

![](E:\Document\work\笔记\getbeanforrefreshscope.png)



配置加载的时候，如果有要求刷新，会注册监听器，当云端配置变化的时候，会回调监听器。而监听器会调用ContextRefresher的refresh方法，如下：

```java
public synchronized Set<String> refresh() {
   Set<String> keys = refreshEnvironment();
   this.scope.refreshAll();
   return keys;
}
```

做的第一步即刷新环境，新创建一个容器，只添加和环境相关的监听器，容器初始化完成，就获取了目前最新的environment。之后发布EnvironmentChangeEvent事件，其中使用**ConfigurationProperties**修饰了的bean会同步刷新，即重新调用其初始化前后的方法，它们就不用使用refreshscope的方式来做了，但是，如果这种也不能满足，就只能添加refreshscope的注解了。

之后清空refreshscope中的缓存。

> 所以自己的一点思考，这里也会同时把本地文件也给刷新上去。

#### 2.6 事件驱动模型

**发布订阅模式**

nacos的事件驱动模型，是基于阻塞队列实现的

核心是定义好的事件，针对某个事件，可以定义多个监听器，监听器可以注册到对应的事件发布器。

这样就是有事件发布的时候，往阻塞队列放事件，同时事件发布器的处理器会循环take队列，依次调用注册的订阅者的处理方法。



角色：

- 事件

- 事件发布者

  保证每个订阅者都能处理对应的事件

- 事件订阅者

  主动向发布者注册，由发布者调用订阅者的对应处理方法

- 通知中心

  存储所有的事件发布者，发布事件的时候，找到具体的事件发布者

**事件监听**

？ 说和事件监听有区别，是因为没有消息队列吗，没办法做缓冲

spring中的事件监听默认不是异步处理的。



这里讲的比较模糊，nacos和spring都会有订阅者、订阅者注册、发布事件的概念，但是nacos中使用阻塞队列存放发过来的事件，spring则是直接从注册的订阅者中找到目标，默认同步执行，前者应该是更利于并发量比较大的场景，spring这种处理机制主要是在启动，应该比较少用在业务逻辑。

#### 2.7 nacos的趋势

插件化开发



### 3. open feign

#### 3.1 使用

暂时只跟ribbon结合实现了

#### 3.2 扩展点

- 夹带私货

- 日志配置

  可以使用bean配置，或者在配置文件中做

  ```yaml
  feign:
    client:
      config:
        provider:
          logger-level: FULL
  # 打开对应包下面的日志级别
  logging:
    level:
      com.sgw: debug
  ```

  全局配置

  ```java
  @Bean
  public Logger.Level loggerLevel() {
      return Logger.Level.BASIC;
  }
  ```
  
  配置文件中的配置会覆盖全局配置。

- 拦截器

  示例：

  ```java
  @Bean
  public BasicAuthRequestInterceptor authRequestInterceptor() {
      return new BasicAuthRequestInterceptor("sgw", "123456");
  }
  ```

  具体实现是向请求中添加header，value是经过base64编码之后的内容。

  以上是全局配置，同样的，也可以针对对应服务做配置。

- 超时时间配置

  同样，可以在配置中配置对应服务的连接超时、请求处理超时。

  针对超时时间，后面会有对应的熔断、短路的组件。

- 压缩配置

  

- encoder & decoder 配置

- ribbon负载均衡配置

  - 全局

    可以直接声明实现IRule接口的bean，指定负载均衡策略

  - 也可以直接指定某个服务对应的负载均衡策略

    provider:

      ribbon:

    ​    NFLoadBalancerRuleClassName: com.alibaba.cloud.nacos.ribbon.NacosRule

#### 3.3 源码实现

> 实现机制和mybatis类似，beandefinitionregistry扫描有特定注解的接口，之后结合factorybean以及动态代理把bean注册进去。
>
> 调用链路
>
> 调用feign接口
>
> 走代理
>
> 根据spring mvc注解解析出具体调用url以及数据
>
> 解析host，基于给定负载均衡策略选择server

启动入口是@EnableFeignClients注解，其中会import一个bd注册类@Import(FeignClientsRegistrar.class)

之后注册类中做的事情：

1. 注册在EnableFeignClients中声明的通用配置

2. 依次处理每个FeignClient

   1. 注册声明的配置类

   2. 构建代理bean

      构建代理bean的时候提供了一个扩展点

      ```java
      Targeter targeter = get(context, Targeter.class);
      return (T) targeter.target(this, builder, context,
            new HardCodedTarget<>(type, name, url));
      ```

      即以上的Targeter，具体的代理对象即它创建的。所以，之后想要整一个sentinel的扩展，就可以实现一个针对sentinel的targeter。TODO 脑子有点大，先这样 参考 https://dzone.com/articles/spring-cloud-alibaba-sentinels-integration-with-fe

### 4. zookeeper

> 是比较古老的保证分布式一致性的中间件，因为保证了CP，面向**并发量不是太高**的分布式一致性场景。
>
> 尤其适合读多写少的场景，例如配置同步更新等，不适合大批量数据同步。
>
> 每个节点默认最多可以写1M的数据。

#### 4.1 理论基础

**CAP**

C 一致性

A 可用性

P 分区容错性

从理论和实践中，这三个只能同时满足其中两个，总体而言，P是必须要保证的，所以目前的分布式系统就是在CP和AP之间做选择。

前面讲的nacos的针对临时节点的集群架构，实现的思路即AP，中间的同步基本都是通过异步任务实现的，不会等到同步返回才返回，这样只能保证最终一致性，会产生一些不一致的场景，不能保证一致性。

> 思考：zk是强一致性的吗？
>
> 对于读操作，不是的，因为它的写是多数确认即直接返回，可以容忍少数节点写入失败，那么读这些少数节点就会有点问题。
>
> 写-强一致性 读-顺序一致性
>
> 因为它对一致性的保证，所以会对性能有一定的损耗。

**BASE原则**

是CP AP之间的折中，提出了 （BA）基本可用、（S）软状态、（E）最终一致性。满足AP的架构基本已经和BASE很靠近了，因为它可以保证

- 基本可用

部分节点出现故障，剩余节点仍可以提供服务

- 软状态

部分节点间的数据不一致

- 最终一致性

故障节点恢复之后，再同步数据，实现最终一致性。



有实现基本的监听机制，本质上是**分布式文件系统+监听机制**。是一个基于**观察者模式**设计的分布式服务管理框架。

**节点**

不适合存大量数据，一个节点默认1M。

一个节点的数据结构：

- data[] 存放的数据

- acl 访问控制

- stat 状态 版本号事务信息等

- children 子节点

节点类型，临时/持久，临时节点是跟session绑定的，当前sessionclose的时候，节点会消失。同时，客户端可以监听某一个节点的变化，这样，就可以实现类似配置监听 服务列表动态刷新 分布式锁这些功能。

**监听器**

监听的含义看起来是，只要查询到的内容有变化，就会触发监听通知，所以ls get stat这些可以查询东西的命令都可以加上一个-w属性。数据发生变化的时候，会把对应的变化事件类型推送过去，但是不会推送具体的信息，需要监听服务再次去拉。

1. 客户端注册wathcer
2. 服务端事件触发之后，顺序通知对应的wathcer，所以如果用这个机制实现分布式锁，可以实现成公平的。

3.6之后，新增了永久watch的机制。即使用addWatch命令，注释如下:

`addWatch [-m mode] path # optional mode is one of [PERSISTENT, PERSISTENT_RECURSIVE] - default is PERSISTENT_RECURSIVE`

意即监听某一个path，有两种模式，一种是只监听当前节点以及子节点的变化，另一种是递归监听的方式，默认采用了递归监听的方式。

**权限控制ACL**

**集群**

角色划分 follower leader observer，其中，follower和leader参与选举和事务，observer只作为只读副本，不参与选举与事务。

- leader选举

leader选举依赖两点，一个是客户端的事务id，一个是客户端的id，优先比较事务id，事务id相同，比较机器的id。

**ZAB**

保证了数据的一致性，主要包括消息广播、崩溃恢复两个范畴。

- 消息广播（两阶段提交）

以上三个角色中，只有follower能处理写事务，其他节点收到写请求之后，就会转发给leader。leader将修改提交到所有的follower节点，如果收到半数以上节点的ack反馈，即写入成功，给所有节点发commit，并返回成功信息给客户端。属于两阶段提交的概念。

- 崩溃恢复

如果leader失去了与过半follower的通信，就会进入崩溃恢复模式，会在发送完所有的提案或者确认之后崩溃，不对外提供服务。之后选举事务id最大的follower作为新的leader，新leader会继续处理事务中未提交的信息。

#### 4.2 场景

**协同服务**

master-worker协同服务，多个worker竞争一个leader，同时保证leader挂了再次竞争。

- 多个worker竞争创建 /master 的临时节点，只有一个worker可以创建成功，即成为leader

  `create -e /master "ip:port"`

- 同时worker以及leader可以互相监听

  - leader创建workers节点，同时监听workers节点

    `create /workers`

    `ls -w /workers`

  - worker节点也会监听

    `stat -w /master`

- worker监听到leader挂掉了，就可以重新竞争，同时leader监听到worker节点挂了，也可以做对应操作。

**乐观锁机制**

可以基于数据版本号实现基于版本号更新的机制，这里更新是原子性的，可以保证同时只能有一个节点修改成功，是一个分布式的CAS操作。

多个线程同时竞争资源的时候，可以采用这种方式，但是因为它的写入确认机制，性能不会太高，竞争激烈的场景性能扛不住。

**具体应用**

- dubbo

  分层api记录

- 动态dns解析

  记录dsn下节点信息

- 动态节点命名

  借助zk的顺序节点名称，创建临时节点，使用临时节点的name做名称

- 分布式id生成

  - java uuid

    完全无序，不太容器找规律

  - redis

  - twitter雪花算法

    这里是使用zk来生成对应的workerid，雪花算法是一个64位的序号，有效部分分为3个，时间戳+workerid+序号，核心实现是一个sync关键字修饰的生成方法，其中生成的时候会取当前的时间戳，比对上一次的时间戳，如果一致，序号++，否则从0开始计数，之后把三个部分拼装起来。

  - mongodb的自动生成id

- **注册中心**

#### 4.3 分布式锁

这个zk中比较重要的概念，常用的是基于redis和zk的实现。

本质上是提供给不同客户端一块共享的存储空间，这里会有数据库、zk、reids这些实现，它们都能提供保证原子性的操作，以确定哪个线程成功获取锁。

- mysql

  考虑竞争向表中插入相同主键的数据

  问题：

  - 死锁的问题，获取锁的进程处理逻辑的时候挂掉了，没有来得及删除锁标记，会造成持续性死锁。

- zookeeper

  竞争创建临时节点，成功则获取锁，失败等待。

  临时节点可以在客户端挂掉的时候自动删除，降低了死锁的风险。

  基于curator可以实现完全公平的锁。

  但是，因为加锁解锁频繁设计节点的创建删除，而zk的创建节点的时间会比较长，因而**效率不高**。

#### 4.4 注册中心

是基于zk的临时节点、监听机制可以实现注册中心。同样，因为它自身的CP机制，可以保证实现高一致性，但是效率不是太高。

#### 4.5 连接客户端

官方提供客户端

网飞给基于官方客户端封装的，curator。

### 5. 负载均衡

#### 5.1 实现逻辑

是利用`@LoadBalanced`注解实现的，这个注解中包含了`@Qualifier`注解，之后使用同样带有`@LoadBalanced`注解的注入点，获取所有带有该注解的bean，使用初始化完成所有非懒加载的单例bean之后的一个注入点`SmartInitializingSingleton`，统一处理这些东西。

1. ```java
   @Bean
   @LoadBalanced
   public RestTemplate restTemplate() {
       return new RestTemplate();
   }
   ```

2. ```java
   @LoadBalanced
   @Autowired(required = false)
   private List<RestTemplate> restTemplates = Collections.emptyList();
   ```

3. ```java
   @Bean
   public SmartInitializingSingleton loadBalancedRestTemplateInitializerDeprecated(
         final ObjectProvider<List<RestTemplateCustomizer>> restTemplateCustomizers) {
      return () -> restTemplateCustomizers.ifAvailable(customizers -> {
         for (RestTemplate restTemplate : LoadBalancerAutoConfiguration.this.restTemplates) {
            for (RestTemplateCustomizer customizer : customizers) {
               customizer.customize(restTemplate);
            }
         }
      });
   }
   ```

这里的核心功能是在拦截器中实现的，即拦截器中把请求中的servicename按照一定策略替换成对应的ip/端口。这里servicename到服务地址列表是通过请求注册中心取得的，策略就是下面说的负载均衡策略。

#### 5.2 负载均衡实现逻辑

- 全局逻辑

  直接配置IRule接口的bean

  ```java
  @Bean
  public IRule rule() {
      return new NacosRule();
  }
  ```

- 指定配置

  直接在配置文件中指定

  ```yaml
  provider:
      ribbon:
        NFLoadBalancerRuleClassName: com.netflix.loadbalancer.RoundRobinRule    
  ```

在做负载均衡调用的时候，是直接调用IRule类型的bean，调用其中的choose(key)，之后在该方法中调用ILoadBlancer获取可用服务，再依据给定逻辑选取其中之一，类似于下面的逻辑：

```java
public Server choose(ILoadBalancer lb, Object key) {
    if (lb == null) {
        log.warn("no load balancer");
        return null;
    }

    Server server = null;
    int count = 0;
    while (server == null && count++ < 10) {
        List<Server> reachableServers = lb.getReachableServers();
        List<Server> allServers = lb.getAllServers();
        int upCount = reachableServers.size();
        int serverCount = allServers.size();

        if ((upCount == 0) || (serverCount == 0)) {
            log.warn("No up servers available from load balancer: " + lb);
            return null;
        }

        int nextServerIndex = incrementAndGetModulo(serverCount);
        server = allServers.get(nextServerIndex);

        if (server == null) {
            /* Transient. */
            Thread.yield();
            continue;
        }

        if (server.isAlive() && (server.isReadyToServe())) {
            return (server);
        }

        // Next.
        server = null;
    }

    if (count >= 10) {
        log.warn("No available alive servers after 10 tries from load balancer: "
                + lb);
    }
    return server;
}
```

####  5.3 spring cloud中的替代品

网飞毕竟闭源了，spring cloud提供了开源替代品，是spring cloud common包下面的loadblancer，在目前最新的spring-cloud-alibaba中已经默认把ribbon给剔除了。

### 6. 流量治理

> 到这里看，这个真的是一个半成品都不能算，只能是能展示的demo，各位看下，我们是想要这么做，如果觉得可以，就交钱吧

- 资源
- 规则
  - qps
  - threadnum
  - 系统负载
- 降级

是基于调用链的模式来做处理的，包括统计、资源获取等。每个节点被称为slot，基于SPI的机制来加载对应的slot

![image-20220918104420081](E:\Document\work\笔记\sentinal通过spi加载slot.png)

#### 6.1 控制台

针对spring mvc，会有一个拦截器，拦截请求，之后获取sentinel资源，资源名称即请求的地址。之后客户端会向sentinel定时发心跳，同时控制台会向客户端请求所有的资源以及流控规则，资源只有在被访问，即url只有在被请求的时候，才会被注册到sentinel。

控制台上可以实时查看请求流量，并可以对流量进行控制，动态指定规则，指定规则之后，控制台会请求服务注册的时候给的端口传递给客户端，这样，客户端就能实时获取规则，并作出正确的响应。客户端默认监听的端口是8719，如果有多台，应该是默认自增。基于这种机制，想要在控制台实时控制规则，就要控制台和客户端所在的网络是打通的，这样才能正常下发规则。

同时，如果要在resttemplate或者feign中添加类似的功能，也可以考虑在拦截器中做了。

> 开源版本的规则默认是存在内存中的，服务重启之后，即丢失了，并且开源平台中不能同步给集群中的多个节点同时发布规则。

- 常用规则

  - 流控

    流控模式

    - 直接

      即直接对编辑的接口采取操作

    - 关联

      关联接口达到对应阈值之后，限制编辑接口

    - 链路关系

      当编辑接口达到对应阈值，入口接口被流控

    流控效果

    - 直接失败

      默认的模式，被流控拒绝了，直接丢弃

    - warm up

      针对系统冷启动的流控方式，一大波流量进来了，系统的处理速度从开始就1/3在给定时间内上升到正常值，中间过滤掉的请求直接丢弃

    - 排队等待

      超过设定速率的请求，即排队等待系统调用，如果系统能在给定的超时事件内能处理过来，即不丢弃，主要用于流量削峰的场景。

      基于漏斗算法实现。

  - 熔断降级

    熔断策略

    - 慢调用比例
    - 异常比例
    - 热点事件

    熔断降级，核心是在给定时间窗口，请求数量达到最小统计量，如果统计数量达到给定值，熔断器**打开**，直到熔断时间之后，进入**半开状态**，第一个请求决定熔断器继续打开还是关闭，如果请求超时或者抛异常，熔断器会再次打开，继续熔断给定时间，如果正常，则熔断器关闭。

  - 热点参数

    针对sentinel的SentinelResource注解以及7种基本参数生效，可以针对一个方法的参数的不同值采用不同的流控规则

  - 系统规则

    系统级别的规则，包括系统的load cpu使用率 入口qps等

  - 授权规则

    对资源的调用方，有一个白名单/黑名单，以控制调用

#### 6.2 sentinel结合feign

使用feign的常规插件应该是做不来这些东西，可以考虑的方案是参照hystrix，在生成的代理对象上动手。

![Image title](E:\Document\work\笔记\12111959-screen-shot-2019-06-29-at-121115-am.png)

如图，这里生成factorybean的时候，有两套，一个是feign的一个就是hystrix的。
