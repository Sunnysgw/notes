# spring bean循环依赖

> spring在获取bean的时候大量用到了缓存这种机制，防止多次重复加载浪费时间。
>
> 同时，这里也使用缓存的机制解决了循环依赖的问题。

## 1. 基于三级缓存来解决循环依赖的问题：

- singletonFactories  三级

  实例化bean之后，向该map中存放创建该对象的bean工厂，是一个函数式接口，getObject方法中根据是否要做aop来返回对应的对象

- earlySingletonObjects  二级

  半成品，没有经过完成的生命周期的bean，放置要做代理的对象或者直接初始化之后的对象

- singletonObjects 一级

  完整bean生命周期的对象

1. bean实例化之后，如果当前bean工厂支持循环依赖，就会向三级缓存中添加缓存，key是beanname，value是一个函数式接口

   ```java
   // Eagerly cache singletons to be able to resolve circular references
   // even when triggered by lifecycle interfaces like BeanFactoryAware.
   boolean earlySingletonExposure = (mbd.isSingleton() && this.allowCircularReferences &&
         isSingletonCurrentlyInCreation(beanName));
   if (earlySingletonExposure) {
      if (logger.isTraceEnabled()) {
         logger.trace("Eagerly caching bean '" + beanName +
               "' to allow for resolving potential circular references");
      }
      addSingletonFactory(beanName, () -> getEarlyBeanReference(beanName, mbd, bean));
   }
   ```

2. 之后出现循环依赖的场景，就用到了前面的缓存

   ```java
   	/**
   	 * Return the (raw) singleton object registered under the given name.
   	 * <p>Checks already instantiated singletons and also allows for an early
   	 * reference to a curren  tly created singleton (resolving a circular reference).
   	 * @param beanName the name of the bean to look for
   	 * @param allowEarlyReference whether early references should be created or not
   	 * @return the registered singleton object, or {@code null} if none found
   	 */
   	@Nullable
   	protected Object getSingleton(String beanName, boolean allowEarlyReference) {
   		// Quick check for existing instance without full singleton lock
   		Object singletonObject = this.singletonObjects.get(beanName);
   		if (singletonObject == null && isSingletonCurrentlyInCreation(beanName)) {
               // 出现了循环依赖
               // 从二级缓存中取
   			singletonObject = this.earlySingletonObjects.get(beanName);
   			if (singletonObject == null && allowEarlyReference) {
   				synchronized (this.singletonObjects) {
   					// Consistent creation of early reference within full singleton lock
   					singletonObject = this.singletonObjects.get(beanName);
   					if (singletonObject == null) {
   						singletonObject = this.earlySingletonObjects.get(beanName);
   						if (singletonObject == null) {
                               // 三级缓存中取工厂方法，之后创建对象
   							ObjectFactory<?> singletonFactory = this.singletonFactories.get(beanName);
   							if (singletonFactory != null) {
                                   // 执行getObject，之后放到二级缓存中
   								singletonObject = singletonFactory.getObject();
   								this.earlySingletonObjects.put(beanName, singletonObject);
   								this.singletonFactories.remove(beanName);
   							}
   						}
   					}
   				}
   			}
   		}
   		return singletonObject;
   	}
   ```

3. 在单例对象初始化完成之后，spring会尝试调用getSingleton方法获取单例对象，代码如下：

   ```java
   if (earlySingletonExposure) {
      Object earlySingletonReference = getSingleton(beanName, false);
      if (earlySingletonReference != null) {
         if (exposedObject == bean) {
            exposedObject = earlySingletonReference;
         }
         else if (!this.allowRawInjectionDespiteWrapping && hasDependentBean(beanName)) {
            String[] dependentBeans = getDependentBeans(beanName);
            Set<String> actualDependentBeans = new LinkedHashSet<>(dependentBeans.length);
            for (String dependentBean : dependentBeans) {
               if (!removeSingletonIfCreatedForTypeCheckOnly(dependentBean)) {
                  actualDependentBeans.add(dependentBean);
               }
            }
            if (!actualDependentBeans.isEmpty()) {
               throw new BeanCurrentlyInCreationException(beanName,
                     "Bean with name '" + beanName + "' has been injected into other beans [" +
                     StringUtils.collectionToCommaDelimitedString(actualDependentBeans) +
                     "] in its raw version as part of a circular reference, but has eventually been " +
                     "wrapped. This means that said other beans do not use the final version of the " +
                     "bean. This is often the result of over-eager type matching - consider using " +
                     "'getBeanNamesForType' with the 'allowEagerInit' flag turned off, for example.");
            }
         }
      }
   }
   
   
   
   
   ```

   如果支持循环依赖，并且已经使用过了三级缓存，即**出现了循环依赖的场景**，那么这里getSingleton是可以取到值的，这里取到的是**aop之后的值**，之后会比较在经过aop之后，bean对象是否有做过改动，即aop生成的代理中的target和目前的target是否一致，即是否有漏掉其他的步骤，如果不一致，说明在aop后面对bean还有其他的处理，就不能把二级代理中取到的bean放到单利池中这里就会报错，防止运行不正常。

## 2. 场景分析

这里很多场景都可以使用Lazy注解解决，就是打破循环依赖的条件

1. 原型bean的循环依赖的问题

   原型bean中不能解决循环依赖的

2. 基于构造方法的循环依赖场景

   是不能解决的，因为构造方法执行的过程中，三级缓存还没有值，故不能解决

3. 加上Transaction注解的时候是否会报错

   这里不会报错的，因为事务不是基于BeanPostProcessor实现的

4. 自己注入自己

   自己注入自己，也是用到了三级缓存