# Docker Images

### Build syntax

1. Laravel
```shell
docker buildx build --platform linux/amd64,linux/arm64 -t puncoz/laravel:7.4 --push -f ./laravel/laravel-7.4.Dockerfile .

docker buildx build --platform linux/amd64,linux/arm64 -t puncoz/laravel:8.1 --push -f ./laravel/laravel-8.1.Dockerfile .
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
