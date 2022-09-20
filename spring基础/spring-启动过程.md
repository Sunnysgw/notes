# spring 启动过程

> spring启动的过程中，其中一个重要的功能就是为bean的整个生命周期服务

涉及的涉及模式： 模板模式

涉及概念：事件监听器、beanfactorypostprocessor



**事件监听器**

会注册事件监听器（基于bean的方式、基于方法注解的方式）

之后发布事件的时候，遍历调用所有的监听器

**beanfactorypostprocessor**

初始化完成bean工厂之后，可以对bean工厂中的内容做一些处理 



之后就是一些spring boot中常用注解的原理，基于此再看它们的使用场景





spring boot使用的applicationcontext实现是不支持多次刷新的



创建bean工厂

创建两个扫描器

​	其中会向bean工厂中注册一些前置后置处理器



解析配置类

扫描

缓存beandefinition beanpostprocessors 

初始化单例池

