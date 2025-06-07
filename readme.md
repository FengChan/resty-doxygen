### 1. 镜像导入docker
```
docker 分支下有镜像文件:  resty-doxygen.tar.gz
cd 项目根目录
gunzip resty-doxygen.tar.gz  
得到 resty-doxygen.tar 文件
docker import  resty-doxygen.tar resty-doxygen


```

### 2. 运行docker
```
docker-compose up -d
```

### 3.更新代码
```
关键代码在 lua_scripts 文件夹下，增加了宿主机映射

使用 git pull

更新代码后执行docker-compose up -d
```

### 4. 其他指令
```

git pull && docker build -t resty-doxygen . && docker-compose up -d

docker logs -f --tail 10 html-nginx

git pull 
docker-compose build 
docker-compose up -d

docker exec -it html-nginx env LANG=C.UTF-8 /bin/bash

docker save resty-doxygen | gzip > resty-doxygen.tar.gz

```






