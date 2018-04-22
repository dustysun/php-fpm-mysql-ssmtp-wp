### About

This image is perfect for a fast and performant WordPress container based on PHP FPM with support for MySQL extensions. Also included is zip support used by many plugins, and sendmail is included as well.

Also included in a WordPress installation script which supports multiple virtual hosts unlike the official WordPress Docker image which only supports one WordPress installation per container.

# Sendmail Support

Make sure to start your containers with the -h or --hostname flag with a FQDN (fully-qualified domain name) which will add the appropriate hostname to the /etc/hosts file in your container. Then, make sure your container is actually reachable by that FQDN. Mail should then work correctly. If not, make sure that port 25 isn't being blocked by your provider.

# Questions?

Contact [support@dustysun.com](<a href="mailto:support@dustysun.com">)
