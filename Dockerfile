FROM huggla/openjre-alpine

# Image-specific BEV_NAME variable.
# ---------------------------------------------------------------------
ENV BEV_NAME="openjre"
# ---------------------------------------------------------------------

ENV BIN_DIR="/usr/local/bin" \
    SUDOERS_DIR="/etc/sudoers.d" \
    CONFIG_DIR="/etc/$BEV_NAME" \
    LANG="en_US.UTF-8"
ENV BUILDTIME_ENVIRONMENT="$BIN_DIR/buildtime_environment" \
    RUNTIME_ENVIRONMENT="$BIN_DIR/runtime_environment"

# Image-specific buildtime environment variables.
# ---------------------------------------------------------------------
ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
ENV TOMCAT_NATIVE_LIBDIR $CATALINA_HOME/native-jni-lib
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR

# see https://www.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/KEYS
# see also "update.sh" (https://github.com/docker-library/tomcat/blob/master/update.sh)
ENV GPG_KEYS 05AB33110949707C93A279E3D3EFE6B686867BA6 07E48665A34DCAFAE522E5E6266191C37C037D42 47309207D818FFD8DCD3F83F1931D684307A10A5 541FBE7D8F78B25E055DDEE13C370389288584E7 61B832AC2F1C5A90F0F9B00A1C506407564C17A3 79F7026C690BAA50B92CD8B66A3AD3F4F22C4FED 9BA44C2621385CB966EBA586F72C284D731FABEE A27677289986DB50844682F8ACB77FC2E86E29AC A9C5DF4D22E99998D9875A5110C01C5A2F6059E7 DCFD35E0BF8CA7344752DE8B6FB21E8933C60243 F3A04C595DB5B6A5F1ECA43E3B7BBB100D811BBE F7DA48BB64BCB84ECBA7EE6935CD23C10D498E23

ENV TOMCAT_MAJOR 9
ENV TOMCAT_VERSION 9.0.7
ENV TOMCAT_SHA1 488c237dbd92778c356de7f9ff3a59da19a5b3ef

ENV TOMCAT_TGZ_URLS \
# https://issues.apache.org/jira/browse/INFRA-8753?focusedCommentId=14735394#comment-14735394
	https://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
# if the version is outdated, we might have to pull from the dist/archive :/
	https://www-us.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
	https://www.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
	https://archive.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz

ENV TOMCAT_ASC_URLS \
	https://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz.asc \
# not all the mirrors actually carry the .asc files :'(
	https://www-us.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz.asc \
	https://www.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz.asc \
	https://archive.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz.asc

# ---------------------------------------------------------------------

COPY ./bin ${BIN_DIR}

# Image-specific COPY commands.
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------
    
RUN env | grep "^BEV_" > "$BUILDTIME_ENVIRONMENT" \
 && addgroup -S sudoer \
 && adduser -D -S -H -s /bin/false -u 100 -G sudoer sudoer \
 && (getent group $BEV_NAME || addgroup -S $BEV_NAME) \
 && (getent passwd $BEV_NAME || adduser -D -S -H -s /bin/false -u 101 -G $BEV_NAME $BEV_NAME) \
 && touch "$RUNTIME_ENVIRONMENT" \
 && apk add --no-cache sudo \
 && echo 'Defaults lecture="never"' > "$SUDOERS_DIR/docker1" \
 && echo "Defaults secure_path = \"$BIN_DIR\"" >> "$SUDOERS_DIR/docker1" \
 && echo 'Defaults env_keep = "REV_*"' > "$SUDOERS_DIR/docker2" \
 && echo "sudoer ALL=(root) NOPASSWD: $BIN_DIR/start" >> "$SUDOERS_DIR/docker2"

# Image-specific RUN commands.
# ---------------------------------------------------------------------
RUN mkdir -p "$CATALINA_HOME" \
 && cd "$CATALINA_HOME" \
 && apk add --no-cache --virtual .fetch-deps gnupg ca-certificates openssl \
 && export GNUPGHOME="$(mktemp -d)" \
 && for key in $GPG_KEYS; do gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; done \
 && echo "hej" \
 && for url in $TOMCAT_TGZ_URLS; do if wget -O tomcat.tar.gz "$url"; then success=1 && break; else success=0; fi; done \
 && if [ "$success" == 1 ]; then echo "$TOMCAT_SHA1 *tomcat.tar.gz" | sha1sum -c -; fi \
 && for url in $TOMCAT_ASC_URLS; do if wget -O tomcat.tar.gz.asc "$url"; then success=1 && break; else success=0; fi; done \
 && if [ "$success" == 1 ]; then echo "$url" && ls -la && cat tomcat.tar.gz.asc && gpg --batch --verify tomcat.tar.gz.asc tomcat.tar.gz; fi \
 && tar -xvf tomcat.tar.gz --strip-components=1 \
 && rm bin/*.bat \
 && rm tomcat.tar.gz* \
 && rm -rf "$GNUPGHOME" \
 && nativeBuildDir="$(mktemp -d)" \
 && tar -xvf bin/tomcat-native.tar.gz -C "$nativeBuildDir" --strip-components=1 \
 && apk add --no-cache --virtual .native-build-deps apr-dev coreutils dpkg-dev dpkg gcc libc-dev make "openjdk${JAVA_VERSION%%[-~bu]*}"="$JAVA_ALPINE_VERSION" openssl-dev \
 && export CATALINA_HOME="$PWD" \
 && cd "$nativeBuildDir/native" \
 && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
 && ./configure --build="$gnuArch" --libdir="$TOMCAT_NATIVE_LIBDIR" --prefix="$CATALINA_HOME" --with-apr="$(which apr-1-config)" --with-java-home="$(docker-java-home)" --with-ssl=yes \
 && make -j "$(nproc)" \
 && make install \
 && rm -rf "$nativeBuildDir" \
 && rm bin/tomcat-native.tar.gz \
 && runDeps="$(scanelf --needed --nobanner --format '%n#p' --recursive "$TOMCAT_NATIVE_LIBDIR" | tr ',' '\n' | sort -u | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }')" \
 && apk add --virtual .tomcat-native-rundeps $runDeps \
 && apk del .fetch-deps .native-build-deps \

# verify Tomcat Native is working properly
RUN nativeLines="$(catalina.sh configtest 2>&1)" \
 && nativeLines="$(echo "$nativeLines" | grep 'Apache Tomcat Native')" \
 && nativeLines="$(echo "$nativeLines" | sort -u)" \
 && if ! echo "$nativeLines" | grep 'INFO: Loaded APR based Apache Tomcat Native library' >&2; then echo >&2 "$nativeLines"; exit 1; fi

# ---------------------------------------------------------------------
    
RUN chmod go= /bin /sbin /usr/bin /usr/sbin \
 && chown root:$BEV_NAME "$BIN_DIR/"* \
 && chmod u=rx,g=rx,o= "$BIN_DIR/"* \
 && ln /usr/bin/sudo "$BIN_DIR/sudo" \
 && chown root:sudoer "$BIN_DIR/sudo" "$BUILDTIME_ENVIRONMENT" "$RUNTIME_ENVIRONMENT" \
 && chown root:root "$BIN_DIR/start"* \
 && chmod u+s "$BIN_DIR/sudo" \
 && chmod u=rw,g=w,o= "$RUNTIME_ENVIRONMENT" \
 && chmod u=rw,go= "$BUILDTIME_ENVIRONMENT" "$SUDOERS_DIR/docker"*
 
USER sudoer

# Image-specific runtime environment variables.
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------

#CMD ["sudo","start"]
