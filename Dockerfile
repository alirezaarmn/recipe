FROM python:3.9-alpine3.13
LABEL maintainer="alirezaarmn.me"

# when you run python in docker, it tells python to not buffer the output. 
# output will be printed directly to the console which prevents any delays of messages and can see the logs immediately 
ENV PYTHONUNBUFFERED 1 

COPY ./requirements.txt /tmp/requirements.txt
COPY ./requirements.dev.txt /tmp/requirements.dev.txt
COPY ./app /app
WORKDIR /app
EXPOSE 8000

# running all command in one RUN doesn't create so many layers on our system, it's better to run all command in one shoot
ARG DEV=false
RUN python -m venv /py && \
    /py/bin/pip install --upgrade pip && \
    # add postgres package 
    apk add --update --no-cache postgresql-client && \ 
    # --vertual sets a virtual dependency package, and groups the package we install into this name and then we can remove those packages later on inside 
    # docker to make sure the docker is lightwight
    apk add --update --no-cache --virtual .tmp-build-deps \
    # these three packages will install inside the virtual that we just mentioned above
    build-base postgresql-dev musl-dev && \
    /py/bin/pip install -r /tmp/requirements.txt && \
    if [ $DEV = "true" ]; \
    then /py/bin/pip install -r /tmp/requirements.dev.txt ; \
    fi && \
    # remove the tmp content to get rid of unwanted files and make the image lightweight as much as possible
    rm -rf /tmp && \
    # remove those packages that we install up there on line 24
    apk del .tmp-build-deps && \
    # adding new user inside image, beacause it's practice not to use the root user
    # if don't specify this, the only user inside image will be root user
    adduser -D -H django-user

ENV PATH="/py/bin:$PATH"
# specify the user we're switching to. so until we run this line, everythin else is being done as the root user 
USER django-user