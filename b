## 概述

这篇文章分享 Gin 的路由配置，主要包含的功能点如下：

- 实现了，路由分组 v1版本、v2版本。
- 实现了，生成签名和验证验证。
- 实现了，在配置文件中读取配置。

## 路由配置

比如我们的接口地址是这样的：

- `/v1/product/add`
- `/v1/member/add`
- `/v2/product/add`
- `/v2/member/add`

假设需求是这样的，接口支持多种请求方式，v1 不需签名验证，v2 需要签名验证，路由文件应该这样写：

```
package router

import (
	"ginDemo/common"
	"ginDemo/controller/v1"
	"ginDemo/controller/v2"
	"github.com/gin-gonic/gin"
	"net/url"
	"strconv"
)

func InitRouter(r *gin.Engine)  {

	r.GET("/sn", SignDemo)

	// v1 版本
	GroupV1 := r.Group("/v1")
	{
		GroupV1.Any("/product/add", v1.AddProduct)
		GroupV1.Any("/member/add", v1.AddMember)
	}

	// v2 版本
	GroupV2 := r.Group("/v2", common.VerifySign)
	{
		GroupV2.Any("/product/add", v2.AddProduct)
		GroupV2.Any("/member/add", v2.AddMember)
	}
}

func SignDemo(c *gin.Context) {
	ts := strconv.FormatInt(common.GetTimeUnix(), 10)
	res := map[string]interface{}{}
	params := url.Values{
		"name"  : []string{"a"},
		"price" : []string{"10"},
		"ts"    : []string{ts},
	}
	res["sn"] = common.CreateSign(params)
	res["ts"] = ts
	common.RetJson("200", "", res, c)
}
```

`.Any` 表示支持多种请求方式。

`controller/v1` 表示 v1 版本的文件。

`controller/v2` 表示 v2 版本的文件。

`SignDemo` 表示生成签名的Demo。

接下来，给出一些代码片段：

验证签名方法：

```
// 验证签名
func VerifySign(c *gin.Context) {
	var method = c.Request.Method
	var ts int64
	var sn string
	var req url.Values

	if method == "GET" {
		req = c.Request.URL.Query()
		sn = c.Query("sn")
		ts, _  = strconv.ParseInt(c.Query("ts"), 10, 64)

	} else if method == "POST" {
		req = c.Request.PostForm
		sn = c.PostForm("sn")
		ts, _  = strconv.ParseInt(c.PostForm("ts"), 10, 64)
	} else {
		RetJson("500", "Illegal requests", "", c)
		return
	}

	exp, _ := strconv.ParseInt(config.API_EXPIRY, 10, 64)

	// 验证过期时间
	if ts > GetTimeUnix() || GetTimeUnix() - ts >= exp {
		RetJson("500", "Ts Error", "", c)
		return
	}

	// 验证签名
	if sn == "" || sn != CreateSign(req) {
		RetJson("500", "Sn Error", "", c)
		return
	}
}
```

生成签名的方法：

```
// 生成签名
func CreateSign(params url.Values) string {
	var key []string
	var str = ""
	for k := range params {
		if k != "sn" {
			key = append(key, k)
		}
	}
	sort.Strings(key)
	for i := 0; i < len(key); i++ {
		if i == 0 {
			str = fmt.Sprintf("%v=%v", key[i], params.Get(key[i]))
		} else {
			str = str + fmt.Sprintf("&%v=%v", key[i], params.Get(key[i]))
		}
	}
	// 自定义签名算法
	sign := MD5(MD5(str) + MD5(config.APP_NAME + config.APP_SECRET))
	return sign
}
```

获取参数的方法：

```
// 获取 Get 参数
name := c.Query("name")
price := c.DefaultQuery("price", "100")

// 获取 Post 参数
name := c.PostForm("name")
price := c.DefaultPostForm("price", "100")

// 获取 Get 所有参数
ReqGet = c.Request.URL.Query()

//获取 Post 所有参数
ReqPost = c.Request.PostForm
```

v1 业务代码：

```
package v1

import "github.com/gin-gonic/gin"

func AddProduct(c *gin.Context)  {
	// 获取 Get 参数
	name  := c.Query("name")
	price := c.DefaultQuery("price", "100")

	c.JSON(200, gin.H{
		"v1"    : "AddProduct",
		"name"  : name,
		"price" : price,
	})
}
```

v2 业务代码：

```
package v2

import (
	"github.com/gin-gonic/gin"
)

func AddProduct(c *gin.Context)  {
	// 获取 Get 参数
	name  := c.Query("name")
	price := c.DefaultQuery("price", "100")

	c.JSON(200, gin.H{
		"v1"    : "AddProduct",
		"name"  : name,
		"price" : price,
	})
}

```

接下来，直接看效果吧。

访问 v1 接口：

![](https://github.com/xinliangnote/Go/blob/master/01-Gin框架/images/02-路由配置/2_go_1.png)

访问后，直接返回数据，不走签名验证。

访问 v2 接口：

![](https://github.com/xinliangnote/Go/blob/master/01-Gin框架/images/02-路由配置/2_go_2.png)

进入了这段验证：

```
// 验证过期时间
if ts > GetTimeUnix() || GetTimeUnix() - ts >= exp {
	RetJson("500", "Ts Error", "", c)
	return
}
```

修改为合法的时间戳后：

![](https://github.com/xinliangnote/Go/blob/master/01-Gin框架/images/02-路由配置/2_go_3.png)

进入了这段验证：

```
// 验证签名
if sn == "" || sn != CreateSign(req) {
	RetJson("500", "Sn Error", "", c)
	return
}
```


package config

const (
	PORT       = ":8080"
	APP_NAME   = "ginDemo"
	APP_SECRET = "6YJSuc50uJ18zj45"
	API_EXPIRY = "120"
)
```

引入 config 包，直接 `config.xx` 即可。

## 源码

**下载源码后，请先执行 `dep ensure` 下载依赖包！**

[查看源码](https://github.com/xinliangnote/Go/blob/master/01-Gin框架/codes/02-路由配置)
