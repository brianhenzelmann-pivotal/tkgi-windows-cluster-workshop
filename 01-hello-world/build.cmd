docker build -t hello-world:1.0.0 .

docker tag hello-world:1.0.0 harbor.homelab.brianhenzelmann.com/windows/hello-world:1.0.0

docker push harbor.homelab.brianhenzelmann.com/windows/hello-world:1.0.0
