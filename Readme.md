### About

This image is perfect for a fast and performant WordPress container based on PHP FPM with support for MySQL extensions. Also included is zip support used by many plugins, and SSMTP supporting using sendmail in conjunction with an external mailserver is supported.

Also included in a WordPress installation script which supports multiple virtual hosts unlike the official WordPress Docker image which only supports one WordPress installation per container.

# Email Support

Make sure to start your containers with the -h or --hostname flag with a FQDN (fully-qualified domain name) which will add the appropriate hostname to the /etc/hosts file in your container. Then, make sure your container is actually reachable by that FQDN.

Next, you will need to provide environment variables that point SSMTP to your mailserver. A good option is the [namshi/docker-smtp container](<a href="https://github.com/namshi/docker-smtp">)

# Environment Variables Supported

Required environment variables:
VIRTUAL_HOST: One or more virtual hosts separated by comma
VIRTUAL_ROOT: Root directory to the HTML files for the site
WORDPRESS_DB_HOST: Reachable DNS name for the database server
WORDPRESS_DB_ADMIN_USER: User account with the ability to create tables and
              			     assign permissions on the DB server
WORDPRESS_DB_ADMIN_PASSWORD: Password for the admin user on the DB server

Per virtual host environment variables:
Prefix these with the name of the virtual host with periods and hyphens
changed to underscores. For example, www.domain-name.com would be changed to
www_domain_name_com.

For the variables below, replace virtualhost_com with your virtual host name
with periods and hyphens changed to underscores as noted above.

virtualhost_com_DB_NAME: Name for the vhost's WP database
virtualhost_com_DB_USER: User account that should have ownership over the DB
virtualhost_com_DB_PASSWORD: Password for the DB account
virtualhost_com_TABLE_PREFIX: Prefix for the tables if different than default
virtualhost_com_WP_DEBUG: Set to 1 to enable debugging
virtualhost_com_WORDPRESS_UPDATE: If set to 1 for true, the WP files will
            be copied even if they already exist in the destination
virtualhost_com_WORDPRESS_SKIP: Set to 1 to prevent WP files from being copied


Mail environment variables:
To use these, you must have another container or other accessible mailing
host from which you can send emails

ssmtp_hostname: Name of your server; default is localhost.localdomain
ssmtp_root_email: Email address for the root user; default is root@localhost
ssmtp_server: FQDN or hostname/containername of your mailserver; default is mail
ssmtp_port: Port for your mailserver; default is 25

# Questions?

Contact [support@dustysun.com](<a href="mailto:support@dustysun.com">)


# Revisions

= v2.1 2018-09-07 = 
* Added SOAP client