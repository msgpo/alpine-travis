# {{{ -- meta

HOSTARCH  := x86_64# on travis.ci
ARCH      := $(shell uname -m | sed "s_armv7l_armhf_")# armhf/x86_64 auto-detect on build and run
OPSYS     := alpine
SHCOMMAND := /bin/bash
SVCNAME   := travis
USERNAME  := woahbase

PUID       := $(shell id -u)
PGID       := $(shell id -g)# gid 100(users) usually pre exists

DOCKERSRC := $(OPSYS)-ruby#
DOCKEREPO := $(OPSYS)-$(SVCNAME)
IMAGETAG  := $(USERNAME)/$(DOCKEREPO):$(ARCH)

# -- }}}

# {{{ -- flags

BUILDFLAGS := --rm --force-rm --compress -f $(CURDIR)/Dockerfile_$(ARCH) -t $(IMAGETAG) \
	--build-arg ARCH=$(ARCH) \
	--build-arg DOCKERSRC=$(DOCKERSRC) \
	--build-arg USERNAME=$(USERNAME) \
	--label org.label-schema.build-date=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ") \
	--label org.label-schema.name=$(DOCKEREPO) \
	--label org.label-schema.schema-version="1.0" \
	--label org.label-schema.vcs-ref=$(shell git rev-parse --short HEAD) \
	--label org.label-schema.vcs-url="https://github.com/$(USERNAME)/$(DOCKEREPO)" \
	--label org.label-schema.vendor=$(USERNAME)

CACHEFLAGS := --no-cache=true --pull
MOUNTFLAGS := -v $(CURDIR):/home/alpine/project # -v $(CURDIR)/data:/home/alpine/.travis
NAMEFLAGS  := --name docker_$(SVCNAME) --hostname $(SVCNAME)
OTHERFLAGS := -v /etc/hosts:/etc/hosts:ro -v /etc/localtime:/etc/localtime:ro # -e TZ=Asia/Kolkata
PORTFLAGS  := #
PROXYFLAGS := --build-arg http_proxy=$(http_proxy) --build-arg https_proxy=$(https_proxy) --build-arg no_proxy=$(no_proxy)

RUNFLAGS   := -e PGID=$(PGID) -e PUID=$(PUID) -c 256 -m 256m

# -- }}}

# {{{ -- docker targets

all : run

build :
	echo "Building for $(ARCH) from $(HOSTARCH)";
	if [ "$(ARCH)" != "$(HOSTARCH)" ]; then make regbinfmt ; fi;
	docker build $(BUILDFLAGS) $(CACHEFLAGS) $(PROXYFLAGS) .

clean :
	docker images | awk '(NR>1) && ($$2!~/none/) {print $$1":"$$2}' | grep "$(USERNAME)/$(DOCKEREPO)" | xargs -n1 docker rmi

logs :
	docker logs -f docker_$(SVCNAME)

pull :
	docker pull $(IMAGETAG)

push :
	docker push $(IMAGETAG)

restart :
	docker ps -a | grep 'docker_$(SVCNAME)' -q && docker restart docker_$(SVCNAME) || echo "Service not running.";

rm : stop
	docker rm -f docker_$(SVCNAME)

run :
	docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) $(PORTFLAGS) $(MOUNTFLAGS) $(OTHERFLAGS) $(IMAGETAG)

rshell :
	docker exec -u root -it docker_$(SVCNAME) $(SHCOMMAND)

shell :
	docker exec -it docker_$(SVCNAME) $(SHCOMMAND)

stop :
	docker stop -t 2 docker_$(SVCNAME)

test :
	docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) $(PORTFLAGS) $(MOUNTFLAGS) $(OTHERFLAGS) $(IMAGETAG) '--version'

# -- }}}

# {{{ -- other targets

regbinfmt :
	docker run --rm --privileged multiarch/qemu-user-static:register --reset

# -- }}}
