## spring boot

[TOC]



### 1. helloworld程序
### 2. 依赖管理
#### 2.1 版本管理
各种各样的starter中已经在spring-boot-dependencies中定义好了，如下：
```xml
<dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>org.apache.activemq</groupId>
        <artifactId>activemq-amqp</artifactId>
        <version>${activemq.version}</version>
      </dependency>
      <dependency>
        <groupId>org.apache.activemq</groupId>
        <artifactId>activemq-blueprint</artifactId>
        <version>${activemq.version}</version>
      </dependency>
</dependencyManagement>
```
如果想要使用不同的版本，可以在当前项目中配置version标签中引用的key值
#### 2.2 启动器管理（starter）
spring boot中针对支持的场景基于spring-boot-starter-*的规则构建了对应的开发场景需要的依赖包，它们都有一个统一的底层依赖
```xml
<dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter</artifactId>
      <version>2.5.4</version>
      <scope>compile</scope>
</dependency>
```
### 3. 自动配置

- 自动配置好所需场景中的常用配置，自带的配置会在spring-boot-autoconfigure包中

> 自动配置中大量使用了conditional类似的注解，当对应的包被引入或者有对应配置的时候，才会生效

- Configuration注解中有个配置proxyBeanMethod，默认会对bean注解修饰的方法做代理（使用cglib），保证多次调用该方法获取的bean是一致的，如果确保该configuration中的生成bean的方法不会直接被调用，那么可以设置为false，从而不会费力生成代理类，提升运行效率

- controller service component 等

- import注解，传进去的值是一个class数组，会使用class的无参构造方法帮你构造bean，同时可以实现selector接口、beanregister相关接口实现bean的初始化，可以一次声明多个bean

- conditional注解，判断是否要初始化某个bean

  > conditionalOnxxx，其中的xxx指的是对应条件，conditionalonbean类似的，看起来挺有意思的，根据不同的场景选择使用不同的注解

- 配置绑定

  - EnableConfigurationProperties，value中是要注入属性的bean，一定要配合ConfigurationProperties一起使用，实现了构造bean和属性注入的功能，这种用于外部jar包中要声明的bean
  - ConfigurationProperties也可以单独配合bean声明注解一起使用，用于本工程中要声明的bean

  > 属性注入有一个基本的前提，就是要被注入的类一定是要被注册为bean的，注册为bean的方式有很多种：
  >
  > 本工程中大多数就使用
  >
  > - component
  > - controller
  > - service
  > - ....
  >
  > 这些注解
  >
  > 外部的jar包，使用import、EnableConfigurationProperties等进行bean的注册
  >
  > 注册完成之后，即根据Value或者ConfigurationProperties注解找到属性和配置文件中key的对应关系

  相关注解EnableAutoConfiguration

  ```java
  @AutoConfigurationPackage
  @Import(AutoConfigurationImportSelector.class)
  ```

  其中AutoConfigurationPackage即

  ```java
  @Import(AutoConfigurationPackages.Registrar.class)
  ```

  将main所在的所有包下的组件进行注册

  而Import(AutoConfigurationImportSelector.class)则是自动配置的核心，在其中会使用如下方法获取提前写死的configuration配置类：

  ```java
  List<String> configurations = getCandidateConfigurations(annotationMetadata, attributes);
  ```

  更具体些，是加载META_INF/spring.factories中的配置，如下：

  ```java
  	private static Map<String, List<String>> loadSpringFactories(ClassLoader classLoader) {
  		Map<String, List<String>> result = cache.get(classLoader);
  		if (result != null) {
  			return result;
  		}
  
  		result = new HashMap<>();
  		try {
  			Enumeration<URL> urls = classLoader.getResources(FACTORIES_RESOURCE_LOCATION);
  			while (urls.hasMoreElements()) {
  				URL url = urls.nextElement();
  				UrlResource resource = new UrlResource(url);
  				Properties properties = PropertiesLoaderUtils.loadProperties(resource);
  				for (Map.Entry<?, ?> entry : properties.entrySet()) {
  					String factoryTypeName = ((String) entry.getKey()).trim();
  					String[] factoryImplementationNames =
  							StringUtils.commaDelimitedListToStringArray((String) entry.getValue());
  					for (String factoryImplementationName : factoryImplementationNames) {
  						result.computeIfAbsent(factoryTypeName, key -> new ArrayList<>())
  								.add(factoryImplementationName.trim());
  					}
  				}
  			}
  
  			// Replace all lists with unmodifiable lists containing unique elements
  			result.replaceAll((factoryType, implementations) -> implementations.stream().distinct()
  					.collect(Collectors.collectingAndThen(Collectors.toList(), Collections::unmodifiableList)));
  			cache.put(classLoader, result);
  		}
  		catch (IOException ex) {
  			throw new IllegalArgumentException("Unable to load factories from location [" +
  					FACTORIES_RESOURCE_LOCATION + "]", ex);
  		}
  		return result;
  	}
  ```

  这样子返回的是一个map，key为具体的包名，之后就根据自动配置类的包名获取所有的自动配置类：

  ```java
  loadSpringFactories(classLoaderToUse).getOrDefault(factoryTypeName, Collections.emptyList());
  ```

  之后基于给定的一些条件再决定是否确定初始化对应的bean。

  - 有意思的东西

    ```java
    		@Bean
    		@ConditionalOnBean(MultipartResolver.class)
    		@ConditionalOnMissingBean(name = DispatcherServlet.MULTIPART_RESOLVER_BEAN_NAME)
    		public MultipartResolver multipartResolver(MultipartResolver resolver) {
    			// Detect if the user has created a MultipartResolver but named it incorrectly
    			return resolver;
    		}
    ```

    这里会看用户是否注册了MultipartResolver这种类型的组件，并将命名规范化为multipartResolver

    spring boot会默认在底层配置好必须的组件，但是以用户配置的优先

###  4.最佳实践

- 引入场景依赖，对于要开发的场景，一般而言，都会有提供对应的spring-boot-start-xxx这种starter的jar包，将所需要的依赖等一站式导入
- 之后要去基于使用原理去看starter中引入了哪些依赖，同时要看自动配置中配置了哪些东西，结合引入的依赖和配置去看是否符合自己现在的应用场景
- 配置必要的属性以及自己自己需要做的一些调整

> 可以把debug配置为true，去看哪些配置生效了，哪些没有生效

> Spring中会有大量customizer，同样用于配制

 
