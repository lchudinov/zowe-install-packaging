#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2018, 2019
#######################################################################

# Create PROCLIB library members.
# Called by zowe-configure.sh
#
# Arguments:
# /
#
# Expected globals:
# $IgNoRe_ErRoR $debug $LOG_FILE $INSTALL_DIR

space="10,2"                   # data set space allocation
here=$(dirname $0)             # script location
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

echo "-- PROCLIB library"
test "$debug" && echo "> $me $@"
test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE

# ---------------------------------------------------------------------
# --- customize a member using sed, optionally creating a new output member
#     assumes $SED is defined by caller and holds sed command string
# $1: input DSN
# $2: input member
# $3: (optional) output DSN, default is $1, required if $4 is specified
# $4: (optional) output member, default is $2
# ---------------------------------------------------------------------
function _sedMVS
{
TmP=$TEMP_DIR/$2
_cmd --repl $TmP sed $SED "//'$1($2)'"            # sed '...' $1 > $TmP
_cmd mv $TmP "//'${3:-$1}(${4:-$2})'"
}    # _sedMVS

# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $1: if --repl then save stdout to $2, parms are removed when present
# $2: if $1 = --save or --repl then target receiving stdout
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _cmd
{
test "$debug" && echo
if test "$1" = "--null"
then         # stdout -> null, stderr -> stdout (without going to null)
  shift
  test "$debug" && echo "$@ 2>&1 >/dev/null"
                         $@ 2>&1 >/dev/null
elif test "$1" = "--save"
then         # stdout -> >>$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 >> $sAvE"
                         $@ 2>&1 >> $sAvE
elif test "$1" = "--repl"
then         # stdout -> >$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 > $sAvE"
                         $@ 2>&1 > $sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "$@ 2>&1"
                         $@ 2>&1
fi    #
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _cmd

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing
_cmd umask 0022                                  # similar to chmod 755

# Set environment variables when not called via zowe-configure.sh
if test -z "$INSTALL_DIR"
then
  # Note: script exports environment vars, so run in current shell
  _cmd . $(dirname $0)/../scripts/zowe-set-envvars.sh $0
else
  echo "  $(date)" >> $LOG_FILE
fi    #

# Validate/create target data set
$scripts/allocate-dataset.sh "$ZOWE_PROCLIB" FB 80 PO "$space"
# returns 0 for OK, 1 for DCB mismatch, 2 for not pds(e), 8 for error
rc=$?
if test $rc -eq 0
then                                          # data set created/exists
  # no operation
elif test $rc -eq 1
then                                       # data set exists, wrong DCB
  echo "** ERROR $me data set $dsn does not have DCB(FB 80 PO)"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
else
  # Error details already reported
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# ZWESISTC
SED=""
SED="$SED;s/HLQ=[^,]*/HLQ=${ZOWE_HLQ}/"
SED="$SED;s/CFG=[^,]*/HLQ=${ZOWE_PARMLIB}/"
_sedMVS "${ZOWE_HLQ}.SZWESAMP" ZWESISTC "$ZOWE_PROCLIB" "$ZOWE_STC_ZSS"

# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

# ZWESTC
SED=""
SED="$SED;s!HOME=[^,]*!HOME='${ZOWE_ROOT_DIR}'!"
SED="$SED;s!CFG=[^,]*!CFG='${ZOWE_CFG}'!"
_sedMVS "${ZOWE_HLQ}.SZWESAMP" ZWESTC "$ZOWE_PROCLIB" "$ZOWE_STC_ZOWE"

test "$debug" && echo "< $me 0"
echo "</$me> 0" >> $LOG_FILE
exit 0