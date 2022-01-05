#!/bin/sh

# Collaboration: Open Threat Research (OTR)
# Author: Roberto Rodriguez (@Cyb3rWard0g)
# Reference: 
# https://linuxize.com/post/how-to-install-tomcat-8-5-on-ubuntu-18-04/
# https://www.digitalocean.com/community/tutorials/install-tomcat-9-ubuntu-1804
# License: MIT

# We need to use sudo for commands, if not running as root
SUDO=''
if [ "$EUID" != 0 ]; then
    SUDO='sudo'
fi

# Setting Variables
ARCHITECTURE=$(uname -m)
TOMCAT_HOME=/opt/tomcat

# Set package to latest GitHub release:
# Get distribution list
LSB_DIST="$(. /etc/os-release && echo "$ID")"
LSB_DIST="$(echo "$LSB_DIST" | tr '[:upper:]' '[:lower:]')"

# Get package manager and set commands
if [ "${ARCHITECTURE}" = 'x86_64' ]; then
  case "$LSB_DIST" in
    ubuntu)
      if [ -z "$DIST_VERSION" ] && [ -r /etc/lsb-release ]; then
        DIST_VERSION="$(. /etc/lsb-release && echo "$DISTRIB_RELEASE")"
      fi
      if [ -z "$DIST_VERSION" ] && [ -r /etc/os-release ]; then
        DIST_VERSION="$(. /etc/os-release && echo "$VERSION_ID")"
      fi
      case "$DIST_VERSION" in
        18.04 | 20.04 | 21.04)
          eval $SUDO apt update -y
          eval $SUDO apt install -y openjdk-8-jre-headless unzip wget
        ;;
        *)
          ERROR=$?
          if [ $ERROR -ne 0 ]; then
            echo "[!] $LSB_DIST version $DIST_VERSION not supported!"
          fi
      esac
      ;;
    debian)
      if [ -z "$DIST_VERSION" ] && [ -r /etc/os-release ]; then
        DIST_VERSION="$(. /etc/os-release && echo "$VERSION_ID")"
      fi
      case "$DIST_VERSION" in
        9 | 10 | 11)
          eval $SUDO apt update -y
          eval $SUDO apt install -y openjdk-8-jre-headless unzip wget
        ;;
        *)
          ERROR=$?
          if [ $ERROR -ne 0 ]; then
            echo "[!] $LSB_DIST version $DIST_VERSION not supported!"
          fi
      esac
      ;;
    centos | rhel)
      pkgMgr="yum install -y"
      if [ -z "$DIST_VERSION" ] && [ -r /etc/os-release ]; then
        DIST_VERSION="$(. /etc/os-release && echo "$VERSION_ID")"
      fi
      case "$DIST_VERSION" in
        7* | 8*)
          eval $SUDO yum update -y
          eval $SUDO yum install -y java-1.8.0-openjdk-devel unzip wget
        ;;
        *)
          ERROR=$?
          if [ $ERROR -ne 0 ]; then
            echo "[!] $LSB_DIST version $DIST_VERSION not supported!"
          fi
      esac
      ;;
    *)
      if [ -x "$(command -v lsb_release)" ]; then
        DIST_VERSION="$(lsb_release --release | cut -f2)"
      fi
      if [ -z "$DIST_VERSION" ] && [ -r /etc/os-release ]; then
        DIST_VERSION="$(. /etc/os-release && echo "$VERSION_ID")"
      fi
      ;;
    esac
    ERROR=$?
    if [ $ERROR -ne 0 ]; then
      echoerror "Could not verify distribution or version of the OS (Error Code: $ERROR)."
    fi
    echo "You're using $LSB_DIST version $DIST_VERSION"

  # Create Tomcat user
  echo "Creating Tomcat user..."
  eval $SUDO useradd -m -U -d ${TOMCAT_HOME} -s /bin/false tomcat

  # Download and configure Tomcat
  echo "Downloading Tomcat.."
  eval $SUDO mkdir -pv ${TOMCAT_HOME}/logs
  eval $SUDO wget -qO- https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.3/bin/apache-tomcat-8.5.3.tar.gz | eval $SUDO tar xvz -C ${TOMCAT_HOME}/ --strip-components=1

  echo "Creating setenv.sh script.."
  echo "
#!/bin/sh

# Collaboration: Open Threat Research (OTR)
# Author: Roberto Rodriguez (@Cyb3rWard0g)
# License: MIT

##### JAVA OPTIONS ####
export JAVA_OPTS=\"$JAVA_OPTS -Dcom.sun.jndi.ldap.object.trustURLCodebase=true\"
export JAVA_OPTS=\"$JAVA_OPTS -Dlog4j2.formatMsgNoLookups=false\"
export JAVA_OPTS=\"$JAVA_OPTS -Dlog4j2.disableThreadContext=false\"

# Log4j 2.15
# Fixes:
# https://issues.apache.org/jira/browse/LOG4J2-3201 - Limit the protocols JNDI can use by default. Limit the servers and classes that can be accessed via LDAP.

# Log4j 2.16
#export JAVA_OPTS=\"$JAVA_OPTS -Dlog4j2.enableJndi=true\"

# Log4k 2.17 -
# Limit JNDI to the java protocol only. JNDI will remain disabled by default. Rename JNDI enablement property from 'log4j2.enableJndi' to 'log4j2.enableJndiLookup', 'log4j2.enableJndiJms', and 'log4j2.enableJndiContextSelector'. 
export JAVA_OPTS=\"$JAVA_OPTS -Dlog4j2.enableJndiLookup\"

#### Environment Variables ####
# export LOG4J_FORMAT_MSG_NO_LOOKUPS=\"true\"
" | eval $SUDO tee ${TOMCAT_HOME}/bin/setenv.sh

  echo "Configuring Tomcat.."
  eval $SUDO chown -R tomcat: ${TOMCAT_HOME}
  eval $SUDO chmod +x ${TOMCAT_HOME}/bin/*.sh

  JAVA_HOME=$(update-java-alternatives -l | cut -d ' ' -f15-)
  export JAVA_HOME=$JAVA_HOME

  echo "
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=${JAVA_HOME}
Environment=CATALINA_PID=${TOMCAT_HOME}/temp/tomcat.pid
Environment=CATALINA_HOME=${TOMCAT_HOME}
Environment=CATALINA_BASE=${TOMCAT_HOME}
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.net.preferIPv4Stack=true -Djava.net.preferIPv4Addresses=true -Djava.awt.headless=true'

ExecStart=${TOMCAT_HOME}/bin/startup.sh
ExecStop=${TOMCAT_HOME}/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
" | eval $SUDO tee /etc/systemd/system/tomcat.service
  
  echo "Starting Tomcat..."
  eval $SUDO systemctl daemon-reload
  eval $SUDO systemctl start tomcat
  eval $SUDO systemctl enable tomcat

  echo ""
  eval $SUDO ufw allow 8080/tcp

  ERROR=$?
  if [ $ERROR -ne 0 ]; then
    echo "[!] Could not install Sysmon for Linux (Error Code: $ERROR)."
  fi
else
  echo "[!] ${ARCHITECTURE} not supported at the moment."
fi