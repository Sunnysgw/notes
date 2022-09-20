# spring bean推断构造方法

实例化bean的时候

- 只有一个构造方法，就不需要选择
- 优先使用无参构造方法
- 通过Autowired注解指定初始化的时候调用的构造方法



AutowiredAnnotationBeanPostProcessor的determineCandidateConstructors方法判断

- 有方法加上了autowried注解

  找到加了autowired注解的构造方法返回，之后让spring去选

- 没有方法加上autowired注解

  如果只有默认构造方法，就用默认构造方法

  只有一个构造方法，就用唯一的

  有多个构造方法，如果有默认的，就用默认的，没有的话，就会报错

-------

对于Bean注解，和xml中定义factory-bean factory-method的注解类似

-----

lookup注解

使用该注解修饰了bean中的方法，之后每次调用该方法，就会获取lookup注解中标注的的bean。

具体是使用代理的方式实现的，每次执行被标记的方法的时候，就会去过去获取指定的bean。

