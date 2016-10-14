FROM gibdfrcu/base:alpine

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH


ENV GPG_KEY="97FC712E4C024BBEA48A61ED3A5CA953F73C700D" \
	PYTHON_VERSION="3.5.2" \
	PYTHON_PIP_VERSION="8.1.2"

RUN set -ex && \
	apk add --no-cache --virtual .fetch-deps \
		openssl \
		tar \
		xz && \
	\
	wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" && \
	wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" && \
	export GNUPGHOME="$(mktemp -d)" && \
	gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" && \
	gpg --batch --verify python.tar.xz.asc python.tar.xz && \
	rm -r "$GNUPGHOME" python.tar.xz.asc && \
	mkdir -p /usr/src/python && \
	tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz && \
	rm python.tar.xz && \
	\
	apk add --no-cache --virtual .build-deps  \
		bzip2-dev \
		gcc \
		libc-dev \
		linux-headers \
		make \
		ncurses-dev \
		openssl \
		openssl-dev \
		pax-utils \
		readline-dev \
		sqlite-dev \
		tcl-dev \
		tk \
		tk-dev \
		xz-dev \
		zlib-dev && \
		\
	apk del .fetch-deps && \
	\
	cd /usr/src/python && \
	./configure \
		--enable-loadable-sqlite-extensions \
		--enable-shared && \
	make -j$(getconf _NPROCESSORS_ONLN) && \
	make install && \
	\
	if [ ! -e /usr/local/bin/pip3 ]; then : && \
		wget -O /tmp/get-pip.py 'https://bootstrap.pypa.io/get-pip.py' && \
		python3 /tmp/get-pip.py "pip==$PYTHON_PIP_VERSION" && \
		rm /tmp/get-pip.py \
	; fi && \
	\
	pip3 install --no-cache-dir --upgrade --force-reinstall "pip==$PYTHON_PIP_VERSION" && \
	\
	[ "$(pip list |tac|tac| awk -F '[ ()]+' '$1 == "pip" { print $2; exit }')" = "$PYTHON_PIP_VERSION" ] && \
	\
	find /usr/local -depth \
		\( \
			\( -type d -a -name test -o -name tests \) \
			-o \
			\( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		\) -exec rm -rf '{}' + && \
	runDeps="$( \
		scanelf --needed --nobanner --recursive /usr/local \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" && \
	apk add --virtual .python-rundeps $runDeps && \
	apk del .build-deps && \
	rm -rf /usr/src/python ~/.cache && \
	\
	cd /usr/local/bin && \
	{ [ -e easy_install ] || ln -s easy_install-* easy_install; } && \
	ln -s idle3 idle && \
	ln -s pydoc3 pydoc && \
	ln -s python3 python && \
	ln -s python3-config python-config

CMD ["python3"]