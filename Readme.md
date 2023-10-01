# Docker Images

### Build syntax

1. Laravel
```shell
docker buildx build --platform linux/amd64,linux/arm64 -t puncoz/laravel:7.4 --push -f ./laravel/laravel-7.4.Dockerfile .

docker buildx build --platform linux/amd64,linux/arm64 -t puncoz/laravel:8.1 --push -f ./laravel/laravel-8.1.Dockerfile .

# 8.2
docker buildx create --use --platform=linux/amd64,linux/arm64 --name multi-platform-builder
docker buildx inspect --bootstrap
docker buildx build --platform=linux/amd64,linux/arm64  -t puncoz/laravel:8.2 --push -f ./laravel/laravel-8.2.Dockerfile .
```

###### Updated docker build command
https://unix.stackexchange.com/questions/748633/error-multiple-platforms-feature-is-currently-not-supported-for-docker-driver
Now you have to make builder with explicit platforms in `docker buildx create` command


### Publishing to docker hub

1. Login
```shell
docker login
```

2. Push
```shell
docker push puncoz/laravel:7.4
```
