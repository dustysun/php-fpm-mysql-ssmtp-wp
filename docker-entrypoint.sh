#!/bin/bash
# ==========================================================
#
# Sets up WordPress using the VIRTUAL_HOST and other
# environment variables. Some sections are from the
# official WordPress Docker image with modifications to
# work with multiple hosts
#
# Required environment variables:
# VIRTUAL_HOST: One or more virtual hosts separated by comma
# VIRTUAL_ROOT: Root directory to the HTML files for the site
# WORDPRESS_DB_HOST: Reachable DNS name for the database server
# WORDPRESS_DB_ADMIN_USER: User account with the ability to create tables and
#			assign permissions on the DB server
# WORDPRESS_DB_ADMIN_PASSWORD: Password for the admin user on the DB server
#
# Per virtual host environment variables:
# Prefix these with the name of the virtual host with periods and hyphens
# changed to underscores. For example, www.domain-name.com would be changed to
# www_domain_name_com.
#
# For the variables below, replace virtualhost_com with your virtual host name
# with periods and hyphens changed to underscores as noted above.
#
# virtualhost_com_DB_NAME: Name for the vhost's WP database
# virtualhost_com_DB_USER: User account that should have ownership over the DB
# virtualhost_com_DB_PASSWORD: Password for the DB account
# virtualhost_com_TABLE_PREFIX: Prefix for the tables if different than default
# virtualhost_com_WP_DEBUG: Set to 1 to enable debugging
# virtualhost_com_WORDPRESS_UPDATE: If set to 1 for true, the WP files will
#			be copied even if they already exist in the destination
# virtualhost_com_WORDPRESS_SKIP: Set to 1 to prevent WP files from being copied
#
# ===========================================================

#variables
scriptLog=/var/log/docker-entrypoint-setup.log

echo >&2 `date` ": Begin Docker entrypoint install/update script..." | tee -a $scriptLog

# usage: file_env VAR [DEFAULT]
#   ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
# "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}
# see http://stackoverflow.com/a/2705678/433558
sed_escape_lhs() {
  echo "$@" | sed -e 's/[]\/$*.^|[]/\\&/g'
}
sed_escape_rhs() {
  echo "$@" | sed -e 's/[\/&]/\\&/g'
}
php_escape() {
  local escaped="$(php -r 'var_export(('"$2"') $argv[1]);' -- "$1")"
  if [ "$2" = 'string' ] && [ "${escaped:0:1}" = "'" ]; then
    escaped="${escaped//$'\n'/"' + \"\\n\" + '"}"
  fi
  echo "$escaped"
}

echo "This script relies on the VIRTUAL_HOST env variable being set. If there are multiple hosts separated by comma, it will process each."
echo "The env variables for WordPress database, username, password and table prefix should all be set as well, beginning with the virtual host name."
echo "For example, hostname.com_DB_NAME, hostname.com_DB_USER, hostname.com_DB_PASSWORD, hostname.com_TABLE_PREFIX"

#Download WordPress
cd /tmp
curl -o wordpress.tar.gz -fSL "https://wordpress.org/latest.tar.gz"  | tee -a $scriptLog

# Script relies on the environment variables
# Get the host names which are separated by comma

#Check for $VIRTUAL_HOST
if [ -z "$VIRTUAL_HOST" ]; then echo >&2 "VIRTUAL_HOST var must be set in the Docker environment variables. Exiting..."; exit 1; fi

#Check for $VIRTUAL_ROOT
if [ -z "$VIRTUAL_ROOT" ]; then echo >&2 "VIRTUAL_ROOT var must be set in the Docker environment variables. Exiting..."; exit 1; fi


IFS=',' read -ra V_HOSTS <<< "${VIRTUAL_HOST}"
for i in "${V_HOSTS[@]}"; do

  #remove any whitespace
  CURRENT_VHOST="${i// /}"

  #convert name to a version with underscores by removing periods
  VHOST_VAR="${CURRENT_VHOST//./_}"

  #convert name to a version with underscores by removing hyphens
  VHOST_VAR="${VHOST_VAR//-/_}"


  VhostPath=${VIRTUAL_ROOT}/${CURRENT_VHOST}

  #Create the Vhosts directory if it does not exist
  if [[ ! -d $VhostPath ]]; then
    mkdir -p $VhostPath
  fi

  #Check if WORDPRESS_SKIP is set for this host
  EVAL_VHOST_WORDPRESS_SKIP=${VHOST_VAR}_WORDPRESS_SKIP
  WORDPRESS_SKIP=${!EVAL_VHOST_WORDPRESS_SKIP}

  if [ $WORDPRESS_SKIP ] && [ $WORDPRESS_SKIP = '1' ]; then
    echo >&2 "WordPress install/update skipped for $i."
    continue;
  fi

  #Check if WORDPRESS_UPDATE is set for this host
  EVAL_VHOST_WORDPRESS_UPDATE=${VHOST_VAR}_WORDPRESS_UPDATE
  WORDPRESS_UPDATE=${!EVAL_VHOST_WORDPRESS_UPDATE}

  #see if WP needs to be set up
	#add additional checks to see if xmlrpc.php is there in case the full WP
	#wasn't copied at some point
  if ! [ -e $VhostPath/index.php ] || ! [ -e $VhostPath/wp-includes/version.php ] || ! [ -e $VhostPath/xmlrpc.php ] || [ $WORDPRESS_UPDATE ]; then

		echo >&2 "WordPress not found in $VhostPath - copying now..." | tee -a $scriptLog

    #decompress earlier downloaded file to the WordPress path
		tar -vzxf /tmp/wordpress.tar.gz --strip-components=1 --directory $VhostPath/ | tee -a $scriptLog
    #cp -R /tmp/wordpress/* $VhostPath/ | tee -a $scriptLog

    #create .htaccess in the root if it doesn't already exist.
    touch $VhostPath/.htaccess | tee -a $scriptLog

    #set initial permissions to the www-data user
		echo >&2 "Changing permissions in $VhostPath..." | tee -a $scriptLog
    chown -Rv www-data:www-data $VhostPath | tee -a $scriptLog

	fi

	if ! [ -e $VhostPath/wp-config.php ]; then

		echo >&2 "Wp-config.php not found in $VhostPath - creating now..." | tee -a $scriptLog

		#Copy the wp-config-sample.php to wp-config.php
		#Start section to update wp-config.php
		#Check for DB access
		if [ -z "${WORDPRESS_DB_HOST}" ]; then echo >&2 "WORDPRESS_DB_HOST must be set in the Docker environment variables to set up WordPress. Skipping this host..."; continue; fi
		if [ -z "${WORDPRESS_DB_ADMIN_USER}" ]; then echo >&2 "WORDPRESS_DB_ADMIN_USER must be set in the Docker environment variables. Exiting..."; continue; fi
		if [ -z "${WORDPRESS_DB_ADMIN_PASSWORD}" ]; then echo >&2 "WORDPRESS_DB_ADMIN_PASSWORD must be set in the Docker environment variables. Exiting..."; continue; fi

    # version 4.4.1 decided to switch to windows line endings, that breaks our seds and awks
    # https://github.com/docker-library/wordpress/issues/116
    # https://github.com/WordPress/WordPress/commit/1acedc542fba2482bab88ec70d4bea4b997a92e4
    sed -ri -e 's/\r$//' $VhostPath/wp-config*

		awk '/^\/\*.*stop editing.*\*\/$/ && c == 0 { c = 1; system("cat") } { print }' $VhostPath/wp-config-sample.php > $VhostPath/wp-config.php <<'EOPHP'
// If we're behind a proxy server and using HTTPS, we need to alert Wordpress of that fact
// see also http://codex.wordpress.org/Administration_Over_SSL#Using_a_Reverse_Proxy
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
	$_SERVER['HTTPS'] = 'on';
}
EOPHP
		echo >&2 "Changing permissions on $VhostPath/wp-config.php..." | tee -a $scriptLog
		chown www-data:www-data $VhostPath/wp-config.php

    set_config() {

      key="$1"
      value="$2"
      var_type="${3:-string}"
      start="(['\"])$(sed_escape_lhs "$key")\2\s*,"
      end="\);"
      if [ "${key:0:1}" = '$' ]; then
        start="^(\s*)$(sed_escape_lhs "$key")\s*="
        end=";"
      fi

      sed -ri -e "s/($start\s*).*($end)$/\1$(sed_escape_rhs "$(php_escape "$value" "$var_type")")\3/" $VhostPath/wp-config.php
    }

    uniqueEnvs=(
      AUTH_KEY
      SECURE_AUTH_KEY
      LOGGED_IN_KEY
      NONCE_KEY
      AUTH_SALT
      SECURE_AUTH_SALT
      LOGGED_IN_SALT
      NONCE_SALT
    )

    for unique in "${uniqueEnvs[@]}"; do
			uniqVar="WORDPRESS_$unique"
			if [ -n "${!uniqVar}" ]; then
				set_config "$unique" "${!uniqVar}"
			else
				# if not specified, let's generate a random value
				currentVal="$(sed -rn -e "s/define\((([\'\"])$unique\2\s*,\s*)(['\"])(.*)\3\);/\4/p" $VhostPath/wp-config.php)"

				if [ "$currentVal" == 'put your unique phrase here' ]; then
					set_config "$unique" "$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)"
				fi
			fi
		done

    #Set up variable names for each hosts
    EVAL_VHOST_DB_NAME=${VHOST_VAR}_DB_NAME
    EVAL_VHOST_DB_USER=${VHOST_VAR}_DB_USER
    EVAL_VHOST_DB_PASSWORD=${VHOST_VAR}_DB_PASSWORD
    EVAL_VHOST_TABLE_PREFIX=${VHOST_VAR}_TABLE_PREFIX
    EVAL_VHOST_DEBUG=${VHOST_VAR}_WP_DEBUG

    # Tests to make sure certain evn vars are set
    if [ -z "${!EVAL_VHOST_DB_NAME}" ]; then echo >&2 "${VHOST_VAR}_DB_NAME must be set in the Docker environment variables. Not configuring wp-config.php for this host..."; continue; fi
    if [ -z "${!EVAL_VHOST_DB_USER}" ]; then echo >&2 "${VHOST_VAR}_DB_USER must be set in the Docker environment variables. Not configuring wp-config.php for this host..."; continue; fi
    if [ -z "${!EVAL_VHOST_DB_PASSWORD}" ]; then echo >&2 "${VHOST_VAR}_DB_PASSWORD must be set in the Docker environment variables. Not configuring wp-config.php for this host..."; continue; fi

    WP_VHOST_DB_NAME=${!EVAL_VHOST_DB_NAME}
    WP_VHOST_DB_USER=${!EVAL_VHOST_DB_USER}
    WP_VHOST_DB_PASSWORD=${!EVAL_VHOST_DB_PASSWORD}
    WP_TABLE_PREFIX=${!EVAL_VHOST_TABLE_PREFIX}
    WP_DEBUG=${!EVAL_VHOST_DEBUG}

    Q1="CREATE DATABASE IF NOT EXISTS \`$WP_VHOST_DB_NAME\`;"
    Q2="GRANT ALL ON \`$WP_VHOST_DB_NAME\`.* TO '$WP_VHOST_DB_USER'@'%' IDENTIFIED BY '$WP_VHOST_DB_PASSWORD';"
    Q3="FLUSH PRIVILEGES;"
    SQL="${Q1}${Q2}${Q3}"

    MYSQL=`which mysql`

    #Create the database if it doesnt exist
    $MYSQL --host=$WORDPRESS_DB_HOST --user=$WORDPRESS_DB_ADMIN_USER --password=$WORDPRESS_DB_ADMIN_PASSWORD -e "$SQL"

    #Make changes to the wp-config.php file with the database setup.
    if [ "$WORDPRESS_DB_HOST" ]; then
      set_config 'DB_HOST' "$WORDPRESS_DB_HOST"
    fi

    if [ "$WP_VHOST_DB_NAME" ]; then
      set_config 'DB_NAME' "$WP_VHOST_DB_NAME"
    fi

    if [ "$WP_VHOST_DB_USER" ]; then
      set_config 'DB_USER' "$WP_VHOST_DB_USER"
    fi

    if [ "$WP_VHOST_DB_PASSWORD" ]; then
      set_config 'DB_PASSWORD' "$WP_VHOST_DB_PASSWORD"
    fi

    if [ "$WP_TABLE_PREFIX" ]; then
      set_config '$table_prefix' "$WP_TABLE_PREFIX"
    fi

    if [ "$WP_DEBUG" ]; then
      set_config 'WP_DEBUG' 1 boolean
    else
      set_config 'WP_DEBUG' 0 boolean
    fi

  fi # end updates to wp-config.php
done # end processing per host

# Start sendmail
/etc/init.d/sendmail start | tee -a $scriptLog

exec "$@"
