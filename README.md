# MD-INIT

A small bash script to initialize md raids (mdadm)

![Example Screenshot](https://i.imgur.com/MPETLJR.png)

## WIP

Work in progress

Currently supports one array (it creates /dev/md0) and destroys everything in the disk

## TODO

* Add more missing checks (to cover all faults in the process)
* Add multiple arrays support
* Auto install dependencies (parted, mdadm, etc)
