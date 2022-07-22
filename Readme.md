# Docker Images

### Build syntax

1. Laravel
```shell
docker build -t puncoz/laravel:7.4 -f ./laravel/laravel-7.4.Dockerfile .
```

### Publishing to docker hub

1. Login
```shell
docker login
```

2. Push
```shell
docker push puncoz/laravel:7.4
```
