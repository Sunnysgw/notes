## 手写spring-boot步骤

- 初始化spring容器

- 初始化tomcat

- tomcat中添加servlet容器

  这里添加的是dispatcherservlet

- 之后实现自动配置的注入

  其中一个点是这里基于DeferredImportSelector这个接口实现依赖注入，这样能实现在最后做依赖注入，配合类似conditionalonmissingbean这种注解使用才能会安全

  同时在selector方法中，使用SPI加载自动配置类

其中，spring boot中使用asm解析class文件，之后解析其中的注解，其中不会涉及类加载，所以类似于conditionalonclass这种注解才不会报错

