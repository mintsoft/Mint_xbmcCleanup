#!/bin/bash
#
# XBMC Orphans and Widows
# v1.1
#
# created by BaerMan for XBMC-community
# includes improvements from deathinator
# This script may be used for any purposes.
# You may change, sell, print or even sing it
# but you have to use it at your own risk!
#
# Hax0red by Mint for mysql supports
#
# This script is ugly and may under certain circumstances crash your
# computer, kill your cat and/or drink your beer.
# Use it at your own risk!
#
# This script searches for media files (actually video files only) and
# checkes for
# 1) files that are not in the library
# 2) files that are in library only
# 3) entries in the library that are 'stacked' ones

# TODO:
# * examine wether a path is marked as defined content or excluded from
#   scanning (strContent=None)

# Discussion and latest version:
# http://forum.xbmc.org/showthread.php?t=62058
# http://wiki.xbmc.org/?title=Linux-Script_To_Find_Not_Scraped_Movies

################
### Settings ###
################

## mySQL arguments:
## credentials can be configurede here with -u -p and -h
## or alternatively in /etc/mysql/my.cnf under [client]
## xbmc_video is the name of the mySQL schema/database in-which the video
## library is contained
MYSQL_ARGS='--batch xbmc_video'

### Filenames for results and intermediate data
### You may change these to any name and place you like but beware not to
### overwrite or delete files you may still need
## Intermediate files are prefixed xbmc_zzz
DIRECTORY="/home/rob/xbmc_cleanup/mysql/"
DBPATHLIST="${DIRECTORY}xbmc_zzz_db_path.lst"
DBFILESLIST="${DIRECTORY}xbmc_zzz_db_files.lst"
FINDLIST="${DIRECTORY}xbmc_zzz_find.lst"
DIFFLIST="${DIRECTORY}xbmc_zzz_diff.lst"
DBONLYLIST="${DIRECTORY}xbmc_db-only.lst"
FSONLYLIST="${DIRECTORY}xbmc_fs-only.lst"
STACKEDLIST="${DIRECTORY}xbmc_db-stacked.lst"

### Programs used ; either absolute path or command only if path to the
### binary is in variable $PATH ; each command may be extended by optional
### arguments - refer to the specific manpage for details
### CUTCMD is used to remove the first character of diff output
MYSQLCMD="mysql" ; FINDCMD="find" ; SORTCMD="sort"
GREPCMD="grep" ; RMCMD="rm" ; UNIQCMD="uniq"
DIFFCMD="diff -a -b -B -U 0 -d" ; CUTCMD="cut -b 2-"

#######################################
### Changes within the working code ###
#######################################

### There is a list of suffixes, that we will search for. You may add,
### delete or modify any entry to fit your needs, but respect the
### correct escaping of newlines

### We don't want to descent into subdirectories as they are usually
### represented by their own path-entry in the database. Deep scans would
### lead to multiple hits on the same file. But if for some reason not all
### path elements are represented in the database, you may find and delete
### the following string and force $FINDCMD to look into all subdirectories
### in any given path
### "-maxdepth 1"

####################
### working code ###
####################

## RE: tr is used to remove tabs between fields
## RE: tail is used to strip the column heading
${RMCMD} ${DBPATHLIST} ${DBFILESLIST} ${FINDLIST} ${DIFFLIST} ${STACKEDLIST} ${FSONLYLIST} ${DBONLYLIST} 2>/dev/null

DIRLIST_SQL="SELECT strPath FROM path ORDER BY strPath;";
FILELIST_SQL="SELECT strPath, strFilename FROM path INNER JOIN files USING (idPath) ORDER BY strPath, strFilename;";

## RE: <() used to create a file descriptor of the SQL then < used to pass that to mysql,
##     mySQL client doesn't support using SQL on the command line directly only through script files

## Create a list of directories to scan, ignoring streams
${MYSQLCMD} ${MYSQL_ARGS} < <(echo "${DIRLIST_SQL}") \
  | tr -d "\t" | tail -n +2\
  | grep -Ev "^http[s]?:\/\/"\
  | ${SORTCMD} > ${DBPATHLIST}

## Create a list of files to compare
${MYSQLCMD} ${MYSQL_ARGS} < <(echo "${FILELIST_SQL}") \
  | tr -d "\t" | tail -n +2\
  | ${SORTCMD} > ${DBFILESLIST}


## Set the Internal Separator to a new line for easier parsing between files in the diff
IFS=$'\n';

## Create list of video files
for fPATH in $(<${DBPATHLIST}) ; do
    ${FINDCMD} ${fPATH} -maxdepth 1 \( \
 -name '*.avi' -o \
 -name '*.divx' -o \
 -name '*.iso' -o \
 -name '*.m2v' -o \
 -name '*.mkv' -o \
 -name '*.mp4' -o \
 -name '*.m4v' -o \
 -name '*.mpeg' -o \
 -name '*.mpg' -o \
 -name '*.rmvb' -o \
 -name '*.wmv' -o \
 -name '*.flv' -o \
 -name '*.ogm' -o \
 -name '*.vob' \
    \) | ${SORTCMD} >> ${FINDLIST}
done
unset IFS

#Diff the database list and find list
${DIFFCMD} ${FINDLIST} ${DBFILESLIST} | ${GREPCMD} -v "^@@" | ${GREPCMD} -v [+-]\\{3\\} | ${SORTCMD} -k 1.2 | ${UNIQCMD} -s 1 > ${DIFFLIST}

#Make a list of those files beginning with "+" meaning only exists in the db list
${GREPCMD} ^+ < ${DIFFLIST} | ${GREPCMD} -v '://' | ${GREPCMD} -v '^+/$' | ${CUTCMD} > ${DBONLYLIST}

#Make a list of those files beginning with "-" meaning only exists on the filesystem
${GREPCMD} ^- < ${DIFFLIST} | ${CUTCMD} > ${FSONLYLIST}

#list stacked files
${GREPCMD} "stack:///" < ${DIFFLIST} > ${STACKEDLIST}

#tidy up intermediate files:
${RMCMD} ${DBPATHLIST} ${DBFILESLIST} ${FINDLIST} ${DIFFLIST} 2>/dev/null
