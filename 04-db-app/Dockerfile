FROM microsoft/iis
SHELL ["powershell", "-command"]
EXPOSE 80

# Install ASP
RUN Install-WindowsFeature Web-ASP; 

# Clean out default site
RUN powershell -NoProfile -Command Remove-Item -Recurse C:\inetpub\wwwroot\*

# Install the ODBC Driver for SQL Server
RUN md c:/msi;
RUN Invoke-WebRequest 'https://download.microsoft.com/download/1/E/7/1E7B1181-3974-4B29-9A47-CC857B271AA2/English/X64/msodbcsql.msi' -OutFile c:/msi/msodbcsql.msi; 
RUN ["cmd", "/S", "/C", "c:\\windows\\syswow64\\msiexec", "/i", "c:\\msi\\msodbcsql.msi", "IACCEPTMSODBCSQLLICENSETERMS=YES", "ADDLOCAL=ALL", "/qn"];

# Add the DSN
RUN Add-OdbcDsn -Name "tkgitest" -DriverName "\"ODBC Driver 13 For SQL Server\""  -DsnType "System"  -SetPropertyValue @("\"Server=mssql\"", "\"Trusted_Connection=No\"");

#Change directory
WORKDIR /inetpub/wwwroot
#Copy the app artifact in (assumes you are in the publish folder when building docker image)
COPY wwwroot/* .
