# spring bean依赖注入

## 1.依赖注入的步骤

> 结合调用方法，从大到小讲述中间涉及到代码以及bean创建过程中的注入点。
>
> 这里涉及的逻辑是在AbstractAutowireCapableBeanFactory的doCreateBean方法中实现的，是bean创建生命周期中的重要的一环。

### 1.1 Autowired注解

1. 注入点标记

   实例化bean对象之后，即在applyMergedBeanDefinitionPostProcessors方法中调用MergedBeanDefinitionPostProcessor实现类中的postProcessMergedBeanDefinition方法：

   ```
   // Allow post-processors to modify the merged bean definition.
   synchronized (mbd.postProcessingLock) {
      if (!mbd.postProcessed) {
         try {
            applyMergedBeanDefinitionPostProcessors(mbd, beanType, beanName);
         }
         catch (Throwable ex) {
            throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                  "Post-processing of merged bean definition failed", ex);
         }
         mbd.postProcessed = true;
      }
   }
   ```

   这个注入点对spring合并好的beandefinition做一些定制化的处理，其中就包括寻找bean中的注入点，resource、value、autowired这些注解的预处理都是在这个注入点实现的。

   具体的实现类包括CommonAnnotationBeanPostProcessor（处理resource注解）和AutowiredAnnotationBeanPostProcessor（处理autowired、value注解）。

   具体寻找注入点的过程即通过反射遍历bean的field和method，检查是否有目标注解，扫描的结果放到cache中，供之后做注入，其中对字段的过滤中，不会记录**静态字段**，因为对于原型bean，如果静态字段也可以做注入，就会出现不合理的结果，对方法的过滤中，有涉及**桥接方法**的处理，对于实现的接口中的方法，编译的字节码中会出现两个同名方法，其中一个会被标记为桥接方法，spring不会扫描这些方法上的注解，同时spring同样不会关心**静态方法**上的注解。

2. 标记完注入点之后，要做的就是基于注解找到要注入的内容了

   这是在populateBean(beanName, mbd, instanceWrapper)方法中实现的，这个方法中做的就是各种依赖注入，包括前面讲的在bean注解或者xml标签中标记的autowired属性这种废弃的方式，以及基于注解的更灵活的方式。注入点是InstantiationAwareBeanPostProcessor中的postProcessProperties方法，上一步中讲的两个BeanPostProcessor类均实现了这个接口，所以前后两个注入点是在同一个bean中做的。

   对于autowired以及value注解的处理中，开始同样是调用在上一步中调用过的findResourceMetadata方法，不同的是，这一步直接使用上一步缓存好的值，取到值之后，即调用InjectionMetadata的inject方法，做真正的注入，这里AutowiredAnnotationBeanPostProcessor针对field和method两种情况分别实现了注入点内部类AutowiredFieldElement以及AutowiredMethodElement，它们都继承了InjectionMetadata.InjectedElement。

    

   下面是找注入值的大体步骤

   1. 基于type找到所有的候选bean，之后对每个候选bean做2 3 4的过滤
   2. 检查是否autowireCandidate的属性为false，如果是的话，丢弃之
   3. 基于范型做匹配
   4. 基于Qualifier注解做匹配
   5. 如果没有候选bean，如果required为true即报错；如果只有一个了，直接返回；如果有多个就按照6 7 8做过滤
   6. 如果有候选bean使用Primary注解修饰，直接返回
   7. 基于Priority注解排序
   8. 基于参数name确定

   到这一步，如果找到的依旧是多个候选bean，直接报错，如果没有候选bean，看下注入点的require参数，如果不是false，同样报错。

### 1.2 Resource注解

1. 注入点标记

   初始化注入点的时候

   - 规范化名称
   - 记录name
   - 解析lazy注解

2. 找bean

   如果使用lazy注解修饰，则返回一个代理，真正使用的时候才去找bean。

   首先根据name去找，如果name没有找到，就基于类型去找，代码如下：

   ```java
   AutowireCapableBeanFactory beanFactory = (AutowireCapableBeanFactory) factory;
   DependencyDescriptor descriptor = element.getDependencyDescriptor();
   // 如果 次优先用类型比较 并且没有指定注入的bean的name 并且bean工厂中没有默认名称的bean
   // 则根据类型去找
   if (this.fallbackToDefaultTypeMatch && element.isDefaultName && !factory.containsBean(name)) {
      autowiredBeanNames = new LinkedHashSet<>();
      resource = beanFactory.resolveDependency(descriptor, requestingBeanName, autowiredBeanNames, null);
      if (resource == null) {
         throw new NoSuchBeanDefinitionException(element.getLookupType(), "No resolvable resource object");
      }
   }
   else {
       // 除开前面的条件 就基于名称去找
      resource = beanFactory.resolveBeanByName(name, descriptor);
      autowiredBeanNames = Collections.singleton(name);
   }
   ```

## 2.中间用到的设计模式

在过滤候选bean的时候使用到了AutowireCandidateResolver接口的isAutowireCandidate方法，这个方法一共有三种实现，对于每个子类的实现方法中，都会有如下代码：

```
if (!super.isAutowireCandidate(bdHolder, descriptor)) {
   // If explicitly false, do not proceed with any other checks...
   return false;
}
```

即，首先调用父类的判断逻辑，如果父类通过，再调用自己的判断逻辑。

这里是**责任链模式**







