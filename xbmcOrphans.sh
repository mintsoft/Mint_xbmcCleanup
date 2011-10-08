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

# To Do:
#
# * examine wether a path is marked as defined content or excluded from
#   scanning (strContent=None)
# * rewrite the whole thing in python

# Discussion and latest version:
# http://forum.xbmc.org/showthread.php?t=62058
# http://wiki.xbmc.org/?title=Linux-Script_To_Find_Not_Scraped_Movies

################
### Settings ###
################

##host, user and password configured in /etc/mysql/my.cnf
##DBPath reassigned to argfuguments to mysql client 
DBPATH='--batch xbmc_video'

### Filenames for results and intermediate data
### You may change these to any name and place you like but beware not to
### overwrite or delete files you may still need
PREFIX="/home/rob/xbmc_cleanup/mysql/xbmc_"
DBPATHLIST="${PREFIX}db_path.lst"
DBFILESLIST="${PREFIX}db_files.lst"
FINDLIST="${PREFIX}find.lst"
DIFFLIST="${PREFIX}diff.lst"
DBONLYLIST="${PREFIX}db-only.lst"
FSONLYLIST="${PREFIX}fs-only.lst"
STACKEDLIST="${PREFIX}db-stacked.lst"

### Programs used ; either absolute path or command only if path to the
### binary is in variable $PATH ; each command may be extended by optional
### arguments - refer to the specific manpage for details
SQLITECMD="mysql" ; FINDCMD="find" ; SORTCMD="sort"
GREPCMD="grep" ; RMCMD="rm" ; UNIQCMD="uniq"
DIFFCMD="diff -a -b -B -U 0 -d"

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

##RE: tr is used to remove tabs between fields 
## tail is used to strip the column heading
${RMCMD} ${DBPATHLIST} ${DBFILESLIST} ${FINDLIST} ${DIFFLIST} ${STACKEDLIST} ${FSONLYLIST} ${DBONLYLIST} 2>/dev/null

${SQLITECMD} ${DBPATH} < <(echo "SELECT strPath FROM path ORDER BY strPath;") \
  | tr -d "\t" | tail -n +2\
  | ${SORTCMD} > ${DBPATHLIST}

${SQLITECMD} ${DBPATH} < <(echo "SELECT strPath, strFilename FROM path, files WHERE path.idPath = files.idPath ORDER BY strPath, strFilename;") \
  | tr -d "\t" | tail -n +2\
  | ${SORTCMD} > ${DBFILESLIST}

IFS='
'
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
${DIFFCMD} ${FINDLIST} ${DBFILESLIST} | ${GREPCMD} -v "^@@" | ${GREPCMD} -v [+-]\\{3\\} | ${SORTCMD} -k 1.2 | ${UNIQCMD} -s 1 > ${DIFFLIST}
${GREPCMD} ^+ < ${DIFFLIST} | ${GREPCMD} -v '://' | ${GREPCMD} -v '^+/$' > ${DBONLYLIST}
${GREPCMD} ^- < ${DIFFLIST} > ${FSONLYLIST}
${GREPCMD} "stack:///" < ${DIFFLIST} > ${STACKEDLIST}
${RMCMD} ${DBPATHLIST} ${DBFILESLIST} ${FINDLIST} ${DIFFLIST} 2>/dev/null
