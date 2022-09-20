# spring mvc父子容器启动

> 无xml的方式，基于SPI的机制初始化spring容器

## 1. 构造父子容器

tomcat启动的时候，基于SPI调用SpringServletContainerInitializer的onStartUp方法，其中会去找WebApplicationInitializer的实现类，实例化这些实现类，并且调用它们的onStartUp方法。

spring给提供了一个比较核心的抽象实现类AbstractAnnotationConfigDispatcherServletInitializer，调用它的onStartup方法的时候，就会创建spring中的父子容器，并初始化servletContext。这里子容器的职责是加载servlet，并处理controller，负责接收servlet收到的请求，做简单的处理之后分发给具体的业务bean，而父容器的职责就是负责处理业务bean，包括具体的业务逻辑，以及中间件逻辑。

这里会首先初始化父容器。

## 2. 初始化父子容器

调用DispatcherServlet的init()方法，初始化子容器，这里会初始化spring mvc中负责请求相关的bean，包括requestmapping的预处理，拦截器的初始化等。之后初始化dispatcherServlet中的组件，基本逻辑就是getBean，如果不存在就从默认配置文件中获取。



其中requestmapping默认是基于RequestMappingHandlerMapping来处理的，即看bean工厂中的bean里面是否有存在使用Controller或者RequestMapping修饰的类，如下：

```java
/**
 * Scan beans in the ApplicationContext, detect and register handler methods.
 * @see #getCandidateBeanNames()
 * @see #processCandidateBean
 * @see #handlerMethodsInitialized
 */
protected void initHandlerMethods() {
   for (String beanName : getCandidateBeanNames()) {
      if (!beanName.startsWith(SCOPED_TARGET_NAME_PREFIX)) {
         processCandidateBean(beanName);
      }
   }
   handlerMethodsInitialized(getHandlerMethods());
}
```



这里看，就是把spring mvc相关的所有bean以及逻辑放在子容器中，把业务逻辑相关的bean放在父容器中，就是使职责划分更加明确。按照这种逻辑配置后，也就会产生一些很有趣的现象，包括在service类型的bean中不能注入controller类型的bean，因为初始化父容器的时候，子容器还没有初始化，根本取不到。其实，完全可以用一个容器来做，因为从目前这两个容器的使用流程中，中间的关系就是子容器接收请求，业务分发给父容器中的bean，那把父容器中的bean放到子容器中做初始化，也完全没问题，这里就是spring boot中的思路。



> 这两节课讲的有点浮夸，课里面的点有点散，需要自己提前对整体的脉络有把握之后再去看。













