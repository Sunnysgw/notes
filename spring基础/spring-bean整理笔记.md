# Spring Bean生命周期

> 本文基于图灵课堂周瑜老师的讲解整理，包括spring bean加载的过程，主要是扫描BeanDefinition以及初始化非懒加载单例Bean两部分，源码取自SpringFramework 5.3.22

## 1. Bean扫描

本小节介绍的是Spring从给定的扫描位置扫描到待加载的Bean，生成BeanDefinitionMap的过程

SpringBoot启动过程中使用的ApplicationContext是`AnnotationConfigApplicationContext`，而它初始化的时候会顺带初始化两个`BeanDefinitionReader`：`AnnotatedBeanDefinitionReader`和`ClassPathBeanDefinitionScanner`，前者是可以直接通过给定的class注册Bean，后者则可以扫描给定目录下所有的目标Bean，下面着重介绍后者扫描Bean组件的过程。

`ClassPathBeanDefinitionScanner`扫描的入口是public int scan(String... basePackages)，而真正做事情的是protected Set<BeanDefinitionHolder> doScan(String... basePackages)方法，代码如下:

```java
/**
	 * Perform a scan within the specified base packages,
	 * returning the registered bean definitions.
	 * <p>This method does <i>not</i> register an annotation config processor
	 * but rather leaves this up to the caller.
	 * @param basePackages the packages to check for annotated classes
	 * @return set of beans registered if any for tooling registration purposes (never {@code null})
	 */
protected Set<BeanDefinitionHolder> doScan(String... basePackages) {
		Assert.notEmpty(basePackages, "At least one base package must be specified");
		Set<BeanDefinitionHolder> beanDefinitions = new LinkedHashSet<>();
		for (String basePackage : basePackages) {
            // 找到basePackage下的所有候选组件，这里只是把classname赋值给了BeanDefinition
			Set<BeanDefinition> candidates = findCandidateComponents(basePackage);
			for (BeanDefinition candidate : candidates) {
                // 获取组件的scope，默认是单例的
				ScopeMetadata scopeMetadata = this.scopeMetadataResolver.resolveScopeMetadata(candidate);
				candidate.setScope(scopeMetadata.getScopeName());
                // 获取beanname
				String beanName = this.beanNameGenerator.generateBeanName(candidate, this.registry);
				if (candidate instanceof AbstractBeanDefinition) {
					postProcessBeanDefinition((AbstractBeanDefinition) candidate, beanName);
				}
                // 处理通用的注解
				if (candidate instanceof AnnotatedBeanDefinition) {
					AnnotationConfigUtils.processCommonDefinitionAnnotations((AnnotatedBeanDefinition) candidate);
				}
                // 最后再对BeanDefinition做检查，看下是否有重名的
				if (checkCandidate(beanName, candidate)) {
					BeanDefinitionHolder definitionHolder = new BeanDefinitionHolder(candidate, beanName);
					definitionHolder =
							AnnotationConfigUtils.applyScopedProxyMode(scopeMetadata, definitionHolder, this.registry);
					beanDefinitions.add(definitionHolder);
					registerBeanDefinition(definitionHolder, this.registry);
				}
			}
		}
		return beanDefinitions;
	}
```

------

下面将以上部分代码展开去讲

### 1.1 扫描包下面的所有组件

即对应`findCandidateComponents`方法的操作，该方法如下：

```java
	/**
	 * Scan the class path for candidate components.
	 * @param basePackage the package to check for annotated classes
	 * @return a corresponding Set of autodetected bean definitions
	 */
	public Set<BeanDefinition> findCandidateComponents(String basePackage) {
		if (this.componentsIndex != null && indexSupportsIncludeFilters()) {
			return addCandidateComponentsFromIndex(this.componentsIndex, basePackage);
		}
		else {
			return scanCandidateComponents(basePackage);
		}
	}
```

- 首先来判断是否有对应的索引，即看`componentsIndex`是否有值，它加载的是` META-INF/spring.components`中的信息，内容格式如下：

  ```properties
  com.sgw.demo=org.springframework.stereotype.Component
  ```

  之后，就加载这里的Bean组件，不去做扫描，对于项目过于庞大，扫描耗费时间的情况，可以考虑这种方案，个人感觉对于现在的微服务架构，这种应该没太多实际场景

- 如果没有索引，即进入真正的扫描流程`scanCandidateComponents`，代码如下：

  ```java
  private Set<BeanDefinition> scanCandidateComponents(String basePackage) {
  	Set<BeanDefinition> candidates = new LinkedHashSet<>();
  	try {
          // 根据传入的包名，得到对应的classpath中的路径
  		String packageSearchPath = ResourcePatternResolver.CLASSPATH_ALL_URL_PREFIX +
  				resolveBasePackage(basePackage) + '/' + this.resourcePattern;
          // 获取该路径下的所有class文件
  		Resource[] resources = getResourcePatternResolver().getResources(packageSearchPath);
  		boolean traceEnabled = logger.isTraceEnabled();
  		boolean debugEnabled = logger.isDebugEnabled();
  		for (Resource resource : resources) {
  			if (traceEnabled) {
  				logger.trace("Scanning " + resource);
  			}
  			try {
                  // 使用ASM读取class文件
  				MetadataReader metadataReader = getMetadataReaderFactory().getMetadataReader(resource);
                  // 判断是否是要扫描的组件
  				if (isCandidateComponent(metadataReader)) {
  					ScannedGenericBeanDefinition sbd = new ScannedGenericBeanDefinition(metadataReader);
                      // 设置resource文件
  					sbd.setSource(resource);
                      // 判断扫描到的组件是否是正常的类（是不是独立的，检查是不是接口、抽象类（带LookUp注解的除外））
  					if (isCandidateComponent(sbd)) {
  						if (debugEnabled) {
  							logger.debug("Identified candidate component class: " + resource);
  						}
  						candidates.add(sbd);
  					}
  					else {
  						if (debugEnabled) {
  							logger.debug("Ignored because not a concrete top-level class: " + resource);
  						}
  					}
  				}
  				else {
  					if (traceEnabled) {
  						logger.trace("Ignored because not matching any filter: " + resource);
  					}
  				}
  			}
  			catch (FileNotFoundException ex) {
  				if (traceEnabled) {
  					logger.trace("Ignored non-readable " + resource + ": " + ex.getMessage());
  				}
  			}
  			catch (Throwable ex) {
  				throw new BeanDefinitionStoreException(
  						"Failed to read candidate component class: " + resource, ex);
  			}
  		}
  	}
  	catch (IOException ex) {
  		throw new BeanDefinitionStoreException("I/O failure during classpath scanning", ex);
  	}
  	return candidates;
  }
  ```

  1. 根据传入的包名，得到对应的classpath中的路径

     前面加上`classpath*:`前缀，后面加上`**/*.class`，同时把包名中的.替换成/

  2. 基于第一步拼接的搜索路径，得到下面所有的class文件，并以`Resource`数组的形式返回

  3. 遍历得到的Resource数组，使用ASM读取class文件

     有个问题是为什么这里已经取得了类名，不直接用jdk的classloader加载进去呢，原因是效率问题，把扫描到的类都加载上去第一没必要，第二浪费时间

  4. 判断是否是要扫描的组件

     这里是基于exclude以及include两类filter以及conditional注解来做的，看下具体代码实现

     ```java
     	/**
     	 * Determine whether the given class does not match any exclude filter
     	 * and does match at least one include filter.
     	 * @param metadataReader the ASM ClassReader for the class
     	 * @return whether the class qualifies as a candidate component
     	 */
     	protected boolean isCandidateComponent(MetadataReader metadataReader) throws IOException {
     		for (TypeFilter tf : this.excludeFilters) {
     			if (tf.match(metadataReader, getMetadataReaderFactory())) {
     				return false;
     			}
     		}
     		for (TypeFilter tf : this.includeFilters) {
     			if (tf.match(metadataReader, getMetadataReaderFactory())) {
     				return isConditionMatch(metadataReader);
     			}
     		}
     		return false;
     	}
     ```

     这些是从`ComponentScan`这个注解中解析出来的，是`includeFilters`和`excludeFilters`这俩属性，平时我们什么都不配置，默认扫描的是@Component @Repository @Service @Controller 这些注解，它们是会默认出现在includeFilters中的。

     如果命中了includefilter，接下来检查是否有conditional注解，如果有，则判断是否满足条件。

  5. 判断扫描到的组件是否是正常的类

     这里是有一套逻辑，因为一些内部类、抽象类、接口编译之后也会生成class文件，而这些文件到这一步是没有被过滤的，这里涉及到一个概念，说类是不是独立的，注释中是这么说的：

     Determine whether the underlying class is independent, i.e. whether it is a top-level class or a nested class (static inner class) that can be constructed independently of an enclosing class.
  
     即不依赖其他类也能正常被构建，因为后面扫描完成，有一个很重要的步骤，是实例化，而那些非静态的内部类、接口、抽象类是不能被实例化的，故这里排除在外。

### 1.2 依次处理扫描到的组件

- 获取组件的scope

  通过解析scope注解获取，默认是单例属性

- 获取BeanDefinition的名称，即BeanName，首先从注解中取，如果没有就基于类名生成一个，用到了Introspector.decapitalize(shortClassName)方法
- 处理`AbstractBeanDefinition` ，设置BeanDefinition中的默认值
- 解析bean的一些注解，并记录到BeanDefinition中，包括Lazy、Primary、DependsOn、Role、Description
- 之后，再次检查对应的BeanDefinition是否已经被加载了，出现这种情况可能是同一个类被扫描到了两次，这里就是检查如果是有两个同名的，只能允许它们是同一个类被扫描了两次，如果是其他情况，即两个bean同名，那么直接报错
- 都检查通过之后，注册该BeanDefinition，等待之后的处理

## 2. 非懒加载单例Bean的创建

本小节介绍在扫描完BeanDefinition之后的，在初始化的时候做的事情，对于每一个扫描到的BeanDefinition，合并成RootBeanDefinition，之后调用getSingleton，如果是单例非懒加载Bean，就实例化、初始化Bean，加载到单例池中。

这里是在ApplicitionContext的`refresh()`方法中调用的，其中有beanFactory.preInstantiateSingletons();这么一步，即初始化所有的非懒加载的单例Bean，具体实现如下：

```java
	public void preInstantiateSingletons() throws BeansException {
		if (logger.isTraceEnabled()) {
			logger.trace("Pre-instantiating singletons in " + this);
		}

		// Iterate over a copy to allow for init methods which in turn register new bean definitions.
		// While this may not be part of the regular factory bootstrap, it does otherwise work fine.
		List<String> beanNames = new ArrayList<>(this.beanDefinitionNames);

		// Trigger initialization of all non-lazy singleton beans...
		for (String beanName : beanNames) {
            // 因为之前BeanDefinition存在继承的概念，这里是合并子BeanDefinition和父BeanDefinition
			RootBeanDefinition bd = getMergedLocalBeanDefinition(beanName);
			if (!bd.isAbstract() && bd.isSingleton() && !bd.isLazyInit()) {
                // 非懒加载单例bean
				if (isFactoryBean(beanName)) {
                    // 处理工厂Bean
					Object bean = getBean(FACTORY_BEAN_PREFIX + beanName);
					if (bean instanceof FactoryBean) {
						FactoryBean<?> factory = (FactoryBean<?>) bean;
						boolean isEagerInit;
						if (System.getSecurityManager() != null && factory instanceof SmartFactoryBean) {
							isEagerInit = AccessController.doPrivileged(
									(PrivilegedAction<Boolean>) ((SmartFactoryBean<?>) factory)::isEagerInit,
									getAccessControlContext());
						}
						else {
							isEagerInit = (factory instanceof SmartFactoryBean &&
									((SmartFactoryBean<?>) factory).isEagerInit());
						}
						if (isEagerInit) {
							getBean(beanName);
						}
					}
				}
				else {
                    // 初始化Bean
					getBean(beanName);
				}
			}
		}

		// Trigger post-initialization callback for all applicable beans...
		for (String beanName : beanNames) {
			Object singletonInstance = getSingleton(beanName);
			if (singletonInstance instanceof SmartInitializingSingleton) {
				StartupStep smartInitialize = this.getApplicationStartup().start("spring.beans.smart-initialize")
						.tag("beanName", beanName);
				SmartInitializingSingleton smartSingleton = (SmartInitializingSingleton) singletonInstance;
				if (System.getSecurityManager() != null) {
					AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
						smartSingleton.afterSingletonsInstantiated();
						return null;
					}, getAccessControlContext());
				}
				else {
					smartSingleton.afterSingletonsInstantiated();
				}
				smartInitialize.end();
			}
		}
	}
```

### 2.1 获取Bean对象

之后的核心实现在getBean(beanName)的doGetBean();方法中，如下:

```java
/**
 * Return an instance, which may be shared or independent, of the specified bean.
 * @param name the name of the bean to retrieve
 * @param requiredType the required type of the bean to retrieve
 * @param args arguments to use when creating a bean instance using explicit arguments
 * (only applied when creating a new instance as opposed to retrieving an existing one)
 * @param typeCheckOnly whether the instance is obtained for a type check,
 * not for actual use
 * @return an instance of the bean
 * @throws BeansException if the bean could not be created
 */
@SuppressWarnings("unchecked")
protected <T> T doGetBean(
      String name, @Nullable Class<T> requiredType, @Nullable Object[] args, boolean typeCheckOnly)
      throws BeansException {
	// 处理BeanName，如果是前面加了&符号，去除之，如果是别名，得到其正式的名称
   String beanName = transformedBeanName(name);
   Object beanInstance;

    // 这里先试着获取下单例池中有没有对应的单例对象，如果有的话，就直接返回
   // Eagerly check singleton cache for manually registered singletons.
   Object sharedInstance = getSingleton(beanName);
   if (sharedInstance != null && args == null) {
      if (logger.isTraceEnabled()) {
         if (isSingletonCurrentlyInCreation(beanName)) {
            logger.trace("Returning eagerly cached instance of singleton bean '" + beanName +
                  "' that is not fully initialized yet - a consequence of a circular reference");
         }
         else {
            logger.trace("Returning cached instance of singleton bean '" + beanName + "'");
         }
      }
      beanInstance = getObjectForBeanInstance(sharedInstance, name, beanName, null);
   }

   else {
      // Fail if we're already creating this bean instance:
      // We're assumably within a circular reference.
      if (isPrototypeCurrentlyInCreation(beanName)) {
         throw new BeanCurrentlyInCreationException(beanName);
      }

       // 如果本bean工厂不存在传进来的BeanName，并且存在父工厂，则到父工厂中寻找
      // Check if bean definition exists in this factory.
      BeanFactory parentBeanFactory = getParentBeanFactory();
      if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
         // Not found -> check parent.
         String nameToLookup = originalBeanName(name);
         if (parentBeanFactory instanceof AbstractBeanFactory) {
            return ((AbstractBeanFactory) parentBeanFactory).doGetBean(
                  nameToLookup, requiredType, args, typeCheckOnly);
         }
         else if (args != null) {
            // Delegation to parent with explicit args.
            return (T) parentBeanFactory.getBean(nameToLookup, args);
         }
         else if (requiredType != null) {
            // No args -> delegate to standard getBean method.
            return parentBeanFactory.getBean(nameToLookup, requiredType);
         }
         else {
            return (T) parentBeanFactory.getBean(nameToLookup);
         }
      }

      if (!typeCheckOnly) {
         markBeanAsCreated(beanName);
      }

      StartupStep beanCreation = this.applicationStartup.start("spring.beans.instantiate")
            .tag("beanName", name);
      try {
         if (requiredType != null) {
            beanCreation.tag("beanType", requiredType::toString);
         }
          // 取合并之后的rootBeanDefinition
         RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
         checkMergedBeanDefinition(mbd, beanName, args);

          // 如果有被dependsOn注解修饰，优先初始化dependsOn中的bean
         // Guarantee initialization of beans that the current bean depends on.
         String[] dependsOn = mbd.getDependsOn();
         if (dependsOn != null) {
            for (String dep : dependsOn) {
               if (isDependent(beanName, dep)) {
                  throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                        "Circular depends-on relationship between '" + beanName + "' and '" + dep + "'");
               }
               registerDependentBean(dep, beanName);
               try {
                  getBean(dep);
               }
               catch (NoSuchBeanDefinitionException ex) {
                  throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                        "'" + beanName + "' depends on missing bean '" + dep + "'", ex);
               }
            }
         }

          // 之后基于不同的scope来创建bean
         // Create bean instance.
         if (mbd.isSingleton()) {
            sharedInstance = getSingleton(beanName, () -> {
               try {
                  return createBean(beanName, mbd, args);
               }
               catch (BeansException ex) {
                  // Explicitly remove instance from singleton cache: It might have been put there
                  // eagerly by the creation process, to allow for circular reference resolution.
                  // Also remove any beans that received a temporary reference to the bean.
                  destroySingleton(beanName);
                  throw ex;
               }
            });
            beanInstance = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
         }

         else if (mbd.isPrototype()) {
            // It's a prototype -> create a new instance.
            Object prototypeInstance = null;
            try {
               beforePrototypeCreation(beanName);
               prototypeInstance = createBean(beanName, mbd, args);
            }
            finally {
               afterPrototypeCreation(beanName);
            }
            beanInstance = getObjectForBeanInstance(prototypeInstance, name, beanName, mbd);
         }

         else {
            String scopeName = mbd.getScope();
            if (!StringUtils.hasLength(scopeName)) {
               throw new IllegalStateException("No scope name defined for bean '" + beanName + "'");
            }
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
               beanInstance = getObjectForBeanInstance(scopedInstance, name, beanName, mbd);
            }
            catch (IllegalStateException ex) {
               throw new ScopeNotActiveException(beanName, scopeName, ex);
            }
         }
      }
      catch (BeansException ex) {
         beanCreation.tag("exception", ex.getClass().toString());
         beanCreation.tag("message", String.valueOf(ex.getMessage()));
         cleanupAfterBeanCreationFailure(beanName);
         throw ex;
      }
      finally {
         beanCreation.end();
      }
   }

   return adaptBeanInstance(name, beanInstance, requiredType);
}
```

- 处理BeanName

  如果是前面加了&符号，去除之，如果是别名，得到其正式的名称

- 先试着获取下单例池中有没有对应的单例对象，如果有的话，就直接返回

- 如果本bean工厂不存在传进来的BeanName，并且存在父工厂，则到父工厂中寻找

- 如果有被dependsOn注解修饰，优先初始化dependsOn中的bean

- 之后基于不同的scope来创建bean

  这里的scope主要有以下几种

  - singleton

  - prototype

  - requestScope

    即同一个request中的bean要保持一致

  - sessionScope

    即同一个session中的bean要保持一致

  之后的两个是通过设置request和session中的属性来实现的

### 2.2 创建Bean对象

以上的情况，需要真正创建bean的时候，就会落到AbstractAutowireCapableBeanFactory中实现的createBean中，

首先加载BeanClass，resolveBeanClass(mbd, beanName)，把**bean加载到对应的classLoader中**。

之后是bean构造的**第一个扩展点**，如下：

```java
try {
   // Give BeanPostProcessors a chance to return a proxy instead of the target bean instance.
   Object bean = resolveBeforeInstantiation(beanName, mbdToUse);
   if (bean != null) {
      return bean;
   }
}
catch (Throwable ex) {
   throw new BeanCreationException(mbdToUse.getResourceDescription(), beanName,
         "BeanPostProcessor before instantiation of bean failed", ex);
}
```

这里是实例化之前调用的接口，注释中看到的就是给BeanPostProcessor接口的实现类一个构造代理bean的机会，实现偷天幻日的机会。具体如下：

```java
/**
 * Apply before-instantiation post-processors, resolving whether there is a
 * before-instantiation shortcut for the specified bean.
 * @param beanName the name of the bean
 * @param mbd the bean definition for the bean
 * @return the shortcut-determined bean instance, or {@code null} if none
 */
@Nullable
protected Object resolveBeforeInstantiation(String beanName, RootBeanDefinition mbd) {
   Object bean = null;
   if (!Boolean.FALSE.equals(mbd.beforeInstantiationResolved)) {
      // Make sure bean class is actually resolved at this point.
      if (!mbd.isSynthetic() && hasInstantiationAwareBeanPostProcessors()) {
         Class<?> targetType = determineTargetType(beanName, mbd);
         if (targetType != null) {
            bean = applyBeanPostProcessorsBeforeInstantiation(targetType, beanName);
            if (bean != null) {
               bean = applyBeanPostProcessorsAfterInitialization(bean, beanName);
            }
         }
      }
      mbd.beforeInstantiationResolved = (bean != null);
   }
   return bean;
}
```

首先会看，是否已经实例化了，如果没有实例化，就依次调用已经实现了的postProcessBeforeInstantiation接口，Spring中的**AOP**即利用的这里的扩展点，将命中切面表达式的Bean替换成对应的代理类，AOP实现的接口是`AbstractAutoProxyCreator`。

之后确认是走正常的Bean初始化流程，即进入doCreateBean方法，具体实现如下，这里实现了bean生命周期中的多个重要的扩展点，包括依赖注入、初始化前后、实例化后、初始化等：

```java
/**
 * Actually create the specified bean. Pre-creation processing has already happened
 * at this point, e.g. checking {@code postProcessBeforeInstantiation} callbacks.
 * <p>Differentiates between default bean instantiation, use of a
 * factory method, and autowiring a constructor.
 * @param beanName the name of the bean
 * @param mbd the merged bean definition for the bean
 * @param args explicit arguments to use for constructor or factory method invocation
 * @return a new instance of the bean
 * @throws BeanCreationException if the bean could not be created
 * @see #instantiateBean
 * @see #instantiateUsingFactoryMethod
 * @see #autowireConstructor
 */
protected Object doCreateBean(String beanName, RootBeanDefinition mbd, @Nullable Object[] args)
      throws BeanCreationException {

   // Instantiate the bean.
   BeanWrapper instanceWrapper = null;
   if (mbd.isSingleton()) {
      instanceWrapper = this.factoryBeanInstanceCache.remove(beanName);
   }
    // 实例化bean，这里会推断使用哪个构造方法实例化对应的bean
   if (instanceWrapper == null) {
      instanceWrapper = createBeanInstance(beanName, mbd, args);
   }
   Object bean = instanceWrapper.getWrappedInstance();
   Class<?> beanType = instanceWrapper.getWrappedClass();
   if (beanType != NullBean.class) {
      mbd.resolvedTargetType = beanType;
   }

    // 调用MergedBeanDefinitionPostProcessor中的postProcessMergedBeanDefinition
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

   // Initialize the bean instance.
   Object exposedObject = bean;
   try {
      populateBean(beanName, mbd, instanceWrapper);
      exposedObject = initializeBean(beanName, exposedObject, mbd);
   }
   catch (Throwable ex) {
      if (ex instanceof BeanCreationException && beanName.equals(((BeanCreationException) ex).getBeanName())) {
         throw (BeanCreationException) ex;
      }
      else {
         throw new BeanCreationException(
               mbd.getResourceDescription(), beanName, "Initialization of bean failed", ex);
      }
   }

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

   // Register bean as disposable.
   try {
      registerDisposableBeanIfNecessary(beanName, bean, mbd);
   }
   catch (BeanDefinitionValidationException ex) {
      throw new BeanCreationException(
            mbd.getResourceDescription(), beanName, "Invalid destruction signature", ex);
   }

   return exposedObject;
}
```

首先会使用instanceWrapper = createBeanInstance(beanName, mbd, args)来**实例化bean**。

包含的扩展点

- 调用`MergedBeanDefinitionPostProcessor`中的`postProcessMergedBeanDefinition`

  这里校验一些关于BeanDefinition的数据，同时也可以做些改动

  `CommonAnnotationBeanPostProcessor`、`AutowiredAnnotationBeanPostProcessor`都实现了这个扩展点，这里是做一些注解的前置校验的工作，在这里找到对应的注入点

  - AutowiredAnnotationBeanPostProcessor中的实现

    其中会扫描所有被Autowired、Value、Inject注解的非static字段、方法，如果静态属性也参与这种注入，会对原型Bean的依赖注入产生影响

    如果方法没有参数，也可以被当作注入点

    > 这里涉及一个概念：桥接方法，java字节码中，对于实现接口中的方法会出现两个方法，其中一个是桥接方法，扫描的过程中会跳过这种方法

    如果一个Bean的类型是String这种简单类型（以java开头），这里会做下过滤，不会去寻找注入点

    以上会循环遍历子类+父类+……

    找到注入点之后会缓存到`injectionMetadataCache`中，方便下一个扩展点取用

    

- 调用`InstantiationAwareBeanPostProcessor`中的`postProcessAfterInstantiation`实例化之后的扩展点

  ```
  // Give any InstantiationAwareBeanPostProcessors the opportunity to modify the
  // state of the bean before properties are set. This can be used, for example,
  // to support styles of field injection.
  ```

- 做Spring自带的依赖注入

  手动赋值优于依赖注入

  - 传统方式注入

    这里不会关心简单类型的注入 Enum CharSequence Number  Date 等

    - byname

      找到set方法，之后根据set方法的名称推断出要注入bean的name，之后就直接getBean(name)

    - bytype

      找到set方法，之后根据参数的类型，找到对应的对象

    这种方式现在已经不怎么用了，因为太灵活了，一旦用了这种方式，就要慎用set方法了

- 调用`InstantiationAwareBeanPostProcessor`的`postProcessProperties`以及`postProcessPropertyValues`(废弃)接口做**依赖注入**

  - AutowiredAnnotationBeanPostProcessor中的实现

    调用`postProcessProperties`

    基于字段的类型、名字找到对应的bean或者方法参数的类型、名字找到对应的bean

- 调用`setBeanName`、`setBeanClassLoader`、`setBeanFactory`

- 调用`BeanPostProcessor`中的`postProcessBeforeInitialization`接口，初始化前的扩展点

- 调用`InitializingBean`中的`afterPropertiesSet`接口

- 调用初始化方法

- 调用`BeanPostProcessor`中的`postProcessAfterInitialization`接口，初始化后的扩展点

- 初始化结束

### 2.3 销毁Bean对象

触发时机：容器销毁的时候，即调用close()方法，或者注册关闭钩子，进程**正常关闭**的时候

对象：实现了`DisposableBean`接口

​			使用注解指定了销毁方法

​			实现了`AutoCloseable`接口

​			`BeanDefinition`接口的`resolvedDestroyMethodName`属性是(inferred)，并且实现了close()或者shutdown()方法

满足以上任一条件的**单例Bean**

之后关闭bean的时候，就把所有的关闭方法找出来，分别执行。

销毁单例Bean的时候，依赖它的Bean也会一并被销毁

###  2.4 常用注解

- @AutoWire

  如果有Lazy注解，扫描到的时候就创建一个代理对象，直接返回该对象，真正使用这个对象的时候，才会去找bean

- @Value注解

  可以使用$（变量key）或者#（spring表达式）前缀





