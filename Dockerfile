FROM huggla/openjre-alpine

ENV REV_LINUX_USER="tomcat" \
    CATALINA_HOME="/usr/local/tomcat" \
#   PATH="$CATALINA_HOME/bin:$PATH" \
    TOMCAT_NATIVE_LIBDIR="$CATALINA_HOME/native-jni-lib" \
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR" \
    TOMCAT_MAJOR="9" \
    TOMCAT_VERSION="9.0.7" \
    JAVA_HOME="/usr/lib/jvm/java-1.8-openjdk"

# Image-specific RUN commands.
# ---------------------------------------------------------------------
RUN mkdir -p "$CATALINA_HOME" \
 && wget -O "$CATALINA_HOME/tomcat.tar.gz" "https://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz" \
 && tar -C "$CATALINA_HOME" -xvf tomcat.tar.gz --strip-components=1 \
 && rm "$CATALINA_HOME/bin/"*.bat \
 && rm "$CATALINA_HOME/tomcat.tar.gz"* \
 && nativeBuildDir="$(mktemp -d)" \
 && tar -xvf bin/tomcat-native.tar.gz -C "$nativeBuildDir" --strip-components=1 \
 && rm "$CATALINA_HOME/bin/"*.gz \
# && rm bin/tomcat-native.tar.gz \
 && cd "$nativeBuildDir/native" \
 && apk add --no-cache --virtual .native-build-deps apr-dev coreutils dpkg-dev dpkg gcc libc-dev make openjdk$JAVA_MAJOR openssl-dev \
 && export CATALINA_HOME="$PWD" \
 && echo "$CATALINA_HOME" \
 && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
 && echo "$gnuArch" \
 && ./configure --build="$gnuArch" --libdir="$TOMCAT_NATIVE_LIBDIR" --prefix="$CATALINA_HOME" --with-apr="$(which apr-1-config)" --with-java-home="$JAVA_HOME" --with-ssl=yes \
 && make -j "$(nproc)" \
 && make install \
 && rm -rf "$nativeBuildDir" \
 && export runDeps="$(scanelf --needed --nobanner --format '%n#p' --recursive "$TOMCAT_NATIVE_LIBDIR" | tr ',' '\n' | sort -u | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }')" \
 && apk add --virtual .tomcat-native-rundeps $runDeps \
 && apk del .native-build-deps \
 && ln /usr/local/tomcat/bin/*.sh /usr/local/bin/

ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk/jre

# verify Tomcat Native is working properly
RUN nativeLines="$(catalina.sh configtest 2>&1)" \
 && nativeLines="$(echo "$nativeLines" | grep 'Apache Tomcat Native')" \
 && nativeLines="$(echo "$nativeLines" | sort -u)" \
 && echo "$nativeLines" \
 && if ! echo "$nativeLines" | grep 'INFO: Loaded APR based Apache Tomcat Native library' >&2; then echo >&2 "$nativeLines"; exit 1; fi

USER sudoer
