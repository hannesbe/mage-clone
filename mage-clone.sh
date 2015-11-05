# mage-clone
# https://github.com/hannesbe/mage-clone
#
# Shell script to clone a Magento site (to a staging site for example)
# Requires n98-magerun xmlstarlet bc & pv
#
# The MIT License (MIT)
#
# Copyright (c) 2015 Hannes Van de Vel <h@nnes.be>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Usage / Help
VERSION="\e[0;44m$0 v0.1.0\e[0;0m"
HELP="(c) 2015 - Hannes Van de Vel (https://github.com/hannesbe/mage-clone)

\e[0;36musage: $0 [-c <config file>] [-h] [-V]\e[0;0m

Options:
-c
mage-clone config file. Defaults to ./mage-clone.conf
-h
Print this help screen
-V
Version information\e[0;0m
"

# Arguments
while getopts 'c:hV' OPT; do
	case $OPT in
		c)  config=$OPTARG;;
		h)  echo -e "$VERSION"; echo -e "$HELP"; exit 0;;
		V)  echo -e "$VERSION"; exit 0;;
		\? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
		:  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
		*  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
	esac
done

# Read config
if [ $config ] ; then
    source $config
else
    source "./mage-clone.conf"
fi

# Requirements check
type n98-magerun.phar >/dev/null 2>&1 || { echo -e >&2 "\e[0;41m I require n98-magerun but it's not installed\e[0;0m"; exit 1; }
type xmlstarlet >/dev/null 2>&1 || { echo -e >&2 "\e[0;41m I require xmlstarlet but it's not installed\e[0;0m"; exit 1; }
type bc >/dev/null 2>&1 || { echo -e >&2 "\e[0;41m I require bc but it's not installed\e[0;0m"; exit 1; }
type pv >/dev/null 2>&1 || { echo -e >&2 "\e[0;41m I require pv but it's not installed\e[0;0m"; exit 1; }

bytestohr()
{
    # Convert input parameter (number of bytes)
    # to Human Readable form
    #
    SLIST="bytes,KB,MB,GB,TB,PB,EB,ZB,YB"

    POWER=1
    VAL=$( echo "scale=2; $1 / 1" | bc)
    VINT=$( echo $VAL / 1024 | bc )
    while [ $VINT -gt 0 ]
    do
        let POWER=POWER+1
        VAL=$( echo "scale=2; $VAL / 1024" | bc)
        VINT=$( echo $VAL / 1024 | bc )
    done

    echo $VAL$( echo $SLIST | cut -f$POWER -d, )
}
function rsync_p {
    # rsync with progressbar
    #
    set -e
    l=`rsync "$@" -n --out-format='%n' | wc -l`
    rsync "$@" --out-format='%n' | pv -lpte -s $l > /dev/null
}

# Sync files
echo -e "\n\e[0;44m                          \e[0;0m"
echo -e   "\e[0;44m  Syncing files to clone  \e[0;0m"
echo -e   "\e[0;44m                          \e[0;0m\n"

echo -e "\e[0;32mSource path to sync from \e[0;33m"$sourcePath" \e[0;0m"

# Create clone directory
mkdir -p $clonePath

# Get directory sizes
sizeSource=`du -bs --exclude=$exclude $sourcePath/ | sed "s/[^0-9]*//g"`
echo -e "\e[0;32mSource size \e[0;33m"$(bytestohr $sizeSource)" \e[0;0m"

# Start sync with progress bar
echo -e "\e[0;32mSyncing to clone \e[0;33m"$clonePath" \e[0;0m"
rsync_p $rsyncArgs $sourcePath/ $clonePath/

# Make hardlinks to media so don't use up space
echo -e "\e[0;32mMaking clone hardlinks to media \e[0;33m"$sourcePath/media"\e[0;0m"
cp -fvlr $sourcePath/media $clonePath/ > /dev/null

# Copy htpasswd file to clone
if [ $htpasswd ] ; then
    echo -e "\e[0;32mCopying htpasswd \e[0;33m$htpasswd \e[0;32mto clone\e[0;0m"
    cp $htpasswd $clonePath
fi

# Dump source database
echo -e "\n\e[0;44m                             \e[0;0m"
echo -e   "\e[0;44m  Copying database to clone  \e[0;0m"
echo -e   "\e[0;44m                             \e[0;0m\n"

cd $sourcePath
dbSource=`n98-magerun.phar db:info dbname`
echo -e "\e[0;32mDumping source db \e[0;33m"$dbSource"\e[0;0m"

dbSize=$(mysql $mysqlArgs -se "SELECT Round(Sum(data_length + index_length), 0)
FROM  information_schema.tables WHERE table_schema = '$dbSource';")
echo -e "\e[0;32mEstimated db size (unstripped) \e[0;33m"$(bytestohr $dbSize)"\e[0;0m"

if [ $strip ] ; then
    echo -e "\e[0;32mStripping data \e[0;33m"$strip"\e[0;0m"
fi

n98-magerun.phar db:dump --strip="$strip" --stdout  | pv -s $dbSize > $clonePath/$dbSource-clone.sql

# Create db & user if not exists
echo -e "\e[0;32mCreating db \e[0;33m$db\e[0;32m and user \e[0;33m$dbUser\e[0;32m pwd \e[0;33m$dbPwd\e[0;32m if not exists\e[0;0m"
mysql $mysqlArgs -e "CREATE DATABASE IF NOT EXISTS $db; GRANT ALL ON $db.* TO '$dbUser'@'localhost' IDENTIFIED BY '$dbPwd'; FLUSH PRIVILEGES;"

# Restore dump to clone db
echo -e "\e[0;32mRestoring dump \e[0;33m"$clonePath/$dbSource-clone.sql"\e[0;0m"
echo -e "\e[0;32mto clone database \e[0;33m"$db"\e[0;0m"
pv $clonePath/$dbSource-clone.sql | mysql $mysqlArgs $db

# Update clone app/etc/local.xml with clone db credentials & redis db database numbers
echo -e "\n\e[0;44m                         \e[0;0m"
echo -e   "\e[0;44m  Updating clone config  \e[0;0m"
echo -e   "\e[0;44m                         \e[0;0m\n"
cd $clonePath
xmlstarlet edit -L -u "/config/global/resources/default_setup/connection/username" -v "$dbUser" app/etc/local.xml
echo -e "\e[0;32mUpdated db user to \e[0;33m"$dbUser"\e[0;0m"
xmlstarlet edit -L -u "/config/global/resources/default_setup/connection/password" -v "$dbPwd" app/etc/local.xml
echo -e "\e[0;32mUpdated db password to \e[0;33m"$dbPwd"\e[0;0m"
xmlstarlet edit -L -u "/config/global/resources/default_setup/connection/dbname" -v "$db" app/etc/local.xml
echo -e "\e[0;32mUpdated db name to \e[0;33m"$db"\e[0;0m"
if [ $cachedb ] ; then
    xmlstarlet edit -L -u "/config/global/cache/backend_options/database" -v "$cachedb" app/etc/local.xml
    echo -e "\e[0;32mUpdated cache db to \e[0;33m"$cachedb"\e[0;0m"
fi
if [ $sessiondb ] ; then
    xmlstarlet edit -L -u "/config/global/redis_session/db" -v "$sessiondb" app/etc/local.xml
    echo -e "\e[0;32mUpdated session db to \e[0;33m"$sessiondb"\e[0;0m"
fi

# Change clone base URLs
echo -e "\e[0;32mUpdating clone base URLs\e[0;0m"
n98-magerun.phar config:set web/unsecure/base_url $unsecureHost
n98-magerun.phar config:set web/secure/base_url $secureHost

echo -e "\e[0;32mUpdating clone cookie domain\e[0;0m"
n98-magerun.phar config:set web/cookie/cookie_domain $cookieDomain

# Create dummy customers
if [ $dummyCustomers > 0 ] ; then
    echo -e "\n\e[0;44m                       \e[0;0m"
    echo -e   "\e[0;44m  Creating dummy data  \e[0;0m"
    echo -e   "\e[0;44m                       \e[0;0m\n"
    echo -e "\e[0;32mCreating \e[0;33m"$dummyCustomers"\e[0;32m dummy customers locale \e[0;33m"$dummyCustomersLocale"\e[0;0m"
    n98-magerun.phar customer:create:dummy --with-addresses $dummyCustomers $dummyCustomersLocale
fi

# Flush clone cache
echo -e "\n\e[0;44m                        \e[0;0m"
echo -e   "\e[0;44m  Flushing clone cache  \e[0;0m"
echo -e   "\e[0;44m                        \e[0;0m\n"
n98-magerun.phar cache:flush

# Show clone address
echo -e "\n\e[0;42m                  \e[0;0m"
echo -e   "\e[0;42m  Clone is ready  \e[0;0m"
echo -e   "\e[0;42m                  \e[0;0m\n"
echo -e "\e[0;32mClone ready at \e[0;33m"$unsecureHost"\e[0;0m"
echo -e "\e[0;32mDon't forget to configure Apache or nginx. Clone path is \e[0;33m"$clonePath"\e[0;0m"
