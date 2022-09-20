## 条件注解

springboot中常用的条件注解

对bean、class、java版本

ConditionalOnBean
ConditionalOnMissingBean
ConditionalOnSingleCandidate

针对是否存在或者不存在或者存在单例bean



ConditionalOnClass
ConditionalOnMissingClass

从classloader中判断是否存在对应的class



ConditionalOnProperty
ConditionalOnResource

从environment中基于property判断



ConditionalOnCloudPlatform
ConditionalOnExpression
ConditionalOnJava

是基于每个java版本的特性（某个类中是否有某种方法）来判断的，emm 硬编码

ConditionalOnJndi
ConditionalOnNotWebApplication
ConditionalOnWarDeployment
ConditionalOnWebApplication

web服务器类型 servlet、reactive

## 自动配置实现

这里的自动是相对于开发者而言的，就是spring主动把大部分开发场景要配置的bean都想好了，利用多种条件注解控制是否加载这些配置类。

是基于Import注解实现的，更具体的，使用了DeferredImportSelector这个接口，这样就保证在加载完用户项目中的所有bean之后，再基于现有情况处理自动配置。

>关于DeferredImportSelector，spring boot中自动配置

因为自动配置类实在太多，之前都是所有放到spring.factory中，现在看的2.7.x版本，把自动配置类集中放到了META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports文件中，外部starter依然可以放到spring.factory中。

同时，为了减轻后期执行匹配逻辑的复杂度，这里会提前构建好了对应的初始的过滤条件，放在了一个properties文件中，ConditionalOnSingleCandidate、ConditionalOnClass、ConditionalOnBean这三种。一个初始化的spring boot web项目，经过过滤，剩下了37个自动配置类。这种效率应该是比经过asm加载类文件，之后再做匹配效率高一点。

## 自动配置中的一些属性

```java
// 用于注册自动配置类，同时加载spring.factory中的自动配置类，这些类将会在正常bean都扫描完成之后再注册
@EnableAutoConfiguration
// 这里会把自动配置类过滤掉自动配置类以及一些自定义的过滤机制
@ComponentScan(excludeFilters = { @Filter(type = FilterType.CUSTOM, classes = TypeExcludeFilter.class),
		@Filter(type = FilterType.CUSTOM, classes = AutoConfigurationExcludeFilter.class) })


```

## webserver自动配置例子

它的自动配置类上主要有如下注解：

```java
@ConditionalOnClass(ServletRequest.class)
@ConditionalOnWebApplication(type = Type.SERVLET)
@EnableConfigurationProperties(ServerProperties.class)
@Import({ ServletWebServerFactoryAutoConfiguration.BeanPostProcessorsRegistrar.class,
      ServletWebServerFactoryConfiguration.EmbeddedTomcat.class,
      ServletWebServerFactoryConfiguration.EmbeddedJetty.class,
      ServletWebServerFactoryConfiguration.EmbeddedUndertow.class })
```

其中，ServletWebServerFactoryAutoConfiguration.BeanPostProcessorsRegistrar.class向beanfactory中注册了一个beanpostprocessor，作用就是在bean初始化前，把配置文件中的配置传递到真正实现的webserver中，如下：

```java
@Override
public void customize(ConfigurableServletWebServerFactory factory) {
   PropertyMapper map = PropertyMapper.get().alwaysApplyingWhenNonNull();
   map.from(this.serverProperties::getPort).to(factory::setPort);
   map.from(this.serverProperties::getAddress).to(factory::setAddress);
   map.from(this.serverProperties.getServlet()::getContextPath).to(factory::setContextPath);
   map.from(this.serverProperties.getServlet()::getApplicationDisplayName).to(factory::setDisplayName);
   map.from(this.serverProperties.getServlet()::isRegisterDefaultServlet).to(factory::setRegisterDefaultServlet);
   map.from(this.serverProperties.getServlet()::getSession).to(factory::setSession);
   map.from(this.serverProperties::getSsl).to(factory::setSsl);
   map.from(this.serverProperties.getServlet()::getJsp).to(factory::setJsp);
   map.from(this.serverProperties::getCompression).to(factory::setCompression);
   map.from(this.serverProperties::getHttp2).to(factory::setHttp2);
   map.from(this.serverProperties::getServerHeader).to(factory::setServerHeader);
   map.from(this.serverProperties.getServlet()::getContextParameters).to(factory::setInitParameters);
   map.from(this.serverProperties.getShutdown()).to(factory::setShutdown);
   for (WebListenerRegistrar registrar : this.webListenerRegistrars) {
      registrar.register(factory);
   }
   if (!CollectionUtils.isEmpty(this.cookieSameSiteSuppliers)) {
      factory.setCookieSameSiteSuppliers(this.cookieSameSiteSuppliers);
   }
}
```

之后就是基于目前引入类的情况，决定初始化哪个webserver，之后springboot启动的时候会获取并启动之。