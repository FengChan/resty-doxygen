git pull && docker-compose build && docker-compose up


docker build -t restydoxygen_resty .

git pull 
docker-compose build 
docker-compose up -d

docker exec -it restydoxygen_resty_1 env LANG=C.UTF-8 /bin/bash



http://xxxxxxxx:8080/output/index.html


http://xxxxxxxx:8080/generate?repo=https://github.com/mrwid/Snake.git