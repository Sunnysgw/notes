# spring mybatis 整合

> 整合的目的是为了把mybatis查询功能的对象作为一个bean注册到spring 容器中

在mybatis中，有这几种重要的角色：

- datasource

  存储具体的数据库连接信息，同时用于建立并管理和数据库之间的连接，生产环境会采用连接池的方式实现。

- sqlsession

  对外暴露了具体的crud操作

- Executor

  sqlsession中使用executor做具体的操作

- sqlsessionfactory

  基于datasource构建sqlsession

## 1. spring整合mybatis过程

整个整合的过程即把定义好的mybatis操作封装成bean，注册到Spring 容器。

1. 使用MapperScan注解开启扫描dao接口

   MapperScan注解中注册了MapperScannerConfigurer类，该类实现了BeanDefinitionRegistryPostProcessor接口，而在接口的postProcessBeanDefinitionRegistry方法中，使用自定义的扫描器ClassPathMapperScanner扫描注解basePackages属性中配置的路径，这里自定义的扫描器重新定义了候选人的范围，默认只会扫描所有包含方法的接口，扫描规则如下：

   ```java
   return beanDefinition.getMetadata().isInterface() && beanDefinition.getMetadata().isIndependent();
   ```

   扫描到的接口，之后借助FactoryBean的机制给包装成bean，这里用的是MapperFactoryBean.class。它的getObject方法即返回对应的代理bean。







1. 声明扫描注解，同时在注解中使用import注解获取扫描路径

2. 使用spring 的scanner扫描路径下的所有接口，并注册到容器中

3. 定义一个sqlsessionfactory的bean

   

mybatis生成sqlsession的方式不太一样

mybatis涉及**一级缓存**、二级缓存



这个是干嘛的  SqlSessionTemplate

多个线程并发的使用sqlsession的时候，默认实现不是线程安全的，实际是使threadlocal实现的，保证每个线程取到的sqlsession不一样

**如果不开启事务，一级缓存会失效（面试）**，因为默认串行执行的多个sql调用，认为它们是独立的



不开启事务 又想用一级缓存

## 1. 自定义mybatis启动流程

> 核心还是在ConfigurationClassPostProcessor，它实现了BeanDefinitionRegistryPostProcessor接口，这个接口允许向beanfactory中添加beandefinition

Modify the application context's internal bean definition registry after its standard initialization. All regular bean definitions will have been loaded, but no beans will have been instantiated yet. This allows for adding further bean definitions before the next post-processing phase kicks in.

经过应用标准的初始化之后，对内部的bd做调整。这里，所有常规的bd会被加载，但是这一步不会有bean被初始化。这里允许在下一个处理阶段开始前加载更多的bd。

mybatis中，框架将代码和sql语句分离，我们可以直接调用接口中的方法，之后mybatis根据我们执行的方法找到对应的sql语句，并执行。这里用到了jdk动态代理，具体的代理方式之后做说明，这里关心的是如何把这些接口给注册成bean，同时将具体的bean实现替换成对应的代理对象。

这里使用了Import注解，在Import注解中引入实现ImportBeanDefinitionRegistrar接口的对象，该接口的registerBeanDefinitions会在所有常规注解处理完之后被调用，其中可以获取配置类上的所有注解信息，包括要扫描的mapper的位置，之后就使用自定义的ClassPathBeanDefinitionScanner对象扫描对应路径，把所有的有方法的接口扫描出来，之后处理扫描出来的bd，使用beanfactory的方式实现替换beanobject的效果，在beanfactory的getObject中生成对应的代理对象。

##  2.mybatis的一些点

- mybatis中引入了一级缓存的概念，但是在spring中引入mybatis之后，一级缓存看起来会失效

  一级缓存是基于sqlsession的概念来的，对于同一个sqlsession，同一个select语句串行执行多次，除了第一次，其他的都会用到缓存，而不是执行sql查询。

  这里是因为不引入事务的话，默认的是每次都会都会启动一个新的sqlsession，这样就跟我们看起来不太一样。

  如果引入了事务，就会把当前线程的sqlsession放到threadlocal中，以便于下次取用

- mabatis使用了 SqlSessionTemplate 而不是SqlSession

  前者是对后者的封装，其中包括了在每种场景下定义











