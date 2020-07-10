docker build -t odbc:1.0.0 .

docker tag odbc:1.0.0 harbor.homelab.brianhenzelmann.com/windows/odbc:1.0.0

docker push harbor.homelab.brianhenzelmann.com/windows/odbc:1.0.0
