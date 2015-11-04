# mage-clone

[![GitHub license](https://img.shields.io/github/license/hannesbe/mage-clone.svg)](https://raw.githubusercontent.com/hannesbe/mage-clone/master/LICENSE)

[![GitHub release](https://img.shields.io/github/release/hannesbe/mage-clone.svg)](https://github.com/hannesbe/mage-clone/releases) [![GitHub commits](https://img.shields.io/github/commits-since/hannesbe/mage-clone/0.1.svg)](https://github.com/hannesbe/mage-clone/commits/0.1)


Shell script to easily create a clone from a Magento site for staging, testing or development.

- Fast file (re)syncing from source to clone
- Hard links to source media folder to safe space & faster cloning.
- Database dump & import into clone with option to strip data. Database user & database created if they do not yet exist.
- Updates clone's `local.xml` database & cache configuration.
- Progress bars for each step, especially useful for larger shops.
- Optionally create dummy customer data on clone.

## Requirements
Requires n98-magerun xmlstarlet bc & pv.
On CentOS / RHEL based OS use
```
yum install xmlstarlet bc pv
```

For n98-magerun follow [Magerun installation instructions](http://magerun.net/installation).

Make sure to copy `n98-magerun.phar` to `/usr/local/bin/` for example, the script expects it to be in your path.

## Known issues / limitations


## License
[![GitHub license](https://img.shields.io/github/license/hannesbe/mage-clone.svg)](https://raw.githubusercontent.com/hannesbe/mage-clone/master/LICENSE)

See the [LICENSE](LICENSE) file for more details.
