#!/bin/bash
source /pkgscripts/include/pkg_util.sh

package="WireGuard"
version="1.0.20200908"
displayname="WireGuard"
maintainer="Andreas Runfalk"
arch="$(pkg_get_platform)"
description="Adds WireGuard support for your Synology NAS."
[ "$(caller)" != "0 NULL" ] && return 0
pkg_dump_info
