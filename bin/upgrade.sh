#!/bin/bash -e

set -o pipefail

cluster_name=$CLUSTER_NAME
cluster_version=$(aws eks describe-cluster --name $cluster_name | jq -r .cluster.version)
desired_version=$K8S_VERSION

function wait_for_update {
    id=$1
    nodegroup=$2
    maybe_nodegroup=''
    if test -n "$nodegroup"; then
        maybe_nodegroup="--nodegroup-name $nodegroup"
    fi
    status=InProgress
    while test "$status" = InProgress; do
        echo Waiting...
        status=$(aws eks describe-update --name $cluster_name --update-id $id $maybe_nodegroup | jq -r .update.status)
        sleep 10
    done
    if test "$status" != Successful; then
        exit 1
    fi
}

if test "$cluster_version" = "$desired_version"; then
    echo "Cluster '$cluster_name' version $cluster_version match desired version $desired_version"
else
    echo "Updating cluster '$cluster_name' version to $desired_version"
    update=$(aws eks update-cluster-version --name $cluster_name --kubernetes-version $desired_version | jq -r .update.id)
    wait_for_update $update
fi

nodegroups=$(aws eks list-nodegroups --cluster-name $cluster_name | jq -r .nodegroups[])
for nodegroup_name in $nodegroups; do
    nodegroup_version=$(aws eks describe-nodegroup --cluster-name $cluster_name --nodegroup-name $nodegroup_name | jq -r .nodegroup.version)
    if test "$nodegroup_version" = "$desired_version"; then
        echo "Managed nodegroup '$nodegroup_name' version $nodegroup_version match desired version $desired_version"
    else
        echo "Updating managed nodegroup '$nodegroup_name' version to $desired_version"
        update=$(aws eks update-nodegroup-version --cluster-name $cluster_name --nodegroup-name $nodegroup_name --kubernetes-version $desired_version | jq -r .update.id)
        wait_for_update $update $nodegroup_name
    fi
done
