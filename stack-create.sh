#!/bin/bash

set -eux

ENVIRONMENT_NAME=${ENVIRONMENT_NAME:-"osp17"}
STACK_NAME=${STACK_NAME:-"osp17"}
SCRIPT_DIR=$(realpath $(dirname $0))
SSH_KEY=${SSH_KEY:-"$HOME/.ssh/${STACK_NAME}"}
DEPLOY_TYPE=${DEPLOY_TYPE:-"tripleo"}

if [ -z "$ENVIRONMENT_NAME" ]; then
    echo "Must provide release as first positional argument"
    echo "Supported options: master, osp17"
    exit 1
fi

if [ ! -f ${SSH_KEY} ]; then
    ssh-keygen -N '' -f ${SSH_KEY}
fi
if [ "$DEPLOY_TYPE" = "standalone" ]; then
    ENVIRONMENT_NAME="${ENVIRONMENT_NAME}-standalone"
fi
echo $ENVIRONMENT_NAME
openstack stack create ${STACK_NAME} -t ${SCRIPT_DIR}/${DEPLOY_TYPE}.yaml --wait \
    --parameter-file PrivateKeyContents=${SSH_KEY} \
    --parameter-file PublicKeyContents=${SSH_KEY}.pub \
    --parameter PublicKey="${SSH_KEY}.pub" \
    -e ${SCRIPT_DIR}/${ENVIRONMENT_NAME}.yaml \
    $@

IP=$(openstack stack output show ${STACK_NAME} UndercloudFloatingIP -c output_value -f value)
ssh-keygen -R $IP
SSH_KEYGEN=1 IP=${IP} ${SCRIPT_DIR}/stack-outputs.sh
