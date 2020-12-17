#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020
################################################################################

# TODO LATER - anyway to do this better?
# Try and work out where we are even if sourced
if [[ -n ${INSTALL_DIR} ]]
then
  export utils_dir="${INSTALL_DIR}/bin/utils"
elif [[ -n ${ZOWE_ROOT_DIR} ]]
then
  export utils_dir="${ZOWE_ROOT_DIR}/bin/utils"
elif [[ -n ${ROOT_DIR} ]]
then
  export utils_dir="${ROOT_DIR}/bin/utils"
elif [[ $0 == "zowe-variable-utils.sh" ]] #Not called by source
then
  export utils_dir=$(cd $(dirname $0);pwd)
else
  echo "Could not work out the path to the utils directory. Please 'export ZOWE_ROOT_DIR=<zowe-root-directory>' before running." 1>&2
  return 1
fi

# Source common util functions
. ${utils_dir}/common.sh

# Takes in a single parameter - the name of the variable
validate_variable_is_set() {
  variable_name=$1
  eval "value=\"\$${variable_name}\""
  if [[ -z "${value}" ]]
  then
    print_error_message "${variable_name} is empty"
    return 1
  fi
}

# Takes in a list of space separated names of the variables
validate_variables_are_set() {
  invalid=0
  for var in $(echo $1 | sed "s/,/ /g")
  do
    validate_variable_is_set "${var}"
    valid_rc=$?
    if [[ ${valid_rc} -ne 0 ]]
    then	
      let "invalid=${invalid}+1"
    fi
  done
  return $invalid
}

# ZOWE_PREFIX + instance - should be <=6 char long and exist.
# TODO - any lower bound (other than 0)?
# Requires ZOWE_PREFIX to be set as a shell variable
validate_zowe_prefix() {
  validate_variable_is_set "ZOWE_PREFIX"
  prefix_set_rc=$?
  if [[ ${prefix_set_rc} -eq 0 ]]
  then
    PREFIX_LENGTH=${#ZOWE_PREFIX}
    if [[ $PREFIX_LENGTH > 6 ]]
    then
      print_error_message "ZOWE_PREFIX '${ZOWE_PREFIX}' should be less than 7 characters"
      return 1
    fi
  else
    return $prefix_set_rc
  fi
}

update_zowe_instance_variable(){                                                                            
  variable_name=$1
  variable_value=$2
  is_append=$3 # if false then the value of the given veriable_name will be replaced, append the value if true

  if [ -z ${is_append} ]; then
    is_append=true # default value is true
  fi

  variable_name_exists=$(grep "^ *${variable_name}=" ${INSTANCE_DIR}/instance.env)

  if [ -z ${variable_name_exists} ]; then
    echo "${variable_name}=${variable_value}" >> ${INSTANCE_DIR}/instance.env
  else
    curr_variable_value=$(echo ". ${INSTANCE_DIR}/instance.env && echo \$${variable_name}" | sh)
    if [ ! -z ${curr_variable_value} ]; then
      if [ ${is_append} = false ]; then
        sed -e "s/^ *${variable_name}=${curr_variable_value}/${variable_name}=${variable_value}/" ${INSTANCE_DIR}/instance.env > ${INSTANCE_DIR}/instance.env.tmp
        mv ${INSTANCE_DIR}/instance.env.tmp ${INSTANCE_DIR}/instance.env
      else
        # Ensures that the bin directory of the component is included into the instance.env once (Avoids duplication if same component is installed twice)
        if [[ $(echo ${curr_variable_value} | grep ${variable_value}) = "" ]]; then
          sed -e "s/^ *${variable_name}=${curr_variable_value}/${variable_name}=${curr_variable_value},${variable_value}/" ${INSTANCE_DIR}/instance.env > ${INSTANCE_DIR}/instance.env.tmp
          mv ${INSTANCE_DIR}/instance.env.tmp ${INSTANCE_DIR}/instance.env
        fi
      fi
    else
        sed -e "s/^ *${variable_name}=/${variable_name}=${variable_value}/" ${INSTANCE_DIR}/instance.env > ${INSTANCE_DIR}/instance.env.tmp
        mv ${INSTANCE_DIR}/instance.env.tmp ${INSTANCE_DIR}/instance.env
    fi
  fi
}