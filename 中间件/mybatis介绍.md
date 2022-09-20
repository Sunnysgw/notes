# mybatis 介绍

> mybatis是一个**半自动的ORM**(Object Relation Model)框架，它是在JDBC的基础上做的封装，提升业务处理过程中的效率。

jdbc的四个核心对象 DriverManager conn PreparedStatement ResultSet。

下面是jdbc的原始编码的方式：

```java
Connection connection = DriverManager.getConnection("jdbc://mysql://127.0.0.1:3306", "username", "password");
connection.setAutoCommit(false);
PreparedStatement preparedStatement = connection.prepareStatement("select * from userinfo");
preparedStatement.execute();
connection.commit();
connection.close();
```

1. 硬编码 连接地址 密码
2. 资源消耗 频繁创建 关闭连接
3. 数据库压力大，对热点数据没有做缓存
4. 参数传输 结果解析 繁杂

## mybatis原始配置文件

xml配置文件使用 XMLConfigBuilder 解析

settings

数据库环境

类型处理器

别名处理器

插件 可以理解成拦截器

mapper（xml）—— crud resultmap namespace 使用 XMLMapperBuilder 来解析



二级缓存

用到了装饰器模式，是同一个namespace中的sqlsession是共享缓存的，默认的缓存溢出策略是lru，对于缓存会有多种策略，包括具体怎么存、淘汰策略、过期策略，对于每一层，它们的构造方法都会加上上级的缓存对象，这样，在调用get set 方法的时候，会首先执行当前的业务逻辑，之后调用下一层的对应get set 方法，是一个链路的模式，职责单一。最外层的涉及并发的地方都是用sync修饰。

现在已经不太用二级缓存了？因为不安全



解析sql语句 解析成静态 or 动态的过程 如果sql语句除了参数其他都确定了，那么就解析成静态的，否则解析成动态的，每一个sql语句节点都解析成sqlnode的形式，中间用到了递归的方式。

# mybatis 执行

### 1. sqlsession

门面模式

提供了可以进行的操作，之后使用executor来做具体的操作，

所有的crud节点都会解析成mapperedstatement

插件使用代理的方式来做 ，比较有用的插件，像pagehelper这种就是用插件来做的。 **可以看下怎么自己写下pagehelper**

解析sql 把前面构建的sqlnode依次解析，是调用apply方法，结合参数解析成对应的语句

static语句直接加到string语句中

if 使用 **ognl**表达式来判断是否匹配，如果匹配，就接着解析if中的node

对于mixedsqlnode，就依次解析其中的node

xml定义的时候 trim和 where set基本是等价的，trimsqlnode是wheresqlnode、setsqlnode的父类

 执行sql 结果映射



**动态数据源**怎么做的？



statementhandler

parameterhandler

resultsethandler



创建执行器  batch reuse simple，这里同样用了装饰器模式，如果选择使用二级缓存，就使用CachingExecutor把构造好的executor再包装一下，它们的继承关系如下：

![executor继承关系](E:\Document\work\笔记\Executor.png)

这样，大家都是executor，只是如果使用了缓存，就在外面再封装一层，因为都实现了executor接口，所以方法该怎么调用就怎么调用，只不过中间使用类似插件的方式多加了几层。

二级缓存的具体实现是在cachingexecutor中做的，它是mappedstatement中的一个属性，mybatis具体做查询操作的时候，会取到对应的ms，这里保证取到ms是一样的，大家肯定就是会用同样的缓存。

首先从二级缓存中取 之后从一级缓存中取，如果再没有，就从数据库中取。

一级缓存默认开启，二级缓存需要配置开启，但是二级缓存一般不会怎么用。



sqlsession 的生命周期



