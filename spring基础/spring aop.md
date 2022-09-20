## 代理相关的概念

- advisor

  包含切入点和切入方法

- 切点 pointcut 

  意即在哪里做切入

- 切入方法 advice 

  包括 运行前 返回后 抛出异常后 最终finally 环绕 五种

  spring支持的advice有以下几种

  - MethodInterceptor

  - MethodBeforeAdviceAdapter

  - AfterReturningAdviceAdapter

  - ThrowsAdviceAdapter

    这个比较有意思，这个ThrowsAdvice接口内容是空的，解析这个advice的时候，从接口实现中扫描约定好的方法。

  其中MethodInterceptor是能够直接支持的，如果是其他的的advice，就使用对应的适配器转化成MethodInterceptor。

  定义advisor的时候，有个参数是runtime，如果为true，则再对代理对象方法的参数做下过滤。

  这里会有两次匹配

  - 第一次是初始化的时候，判断在处理的bean是否命中某些advisor

    第一次匹配的时候，会把spring中所有的advisor以及使用aspectj注解修饰的bean，并缓存下来

  - 第二次是代理对象真正执行的时候，会判断有哪些advisor和当前执行的方法匹配

- joinpoint 连接点

  具体指带方法的运行，真正执行代理逻辑的方法会有一个joinpoint的对象，基于这个对象，可以执行被代理对象的方法

spring中给提供了ProxyFactory给我们封装了代理的实现

## spring aop实现

> 看起来是spring解析到我们使用aspect注解定义的些切入点，之后就在初始化后的方法中依次做匹配，如果我们用注解定义的规则命中了当前的bean，就使用代理对象替换原始对象，并加上切面方法。

### 1. 开启aop

这里使用这个注解EnableAspectJAutoProxy，注解中会import一个类AspectJAutoProxyRegistrar，这个类会把处理aop的beanpostprocessor注册到bean工厂中：

```java
AopConfigUtils.registerAspectJAnnotationAutoProxyCreatorIfNecessary(registry);
```

### 2. 依次处理bean

在bean初始化后，会判断该bean有没有命中aop的逻辑，如果有命中，就使用代理对象替代原对象。其中有几个要注意的点：

- 对于注入点，即advisor的筛选是在bean初始化完之后才做的，在处理第一个bean的时候，就把手动生命的advisor以及通过aspectj注解声明的advisor筛出来，并初始化过，之后放到缓存（map）中。
- 如果一个bean要进行aop处理，就要spring中的ProxyFactory来构造对应的代理对象，构造的过程中会根据实际情况选择使用cglib还是jdk动态代理。

**cglib or jdk动态代理**

```java
// 满足如下条件 会用cglib
if (!NativeDetector.inNativeImage() &&
      (config.isOptimize() || config.isProxyTargetClass() || hasNoUserSuppliedProxyInterfaces(config)))
```

一般来说，如果有目标接口，默认是使用jdk动态代理来做，但是也会有几个可控制的参数包括isOptimize isProxyTargetClass这些。

**EnableAspectJAutoProxy注解的属性**

- ProxyTargetClass

  这么配置了之后，就会使用cglib代理

- exposeProxy

  会有这么个参数，如果为true，就会把当前的代理对象放到当前线程中











spring还有哪些地方可以用到动态代理，解析到lazy的时候，aop代理，lookup对象





