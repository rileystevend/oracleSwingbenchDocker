#use java docker for base
FROM frolvlad/alpine-oraclejdk8:cleaned

# update base image and download required glibc libraries
RUN apk update && apk add libaio libnsl && \
    ln -s /usr/lib/libnsl.so.2 /usr/lib/libnsl.so.1

#install git and cleanup cache
RUN apk add --update \
    git \
    maven \
   && rm -rf /var/cache/apk/*



# get oracle instant client from bumpx git repo
ENV CLIENT_FILENAME instantclient-basic-linux.x64-12.1.0.1.0.zip

# set working directory
WORKDIR /opt/oracle/lib

# download instant client zip file from git repo
ADD https://github.com/bumpx/oracle-instantclient/raw/master/${CLIENT_FILENAME} .

# unzip required libs, unzip instant client and create sim links
RUN LIBS="*/libociei.so */libons.so */libnnz12.so */libclntshcore.so.12.1 */libclntsh.so.12.1" && \
    unzip ${CLIENT_FILENAME} ${LIBS} && \
    for lib in ${LIBS}; do mv ${lib} /usr/lib; done && \
    ln -s /usr/lib/libclntsh.so.12.1 /usr/lib/libclntsh.so && \
    rm ${CLIENT_FILENAME}

# download and unzip Swingbench
# RUN git clone https://github.com/kbhanush/ATPDocker
ENV SB_FILENAME swingbenchlatest.zip
ADD http://www.dominicgiles.com/swingbench/${SB_FILENAME} .
RUN unzip ${SB_FILENAME}

RUN mkdir wallet_STEVENATP
COPY ./wallet_STEVENATP ./wallet_STEVENATP

# install a SB workload schema into the ATP instance
RUN cd /opt/oracle/lib/swingbenchlatest/bin
RUN ./oewizard -cf ~/wallet_STEVENATP.zip \
           -cs stevenatp_medium \
           -ts DATA \
           -dbap Vicfirth#13! \
           -dba admin \
           -u soe \
           -p Vicfirth#13! \
           -async_off \
           -scale 5 \
           -hashpart \
           -create \
           -cl \
           -v

# run a workload 
RUN sed -i -e 's/<LogonGroupCount>1<\/LogonGroupCount>/<LogonGroupCount>5<\/LogonGroupCount>/' \
       -e 's/<LogonDelay>0<\/LogonDelay>/<LogonDelay>300<\/LogonDelay>/' \
       -e 's/<WaitTillAllLogon>true<\/WaitTillAllLogon>/<WaitTillAllLogon>false<\/WaitTillAllLogon>/' \
       ../configs/SOE_Server_Side_V2.xml

RUN ./charbench -c ../configs/SOE_Server_Side_V2.xml \
            -cf ~/wallet_STEVENATP.zip \
            -cs stevenatp_low \
            -u soe \
            -p Vicfirth#13! \
            -v users,tpm,tps,vresp \
            -intermin 0 \
            -intermax 0 \
            -min 0 \
            -max 0 \
            -uc 128 \
            -di SQ,WQ,WA \
            -rt 0:0.30
#set env variables
ENV ORACLE_BASE /opt/oracle/lib/instantclient_12_1
ENV LD_LIBRARY_PATH /opt/oracle/lib/instantclient_12_1
ENV TNS_ADMIN /opt/oracle/lib/wallet_STEVENATP
ENV ORACLE_HOME /opt/oracle/lib/instantclient_12_1
ENV PATH /opt/oracle/lib/instantclient_12_1:$PATH
# ENV PATH /opt/oracle/lib/instantclient_12_1:/opt/oracle/lib/wallet_STEVENATP:/opt/oracle/lib/ATPDocker/aone:/opt/oracle/lib/ATPDocker/aone/node_modules:$PATH

# RUN cd /opt/oracle/lib/ATPDocker/aone && \
# 	npm install oracledb
EXPOSE 3050
CMD ["/opt/oracle/lib/swingbenchlatest/bin" ]
