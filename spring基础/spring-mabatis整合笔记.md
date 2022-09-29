# spring mybatis 整合

> 整合的目的是为了把mybatis查询功能的对象作为一个bean注册到spring 容器中

在mybatis中，有这几种重要的角色：

- datasource

  存储具体的数据库连接信息，同时用于建立并管理和数据库之间的连接，生产环境会采用连接池的方式实现。

- sqlsession

  对外暴露了具体的crud操作

- Executor

  sqlsession中使用executor做具体的操作

- sqlsessionfactory

  基于datasource构建sqlsession

## spring整合mybatis过程

整个整合的过程即把定义好的mybatis操作封装成bean，注册到Spring 容器。

1. 使用MapperScan注解开启扫描dao接口

   MapperScan注解中注册了MapperScannerConfigurer类，该类实现了BeanDefinitionRegistryPostProcessor接口，而在接口的postProcessBeanDefinitionRegistry方法中，使用自定义的扫描器ClassPathMapperScanner扫描注解basePackages属性中配置的路径，这里自定义的扫描器重新定义了候选人的范围，默认只会扫描所有包含方法的接口，扫描规则如下：

   ```java
   return beanDefinition.getMetadata().isInterface() && beanDefinition.getMetadata().isIndependent();
   ```

   扫描到的接口，之后借助FactoryBean的机制给包装成bean，这里用的是MapperFactoryBean.class。它的getObject方法即返回对应的代理bean。
   
   具体的代理类是MapperProxy，之后的步骤就跟直接用mybatis一致了。这里目前不是太清楚todo，只知道后面的请求落到了SqlSessionTemplate上。

2. 执行sql查询

   之后是使用SqlSessionTemplate来执行用户给的sql请求，它同样是一个sqlsession的代理，实现代理的逻辑如下：

   ```java
   this.sqlSessionProxy = (SqlSession) newProxyInstance(SqlSessionFactory.class.getClassLoader(),
       new Class[] { SqlSession.class }, new SqlSessionInterceptor());
   ```

   而SqlSessionInterceptor中的逻辑如下：

   ```java
   public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
       SqlSession sqlSession = getSqlSession(SqlSessionTemplate.this.sqlSessionFactory,
           SqlSessionTemplate.this.executorType, SqlSessionTemplate.this.exceptionTranslator);
       try {
         Object result = method.invoke(sqlSession, args);
         if (!isSqlSessionTransactional(sqlSession, SqlSessionTemplate.this.sqlSessionFactory)) {
           // force commit even on non-dirty sessions because some databases require
           // a commit/rollback before calling close()
           sqlSession.commit(true);
         }
         return result;
       } catch (Throwable t) {
         Throwable unwrapped = unwrapThrowable(t);
         if (SqlSessionTemplate.this.exceptionTranslator != null && unwrapped instanceof PersistenceException) {
           // release the connection to avoid a deadlock if the translator is no loaded. See issue #22
           closeSqlSession(sqlSession, SqlSessionTemplate.this.sqlSessionFactory);
           sqlSession = null;
           Throwable translated = SqlSessionTemplate.this.exceptionTranslator
               .translateExceptionIfPossible((PersistenceException) unwrapped);
           if (translated != null) {
             unwrapped = translated;
           }
         }
         throw unwrapped;
       } finally {
         if (sqlSession != null) {
           closeSqlSession(sqlSession, SqlSessionTemplate.this.sqlSessionFactory);
         }
       }
     }
   }
   ```

   即，执行其中的每个方法的时候，都会调用getSqlSession方法，如下：

   ```java
   public static SqlSession getSqlSession(SqlSessionFactory sessionFactory, ExecutorType executorType,
       PersistenceExceptionTranslator exceptionTranslator) {
   
     notNull(sessionFactory, NO_SQL_SESSION_FACTORY_SPECIFIED);
     notNull(executorType, NO_EXECUTOR_TYPE_SPECIFIED);
   
     SqlSessionHolder holder = (SqlSessionHolder) TransactionSynchronizationManager.getResource(sessionFactory);
   
     SqlSession session = sessionHolder(executorType, holder);
     if (session != null) {
       return session;
     }
   
     LOGGER.debug(() -> "Creating a new SqlSession");
     session = sessionFactory.openSession(executorType);
   
     registerSessionHolder(sessionFactory, executorType, exceptionTranslator, session);
   
     return session;
   }
   ```

   即，从事务管理器中取sqlsession，如果有，说明当前正在一段事务中，即使用取到的sqlsession，生命周期也交给事务管理器，如果没有，就使用sqlsessionfactory构建一个新的，并把它注册到事务管理器中。





多个线程并发的使用sqlsession的时候，默认实现不是线程安全的，实际是使threadlocal实现的，保证每个线程取到的sqlsession不一样

**如果不开启事务，一级缓存会失效（面试）**，如上方的代码，不使用事务，默认即每次调用mapper接口即一次独立的事务，sqlsessiontemplate中执行完业务逻辑之后，即直接提交了，下方是具体代码，所以这个也不算是失效，因为本来也不是一个sqlsession，也就谈不上失效了：

```java
      if (!isSqlSessionTransactional(sqlSession, SqlSessionTemplate.this.sqlSessionFactory)) {
        // force commit even on non-dirty sessions because some databases require
        // a commit/rollback before calling close()
        sqlSession.commit(true);
      }
```













