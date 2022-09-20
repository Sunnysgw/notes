# spring MVC

> servlet -> spring mvc

## MVC

model view controller

servlet中，对于参数的解析、业务的分发、相应的设置，都要手动来配置，spring mvc对此进行了封装，提升了开发效率。

DispatcherServlet是一套调度器的逻辑，调度不同的组件处理请求，这个东西是spirng mvc的核心。

handlermapping解析用户请求，返回处理链路（拦截器 + handler）之后依次做处理。

调用拦截器，中间涉及的注入点就是拦截器的几个周期

之前的这一套是返回的modelandview，后面涉及的就是基于返回的model渲染对应的view（jsp）并返回。



核心方法是DispatcherServlet中的doDispatch



requestmapping路径匹配过程 首先做精准匹配，之后做正则过滤



这些就是在afterproperties中做的

初始化pathLookup的map，key：path value：requestmappinginfo



关于spring mvc请求过程中的参数解析，可以参考这篇文章：https://juejin.cn/post/6844903841775747079

请求过程如下：

![img](https://p1-jj.byteimg.com/tos-cn-i-t2oaga2asx/gold-user-assets/2019/5/7/16a9290983a05cde~tplv-t2oaga2asx-zoom-in-crop-mark:3024:0:0:0.awebp)



## 数据模式

策略者模式











