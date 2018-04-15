FROM huggla/openjre-alpine

ENV REV_LINUX_USER="tomcat"
ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
ENV TOMCAT_NATIVE_LIBDIR $CATALINA_HOME/native-jni-lib
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR
ENV TOMCAT_MAJOR 9
ENV TOMCAT_VERSION 9.0.7
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk
ENV TOMCAT_TGZ_URLS \
# https://issues.apache.org/jira/browse/INFRA-8753?focusedCommentId=14735394#comment-14735394
	https://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
# if the version is outdated, we might have to pull from the dist/archive :/
	https://www-us.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
	https://www.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
	https://archive.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz

#COPY ./bin ${BIN_DIR}

# Image-specific RUN commands.
# ---------------------------------------------------------------------
RUN mkdir -p "$CATALINA_HOME" \
# && apk add --no-cache --virtual .fetch-deps gnupg ca-certificates openssl \
# && export GNUPGHOME="$(mktemp -d)" \
# && for key in $GPG_KEYS; do gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; done \
 && echo "hej" \
# && tmpDir="$(mktemp -d)" \
 && cd "$CATALINA_HOME" \
 && for url in $TOMCAT_TGZ_URLS; do if wget -O tomcat.tar.gz "$url"; then success=1 && break; else success=0; fi; done \
# && if [ "$success" == 1 ]; then echo "$TOMCAT_SHA1 *tomcat.tar.gz" | sha1sum -c -; fi \
# && for url in $TOMCAT_ASC_URLS; do if wget -O tomcat.tar.gz.asc "$url"; then success=1 && break; else success=0; fi; done \
# && if [ "$success" == 1 ]; then echo "$url" && ls -la && cat tomcat.tar.gz.asc && gpg --batch --verify tomcat.tar.gz.asc tomcat.tar.gz; fi \
 && tar -xvf tomcat.tar.gz --strip-components=1 \
 && rm bin/*.bat \
 && rm tomcat.tar.gz* \
# && rm -rf "$GNUPGHOME" \
 && nativeBuildDir="$(mktemp -d)" \
 && tar -xvf bin/tomcat-native.tar.gz -C "$nativeBuildDir" --strip-components=1 \
 && rm bin/tomcat-native.tar.gz \
 && cd "$nativeBuildDir/native" \
# && rm -rf "$tmpDir" \
 && apk add --no-cache --virtual .native-build-deps apr-dev coreutils dpkg-dev dpkg gcc libc-dev make openjdk$JAVA_MAJOR openssl-dev \
 && export CATALINA_HOME="$PWD" \
 && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
 && echo "$gnuArch" \
 && ./configure --build="$gnuArch" --libdir="$TOMCAT_NATIVE_LIBDIR" --prefix="$CATALINA_HOME" --with-apr="$(which apr-1-config)" --with-java-home="$JAVA_HOME" --with-ssl=yes \
 && make -j "$(nproc)" \
 && make install \
 && rm -rf "$nativeBuildDir" \
 && export runDeps="$(scanelf --needed --nobanner --format '%n#p' --recursive "$TOMCAT_NATIVE_LIBDIR" | tr ',' '\n' | sort -u | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }')" \
 && apk add --virtual .tomcat-native-rundeps $runDeps \
 && apk del .native-build-deps \
 && ln /usr/local/tomcat/*.sh /usr/local/bin/

ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk/jre

# verify Tomcat Native is working properly
RUN nativeLines="$(catalina.sh configtest 2>&1)" \
 && nativeLines="$(echo "$nativeLines" | grep 'Apache Tomcat Native')" \
 && nativeLines="$(echo "$nativeLines" | sort -u)" \
 && echo "$nativeLines"
# && if ! echo "$nativeLines" | grep 'INFO: Loaded APR based Apache Tomcat Native library' >&2; then echo >&2 "$nativeLines"; exit 1; fi

USER sudoer
