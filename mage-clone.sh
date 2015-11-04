# Script to clone a Magento site (to a staging site for example)
# Requires n98-magerun xmlstarlet bc & pv
#
# (c) 2015 - Hannes Van de Vel (https://github.com/hannesbe/mage-clone)
#

# Script parameters

sourcePath="/var/www/html/live"
clonePath="/var/www/html/stage"

# Clone Magento secure & unsecure host. Trailing slash required!
unsecureHost="http://www.stage.shop.com/"
secureHost="http://www.stage.shop.com/"

mysqlArgs="--password=1234 --user=root "

# Optional path to htpasswd file to password protect clone, will be copied to
# clone path after source sync.
htpasswd="/var/www/html/.htpasswd"

# Clone database settings. User & db will be created if either doesn't exist
db="magento_clone"
dbUser="magento"
dbPwd="1234"

# Redis cache & session db for clone, optional
cachedb="3"
sessiondb="4"

strip="@development"
# Strip database information from source.
# Options:
# @log Log tables
# @dataflowtemp Temporary tables of the dataflow import/export tool
# @importexporttemp Temporary tables of the Import/Export module
# @stripped Standard definition for a stripped dump (logs, sessions, dataflow and importexport)
# @sales Sales data (orders, invoices, creditmemos etc)
# @customers Customer data
# @trade Current trade data (customers and orders). You usally do not want those in developer systems.
# @search Search related tables (catalogsearch_)
# @development Removes logs, sessions and trade data so developers do not have to work with real customer data
# @idx Tables with _idx suffix and index event tables

dummyCustomers=5
dummyCustomersLocale="en_GB"
# cs_CZ
# ru_RU
# bg_BG
# en_US
# it_IT
# sr_RS
# sr_Cyrl_RS
# sr_Latn_RS
# pl_PL
# en_GB
# de_DE
# sk_SK
# fr_FR
# es_AR
# de_AT

##### Script parameters above

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

exclude='\
--exclude /media \
--exclude /var/report/ \
--exclude /var/session/ \
--exclude /var/log/ \
--exclude \*.sql \
--exclude \*.zip \'
rsyncArgs=" -ai --acls --exclude=$exclude --delete --delete-excluded "

# Create clone directory
mkdir -p $clonePath

# Get directory sizes
sizeSource=`du -bs --exclude=$exclude $sourcePath/ | sed "s/[^0-9]*//g"`

echo -e "\e[0;32m Source size \e[0;33m"$(bytestohr $sizeSource)" \e[0;0m\n"
rsync_p $rsyncArgs $sourcePath/ $clonePath/

# Make hardlinks to media so don't use up space
echo -e "\n\e[0;44m                                   \e[0;0m"
echo -e   "\e[0;44m  Making clone hardlinks to media  \e[0;0m"
echo -e   "\e[0;44m                                   \e[0;0m\n"

cp -fvlr $sourcePath/media $clonePath/   > /dev/null

# Copy htpasswd file to clone
if [ $htpasswd ] ; then
    echo -e "\n\e[0;44m                             \e[0;0m"
    echo -e   "\e[0;44m  Copying htpasswd to clone  \e[0;0m"
    echo -e   "\e[0;44m                             \e[0;0m\n"

    cp $htpasswd $clonePath
fi

# Create db & user if not exists
echo -e "\n\e[0;44m                                        \e[0;0m"
echo -e   "\e[0;44m  Create clone db & user if not exists  \e[0;0m"
echo -e   "\e[0;44m                                        \e[0;0m\n"

echo -e "\e[0;32m Creating db \e[0;33m$db\e[0;32m and user \e[0;33m$dbUser\e[0;32m pwd \e[0;33m$dbPwd\e[0;32m if not exists\e[0;0m"
mysql $mysqlArgs -e "CREATE DATABASE IF NOT EXISTS $db; GRANT ALL ON $db.* TO '$dbUser'@'localhost' IDENTIFIED BY '$dbPwd'; FLUSH PRIVILEGES;"

# Dump source database
echo -e "\n\e[0;44m                     \e[0;0m"
echo -e   "\e[0;44m  Dumping source db  \e[0;0m"
echo -e   "\e[0;44m                     \e[0;0m\n"

cd $sourcePath
dbSource=`n98-magerun.phar db:info dbname`
echo -e "\e[0;32m Dumping source db \e[0;33m"$dbSource"\e[0;0m"

dbSize=$(mysql $mysqlArgs -se "SELECT Round(Sum(data_length + index_length), 0)
FROM  information_schema.tables WHERE table_schema = '$dbSource';")
echo -e "\e[0;32m Estimated db size (without strips) \e[0;33m"$(bytestohr $dbSize)"\e[0;0m"

if [ $strip ] ; then
    echo -e "\e[0;32m Stripping data \e[0;33m"$strip"\e[0;0m"
fi

echo -e "\n"
n98-magerun.phar db:dump --strip="$strip" --stdout  | pv -s $dbSize > $clonePath/$dbSource-clone.sql

# Restore dump to clone db
echo -e "\n\e[0;44m                              \e[0;0m"
echo -e   "\e[0;44m  Restoring dump to clone db  \e[0;0m"
echo -e   "\e[0;44m                              \e[0;0m\n"

echo -e "\e[0;32m Retoring dump \e[0;33m"$clonePath/$dbSource-clone.sql"\e[0;0m"
echo -e "\e[0;32m To clone database \e[0;33m"$db"\e[0;0m"

echo -e "\n"
pv $clonePath/$dbSource-clone.sql | mysql $mysqlArgs $db

# Update clone app/etc/local.xml with clone db credentials & redis db database numbers
echo -e "\n\e[0;44m                                    \e[0;0m"
echo -e   "\e[0;44m  Updating clone db / cache config  \e[0;0m"
echo -e   "\e[0;44m                                    \e[0;0m\n"
cd $clonePath
xmlstarlet edit -L -u "/config/global/resources/default_setup/connection/username" -v "$dbUser" app/etc/local.xml
xmlstarlet edit -L -u "/config/global/resources/default_setup/connection/password" -v "$dbPwd" app/etc/local.xml
xmlstarlet edit -L -u "/config/global/resources/default_setup/connection/dbname" -v "$db" app/etc/local.xml
xmlstarlet edit -L -u "/config/global/cache/backend_options/database" -v "$cachedb" app/etc/local.xml
xmlstarlet edit -L -u "/config/global/redis_session/db" -v "$sessiondb" app/etc/local.xml

if [ $dummyCustomers > 0 ] ; then


# Change clone base URLs
echo -e "\e[0;32m Updating clone base URLs \e[0;0m"
n98-magerun.phar config:set web/unsecure/base_url $unsecureHost
n98-magerun.phar config:set web/secure/base_url $secureHost

# Create dummy customers
if [ $dummyCustomers > 0 ] ; then
    echo " "
    echo -e "\e[0;32m Creating \e[0;33m"$dummyCustomers"\e[0;32m dummy customers in \e[0;33m"$dummyCustomersLocale"\e[0;0m"
    n98-magerun.phar customer:create:dummy --with-addresses $dummyCustomers $dummyCustomersLocale
fi

# Flush clone cache
echo -e "\n\e[0;44m                       \e[0;0m"
echo -e   "\e[0;44m  Flushing clone cache \e[0;0m"
echo -e   "\e[0;44m                       \e[0;0m\n"
n98-magerun.phar cache:flush

# Show clone address
echo -e "\n\e[0;45m                 \e[0;0m"
echo -e   "\e[0;45m  Clone is ready \e[0;0m"
echo -e   "\e[0;45m                 \e[0;0m\n"
echo -e "\e[0;32mClone ready at \e[0;33m"$unsecureHost"\e[0;0m"
echo -e "\e[0;32mDon't forget to configure Apache or nginx. Clone path is \e[0;33m"$clonePath"\e[0;0m"
