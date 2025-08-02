# manual script, not reproducible
BUCKET="583168578067-lambda-layers"
ARCHIVE="psycopg-py3.12-layer.zip"

docker build -t psycopg-zip .

# run the container with the given name psycopg-zip
docker run --name psycopg-zip --entrypoint "/bin/sh" -d -it psycopg-zip

# get the docker container ID
docker ps -aqf "name=psycopg-zip"

# copy the zip package out to local
docker cp $(docker ps -aqf "name=psycopg-zip"):/app/package/$ARCHIVE .

docker rm --force psycopg-zip

aws s3 cp $ARCHIVE "s3://${BUCKET}/${ARCHIVE}" --profile "personal"  # todo replace to correct profile

rm $ARCHIVE
