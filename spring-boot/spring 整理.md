## spring boot 流程梳理

todo 整理aop逻辑

### 1.入口

一般而言，spring boot的入口即一个main函数，如下：

```java
@SpringBootApplication
public class DemoBootApplication {

   public static void main(String[] args) {
		new SpringApplication(DemoBootApplication.class).run(args);
   }

}
```

总体而言，作为一个普通的spring web工程，这里做的事情有：

- 从spring.factory中读取初始化工具类、监听器、bootstrap初始化工具类（默认没有）

- 配置primarySources（初始化SpringApplication传进来的类）以及mainApplicationClass（执行启动命令的类）

  

- 初始化环境

- 初始化applicationcontext

- 刷新容器

- 启动webserver

  

- 做一些收尾工作

ok，下面就以这些为基础，进行梳理，以下步骤讲的是servlet类型的web应用。

### 2. 步骤梳理

#### 2.1 初始化准备

这里是new SpringApplication(DemoBootApplication.class)这步做的事情，更具体代码如下：

```java
/**
 * Create a new {@link SpringApplication} instance. The application context will load
 * beans from the specified primary sources (see {@link SpringApplication class-level}
 * documentation for details). The instance can be customized before calling
 * {@link #run(String...)}.
 * @param resourceLoader the resource loader to use
 * @param primarySources the primary bean sources
 * @see #run(Class, String[])
 * @see #setSources(Set)
 */
@SuppressWarnings({ "unchecked", "rawtypes" })
public SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources) {
   this.resourceLoader = resourceLoader;
   Assert.notNull(primarySources, "PrimarySources must not be null");
   this.primarySources = new LinkedHashSet<>(Arrays.asList(primarySources));
   this.webApplicationType = WebApplicationType.deduceFromClasspath();
   this.bootstrapRegistryInitializers = new ArrayList<>(
         getSpringFactoriesInstances(BootstrapRegistryInitializer.class));
   setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));
   setListeners((Collection) getSpringFactoriesInstances(ApplicationListener.class));
   this.mainApplicationClass = deduceMainApplicationClass();
}
```

1. 设置`resourceLoader`，传入的为null

2. 设置`primarySources`，这里指的就是初始化`SpringApplication`传入的那个类，之后，spring会以这个类为起点，扫描并初始化项目下面的bean

3. 推断web服务器类型，就是简单粗暴的根据是否有对应的类来推断的，具体类型有`REACTIVE`、`SERVLET`、`NONE`

4. 从spring.factory中取一些初始化工具类

   1. `BootstrapRegistryInitializer`

      `bootstrap`是一个生命周期很短的容器

   2. `ApplicationContextInitializer`

      TODO 作用

   3. `ApplicationListener`

      TODO 是spring初始化过程中的事件处理器，即到达某个阶段之后，就会链式调用其中的事件处理器

5. 设置`mainApplicationClass`，这里就是执行main方法的类

> **TIP**： 这个方法的注释也提示了我们，可以在调用run方法之前，进一步配置`SpringApplication`。
>
> TODO 例子

#### 2.2 执行run方法，启动spring

这里是整个spring boot启动的核心，做完了前面的配置工作之后，就要准备环境、初始化容器、启动web服务了，方法如下：

```java
/**
 * Run the Spring application, creating and refreshing a new
 * {@link ApplicationContext}.
 * @param args the application arguments (usually passed from a Java main method)
 * @return a running {@link ApplicationContext}
 */
public ConfigurableApplicationContext run(String... args) {
   long startTime = System.nanoTime();
   // 创建 BootstrapContext上下文，用作applicationcontext初始化
   DefaultBootstrapContext bootstrapContext = createBootstrapContext();
   // 先声明
   ConfigurableApplicationContext context = null;
   configureHeadlessProperty();
   // 从spring.factory中获取SpringApplicationRunListener，之后在每个阶段会执行，用于发布事件
   SpringApplicationRunListeners listeners = getRunListeners(args);
   // 发布ApplicationStartingEvent
   listeners.starting(bootstrapContext, this.mainApplicationClass);
   try {
      // 获取启动的时候传入的参数
      ApplicationArguments applicationArguments = new DefaultApplicationArguments(args);
      // 初始化环境信息，即启动的时候通过各种途径传入的参数，以key-value的方式存放
      ConfigurableEnvironment environment = prepareEnvironment(listeners, bootstrapContext, applicationArguments);
      configureIgnoreBeanInfo(environment);
      Banner printedBanner = printBanner(environment);
      // 构建applicationcontext 对于servlet webserver 构建的是 AnnotationConfigServletWebServerApplicationContext
      context = createApplicationContext();
      context.setApplicationStartup(this.applicationStartup);
      // 准备上下文
      prepareContext(bootstrapContext, context, environment, listeners, applicationArguments, printedBanner);
      // 刷新上下文，之后如果是web应用，启动webserver
      refreshContext(context);
      // 刷新之后的方法，目前为空，是一个扩展点
      afterRefresh(context, applicationArguments);
      Duration timeTakenToStartup = Duration.ofNanos(System.nanoTime() - startTime);
      if (this.logStartupInfo) {
         new StartupInfoLogger(this.mainApplicationClass).logStarted(getApplicationLog(), timeTakenToStartup);
      }
      // 调用监听器的started方法
      listeners.started(context, timeTakenToStartup);
      // 所有bean加载完成，调用声明的runner的run方法
      callRunners(context, applicationArguments);
   }
   catch (Throwable ex) {
      handleRunFailure(context, ex, listeners);
      throw new IllegalStateException(ex);
   }
   try {
      Duration timeTakenToReady = Duration.ofNanos(System.nanoTime() - startTime);
      // 调用监听器的ready方法
      listeners.ready(context, timeTakenToReady);
   }
   catch (Throwable ex) {
      handleRunFailure(context, ex, null);
      throw new IllegalStateException(ex);
   }
   return context;
}
```

这里算是把一个一般的spring web服务启动过程都摆上来了，其中的任意一段，基本都可以展开出很多东西。下面按照顺序展开讲下其中几个步骤：

##### 2.2.1 发布ApplicationStartingEvent

TODO

##### 2.2.2 初始化环境信息

首先是创建环境

![image-20220916112930388](E:\Document\work\笔记\初始化之后的env.png)

这里看到是找到了这几个运行环境中的属性：环境变量 系统属性。



之后把spring启动的时候配置的参数添加到propertySources中，并配置profiles

之后会配置这么一个属性spring.beaninfo.ignore



发布ApplicationEnvironmentPreparedEvent事件，spring cloud context包中注册了该事件的监听器，初始化spring cloud的容器，同时也会有一个ConfigFileApplicationListener监听该事件，监听到事件之后，即按照优先级加载spring boot的配置文件。

这里初始化spring cloud容器的时候，会做一步动作，即把spring cloud这个容器中的所有ApplicationContextInitializer给添加到spring boot的容器中，PropertySourceBootstrapConfiguration就是其中之一，它在后面准备上下文的时候，会被调用其中的initialize方法，作用就是在初始化之前加载额外的配置，包括从云端获取的配置。这里这么麻烦的操作，应该是因为这些初始化工具都是有状态的吧，它们会依赖spring容器中的一些bean的特性。



之后根据当前的context类型决定初始化哪种类型就applicationcontext

- default:AnnotationConfigApplicationContext
- servlet:AnnotationConfigServletWebServerApplicationContext
- relative:AnnotationConfigReactiveWebServerApplicationContext



##### 2.2.3 准备上下文

> 对于2.4之前的版本，是没有bootstrapContext的

这里是用上面准备好的`environment`、`listener`初始化上下文

```java
private void prepareContext(DefaultBootstrapContext bootstrapContext, ConfigurableApplicationContext context,
      ConfigurableEnvironment environment, SpringApplicationRunListeners listeners,
      ApplicationArguments applicationArguments, Banner printedBanner) {
    
   context.setEnvironment(environment);
   postProcessApplicationContext(context);
   applyInitializers(context);
   listeners.contextPrepared(context);
   bootstrapContext.close(context);
   if (this.logStartupInfo) {
      logStartupInfo(context.getParent() == null);
      logStartupProfileInfo(context);
   }
   // Add boot specific singleton beans
   ConfigurableListableBeanFactory beanFactory = context.getBeanFactory();
   beanFactory.registerSingleton("springApplicationArguments", applicationArguments);
   if (printedBanner != null) {
      beanFactory.registerSingleton("springBootBanner", printedBanner);
   }
   if (beanFactory instanceof AbstractAutowireCapableBeanFactory) {
      ((AbstractAutowireCapableBeanFactory) beanFactory).setAllowCircularReferences(this.allowCircularReferences);
      if (beanFactory instanceof DefaultListableBeanFactory) {
         ((DefaultListableBeanFactory) beanFactory)
               .setAllowBeanDefinitionOverriding(this.allowBeanDefinitionOverriding);
      }
   }
   if (this.lazyInitialization) {
      context.addBeanFactoryPostProcessor(new LazyInitializationBeanFactoryPostProcessor());
   }
   context.addBeanFactoryPostProcessor(new PropertySourceOrderingBeanFactoryPostProcessor(context));
   // Load the sources
   Set<Object> sources = getAllSources();
   Assert.notEmpty(sources, "Sources must not be empty");
   load(context, sources.toArray(new Object[0]));
   listeners.contextLoaded(context);
}
```

这里其中好好一个作用即调用Initialize方法，其中一个初始化组件为PropertySourceBootstrapConfiguration，功能是加载其他配置，nacos就用了其中一点，具体分析见spring cloud组件分析。这里也可以是自己的在容器初始化之前加载配置的一些扩展点。

下面是PropertySourceLocator这个接口的注释，想要实现加载自定义配置即可以实现这个接口。

Strategy for locating (possibly remote) property sources for the Environment. Implementations should not fail unless they intend to prevent the application from starting.

##### 2.2.4 刷新上下文

对于servlet的web程序，刷新步骤如下：

```java
@Override
public void refresh() throws BeansException, IllegalStateException {
   synchronized (this.startupShutdownMonitor) {
      StartupStep contextRefresh = this.applicationStartup.start("spring.context.refresh");

      // Prepare this context for refreshing.
      prepareRefresh();

      // Tell the subclass to refresh the internal bean factory.
      ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

      // Prepare the bean factory for use in this context.
      prepareBeanFactory(beanFactory);

      try {
         // Allows post-processing of the bean factory in context subclasses.
         postProcessBeanFactory(beanFactory);

         StartupStep beanPostProcess = this.applicationStartup.start("spring.context.beans.post-process");
         // Invoke factory processors registered as beans in the context.
         invokeBeanFactoryPostProcessors(beanFactory);

         // Register bean processors that intercept bean creation.
         registerBeanPostProcessors(beanFactory);
         beanPostProcess.end();

         // Initialize message source for this context.
         initMessageSource();

         // Initialize event multicaster for this context.
         initApplicationEventMulticaster();

         // Initialize other special beans in specific context subclasses.
         // 这里创建webserver
         onRefresh();

         // Check for listener beans and register them.
         registerListeners();

         // Instantiate all remaining (non-lazy-init) singletons.
         // 初始化所有的非懒加载单例bean
         finishBeanFactoryInitialization(beanFactory);

         // Last step: publish corresponding event.
         finishRefresh();
      }

      catch (BeansException ex) {
         if (logger.isWarnEnabled()) {
            logger.warn("Exception encountered during context initialization - " +
                  "cancelling refresh attempt: " + ex);
         }

         // Destroy already created singletons to avoid dangling resources.
         destroyBeans();

         // Reset 'active' flag.
         cancelRefresh(ex);

         // Propagate exception to caller.
         throw ex;
      }

      finally {
         // Reset common introspection caches in Spring's core, since we
         // might not ever need metadata for singleton beans anymore...
         resetCommonCaches();
         contextRefresh.end();
      }
   }
}
```

###### 2.2.4.1 构建applicationcontext

```java
this.reader = new AnnotatedBeanDefinitionReader(this);
this.scanner = new ClassPathBeanDefinitionScanner(this);
```

这里构造了一个`reader`，一个`scanner`，前者用于注册bean，后者用于扫描bean，它们是整个生命周期扫描注册bean的重要工具。

###### 2.2.4.2 获取并准备beanfactory

把`beanfactory`的状态标记为`refreshed`，这里只允许标记一次，如果发现标记失败，即报错。

之后注册一些bean，并将一些接口配置为不可注入。

```java
// Tell the internal bean factory to use the context's class loader etc.
beanFactory.setBeanClassLoader(getClassLoader());
if (!shouldIgnoreSpel) {
   beanFactory.setBeanExpressionResolver(new StandardBeanExpressionResolver(beanFactory.getBeanClassLoader()));
}
beanFactory.addPropertyEditorRegistrar(new ResourceEditorRegistrar(this, getEnvironment()));

// Configure the bean factory with context callbacks.
// 注册ApplicationContextAwareProcessor
beanFactory.addBeanPostProcessor(new ApplicationContextAwareProcessor(this));
// 阻止这些bean的依赖注入TODO 
beanFactory.ignoreDependencyInterface(EnvironmentAware.class);
beanFactory.ignoreDependencyInterface(EmbeddedValueResolverAware.class);
beanFactory.ignoreDependencyInterface(ResourceLoaderAware.class);
beanFactory.ignoreDependencyInterface(ApplicationEventPublisherAware.class);
beanFactory.ignoreDependencyInterface(MessageSourceAware.class);
beanFactory.ignoreDependencyInterface(ApplicationContextAware.class);
beanFactory.ignoreDependencyInterface(ApplicationStartupAware.class);

// BeanFactory interface not registered as resolvable type in a plain factory.
// MessageSource registered (and found for autowiring) as a bean.
// 提前注册bean，之后做依赖注入的时候会用到
beanFactory.registerResolvableDependency(BeanFactory.class, beanFactory);
beanFactory.registerResolvableDependency(ResourceLoader.class, this);
beanFactory.registerResolvableDependency(ApplicationEventPublisher.class, this);
beanFactory.registerResolvableDependency(ApplicationContext.class, this);

// Register early post-processor for detecting inner beans as ApplicationListeners.
// 注册用于发现ApplicationListeners的beanpostprocessor
beanFactory.addBeanPostProcessor(new ApplicationListenerDetector(this));

// Detect a LoadTimeWeaver and prepare for weaving, if found.
if (!NativeDetector.inNativeImage() && beanFactory.containsBean(LOAD_TIME_WEAVER_BEAN_NAME)) {
   beanFactory.addBeanPostProcessor(new LoadTimeWeaverAwareProcessor(beanFactory));
   // Set a temporary ClassLoader for type matching.
   beanFactory.setTempClassLoader(new ContextTypeMatchClassLoader(beanFactory.getBeanClassLoader()));
}

// Register default environment beans.
if (!beanFactory.containsLocalBean(ENVIRONMENT_BEAN_NAME)) {
   beanFactory.registerSingleton(ENVIRONMENT_BEAN_NAME, getEnvironment());
}
if (!beanFactory.containsLocalBean(SYSTEM_PROPERTIES_BEAN_NAME)) {
   beanFactory.registerSingleton(SYSTEM_PROPERTIES_BEAN_NAME, getEnvironment().getSystemProperties());
}
if (!beanFactory.containsLocalBean(SYSTEM_ENVIRONMENT_BEAN_NAME)) {
   beanFactory.registerSingleton(SYSTEM_ENVIRONMENT_BEAN_NAME, getEnvironment().getSystemEnvironment());
}
if (!beanFactory.containsLocalBean(APPLICATION_STARTUP_BEAN_NAME)) {
   beanFactory.registerSingleton(APPLICATION_STARTUP_BEAN_NAME, getApplicationStartup());
}
```

这里涉及一个概念：BeanPostProcessor，是bean生命周期中重要的处理器，可以在赋值前后、初始化前后插入处理逻辑。这里是添加到bean工厂的beanPostProcessors中，它是一个list，之后在bean对应的生命周期的时候，会从中获取BeanPostProcessor，并执行其逻辑。

之后添加WebApplicationContextServletContextAwareProcessor，并注册web应用的scope（TODO registerWebApplicationScopes）。

###### 2.2.4.3 扫描并注册beandefinition

<img src="E:\Document\work\笔记\image-20220802202437270.png" alt="image-20220802202437270" style="zoom:200%;" />

核心就是调用invokeBeanFactoryPostProcessors方法。首先执行的是`ConfigurationClassPostProcessor`类，它是用来解析项目包下面的配置类，从`primarySources`开始，按照上图的方式做扫描。

执行完系统定义的`BeanDefinitionRegistryPostProcessor`之后，就会执行扫描得到的实现类，一些三方启动类就是使用这种机制，实现自定义注册bean的功能，例如mybatis，扫描对应mapper包下面的接口，并使用代理生成对应的bean，注册到bean工厂中。

###### 2.2.4.4 扫描beanpostprocessor

基于上一步的扫描结果，注册beanpostprocessor

###### 2.2.4.5 初始化所有的非懒加载单例bean

这里即遍历所有的bean，如果是满足提前初始化条件，即调用getBean方法。

中间就涉及bean的

- 类加载

- 实例化

- 依赖注入

- 初始化

其中依赖注入可能会面临循环依赖的问题，之前版本的spring采用的是三级缓存的机制，但是目前用的spring版本是默认禁止了循环依赖，一旦检测到，直接报错。

###### 2.2.4.6 bean生命周期中的扩展点

TODO 扩展点

这里罗列出来之后用到的生命周期扩展点及其作用

- SmartInitializingSingleton

  是一个函数式接口，`afterSingletonsInstantiated`是接口中唯一的方法，这里是在应用上下文刷新过程中，所有的非懒加载的单例bean已经创建完成，之后依次扫描每个bean，如果实现了这个接口，即调用`afterSingletonsInstantiated`方法。

  应用：

  - RestTemplate的负载均衡初始化

    首先在配置类中注入所有使用`LoadBalancer`注解标注的`RestTemplate`bean，之后声明一个实现了该接口的bean，对这些`RestTemplate`进行进一步封装，其中一步就是添加一个实现负载均衡的拦截器，从服务注册中心获取服务列表，按照一定策略选择其中之一进行请求。

##### 2.2.5 调用监听器的started方法

##### 2.2.6 callRunners

TODO 具体的应用

##### 2.2.7 调用监听器的ready方法



