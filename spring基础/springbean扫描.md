# spring bean 扫描过程

核心方法

```java
// Invoke factory processors registered as beans in the context.
invokeBeanFactoryPostProcessors(beanFactory);

// Register bean processors that intercept bean creation.
// 初始化系统和用户定义的beanpostprossor
registerBeanPostProcessors(beanFactory);
```

核心代码

```java
beanFactory.setDependencyComparator(AnnotationAwareOrderComparator.INSTANCE);
// 这里只是把一些处理器的定义放到beanfactory中
// 这个是实现了BeanDefinitionRegistryPostProcessor接口
RootBeanDefinition def = new RootBeanDefinition(ConfigurationClassPostProcessor.class);
RootBeanDefinition def = new RootBeanDefinition(AutowiredAnnotationBeanPostProcessor.class);
RootBeanDefinition def = new RootBeanDefinition(CommonAnnotationBeanPostProcessor.class);

beanFactory.addBeanPostProcessor(new ApplicationContextAwareProcessor(this));
beanFactory.addBeanPostProcessor(new ApplicationListenerDetector(this));
```

- invokeBeanFactoryPostProcessors

  > 这里即扫描注册beandefinition
  >
  > 后置处理beanfactory

  此时已经有一部分beandefinition。

  这里就是对初步准备好的beanfactory做进一步的加工。

  BeanDefinitionRegistryPostProcessor BeanFactoryPostProcessor 这两个接口

  先执行 postProcessBeanDefinitionRegistry 方法，之后执行 postProcessBeanFactory 方法

  这里注释有这么一句话：

  ```
  Do not initialize FactoryBeans here: We need to leave all regular beans uninitialized to let the bean factory post-processors apply to them! Separate between BeanDefinitionRegistryPostProcessors that implement PriorityOrdered, Ordered, and the rest.
  ```

  1. First, invoke the BeanDefinitionRegistryPostProcessors that implement PriorityOrdered.
  2. Next, invoke the BeanDefinitionRegistryPostProcessors that implement Ordered.
  3. Finally, invoke all other BeanDefinitionRegistryPostProcessors until no further ones appear.

  首先执行beandefinition注册的方法，之后执行FactoryPostProcessors的后置处理方法

  执行完以上三步，不会再有新的beandefinition产生了

- registerBeanPostProcessors

  > 收集目前所有的beanpostprocessor，之后做排序

  同样，这里也是按照 PriorityOrdered Ordered 其他 三种类型对所有的beanpostprocessor进行分类、排序

  这里实现了MergedBeanDefinitionPostProcessor接口的beanpostprocessor放在最后执行了



扫描

加了configuration注解且proxymethod属性为true

为完全配置类

加了以下四个注解

```java
candidateIndicators.add(Component.class.getName());
candidateIndicators.add(ComponentScan.class.getName());
candidateIndicators.add(Import.class.getName());
candidateIndicators.add(ImportResource.class.getName());
```

或者类中的方法加了Bean注解

或者proxymethod属性为false

为轻配置类

之后就会加载这些配置类





