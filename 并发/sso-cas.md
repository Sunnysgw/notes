# sso单点登录之cas

- 访问业务网站，被裹在最外面的filter处理
- session中不存在登录信息，重定向到cas server，其中用户要访问的地址以service的参数被加到cas server地址后面
- cas server收到请求，首先看是否有tgc，如果没有，直接重定向到登录页面
- 用户在登录页面登录认证，之后，后台生成tgt，添加tgc，同时生成ticket
- 之后把ticket作为参数，重新访问业务网站
- 同样，被filter处理，校验ticket到可用性，如果可用，即直接放开

以上，是一个空白的应用从0开始登录的过程