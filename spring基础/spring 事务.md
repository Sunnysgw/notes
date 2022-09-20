 

# spring 事务

## 1. 前置知识

- 事务的特性
  - 原子性
  - 一致性
  - 隔离性
  - 持久性

- 事务并发可能会出现的问题

  - 脏读

    因为读到了其他事务还没有提交的修改产生的问题

  - 不可重复读

    在其他事务对某一行做了修改前后读取到的数据不一样，导致的问题

  - 幻读

    在其他事务插入了多行前后读取的数据不一样，导致的问题

- 事务的隔离级别

  - read uncommit

    此时会有脏读

  - read commit

    解决脏读

  - repeatable read

    解决不可重复读，基于**行锁**实现，是**inoodb**默认的隔离级别

  - 串行读取

    并发的读取错误的问题都没了，但是会有很大的性能问题

- 事务的传播级别

- mysql的mvvc模型

  更具体的，是inoodb的mvvc模型，

 ## 2. spring事务相关的实现

> 只要是同一个事务，最基本的要求就是原子性，即对于同一个事务中的所有sql操作，必定是要么都执行，要么都不执行

- 入口

  开启事务注解EnableTransactionManagement之后，会在import中注册开关bean，默认是PROXY 的模式，此时会注入AutoProxyRegistrar、ProxyTransactionManagementConfiguration这俩bean。

  - AutoProxyRegistrar

    这里会引入InfrastructureAdvisorAutoProxyCreator这个类，是AbstractAdvisorAutoProxyCreator的子类，目的就是扫描到要处理的地方，并使用代理处理。

  - ProxyTransactionManagementConfiguration

    中间会注册关于事务相关的advisor，把开始事务的类和方法过滤并缓存出来。其中方法注解中解析出来的内容会放到RuleBasedTransactionAttribute这个对象中。

  到这里，就是可以保证可以扫描到事务注解标注的类和方法，下一步就是调用的时候

- 事务执行原理

  入口是invokeWithinTransaction，能走到这一步，说明已经在代理类那里经过过滤，方法头上使用了Transaction注解。

  首先取到注解上的参数，保存到TransactionAttribute的子类中，之后，取到TransactionManager;

  调用createTransactionIfNecessary方法，基于前面解析出来的Transaction注解配置参数判断是否需要创建事务，如需要则创建，默认事务的名称是当前执行方法的名称。

  首先调用doGetTransaction方法获取当前存在的事务信息，这里是基于当前的datasource从threadlocal对象resources中获取当前的conn，之后封装成DataSourceTransactionObject对象返回，除了嵌套调用的事务，一般这里取到的都是null。

  之后判断是否有取到connection对象，根据是否有事务决定下一步策略，这里的策略是由当前的事务传播机制确定的。

  - 之前已经存在了事务

    进入handleExistingTransaction方法处理

    判断传播机制

    - PROPAGATION_NEVER（不允许当前线程存在事务）

      直接报错

    - PROPAGATION_NOT_SUPPORTED（当前方法中不支持事务）

      因为当前方法不需要事务，所以直接把前面的事务挂起，之后保存当前的事务状态，事务对象为null

    - PROPAGATION_REQUIRES_NEW

      挂起之前的事务

      开启新的事务

    - PROPAGATION_NESTED（父子事务）

      这里有一个概念是savepoint，如果这里创建的事务要回滚，则回滚到这个savepoint

      

  - 之前不存在事务

    判断传播机制

    - PROPAGATION_MANDATORY

      直接报错，因为这个传播机制要求当前一定要有事务存在

    - PROPAGATION_REQUIRED（默认传播机制，要求存在事务，如没有则新建，有的话则不用关心）

    - PROPAGATION_REQUIRES_NEW（要求必须创建一个新的事务）

    - PROPAGATION_NESTED（要求创建父子事务）

      以上三种情况下，都会去调用startTransaction创建一个新的事务。

      首先在使用suspend方法初始化当前的事务信息，这里suspend方法的作用是，如果有传入事务对象，则挂起之前的事务，并设置到当前事务信息中，同时初始化当前的事务信息，这里调用suspend是用的初始化当前事务信息的功能。

      之后doBegin方法中基于构建好的definition初始化事务对象：

      1. 创建数据库连接对象，并设置连接对象的readonly属性以及事务的隔离级别

      2. 将conn对象的AutoCommit属性设置为false

      3. 将第一步创建好的conn对象绑定到前面的threadlocal中，方便后面获取

         > **这里有一点，在mybatis执行sql操作的时候，首先就是从这里取conn，如果有，并且SynchronizedWithTransaction为true，则使用。**

  到这一步就已经基于不同的情况取到了当前的事务对象，下一步要做的是把当前的事务信息绑定到threadlocal对象中，方便后面获取。

  

  之后做的是如果捕捉到了异常，就处理事务回滚。

  所有事情都处理完之后，在finally块中清除当前线程中的事务信息。

  最后提交当前事务。

  

