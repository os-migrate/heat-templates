#!/bin/bash

exec > >(tee -a standalone-install.log)
exec 2>&1

set -eux
date

cat <<EOF > /home/stack/standalone_parameters.yaml
parameter_defaults:
  CloudName: 192.168.24.2
  # default gateway
  KernelIpNonLocalBind: 1
  ControlPlaneStaticRoutes:
    - ip_netmask: 0.0.0.0/0
      next_hop: 10.98.0.1
      default: true
  Debug: true
  DeploymentUser: stack
  DnsServers:
    - 10.11.5.19
    - 10.5.30.160
  NtpServer: clock.corp.redhat.com
  # needed for vip & pacemaker
  KernelIpNonLocalBind: 1
  DockerInsecureRegistryAddress:
    - 192.168.24.2:8787
  NeutronPublicInterface: eth1
  # domain name used by the host
  CloudDomain: localdomain
  NeutronDnsDomain: localdomain
  # re-use ctlplane bridge for public net, defined in the standalone
  # net config (do not change unless you know what you're doing)
  NeutronBridgeMappings: datacentre:br-ctlplane
  NeutronPhysicalBridge: br-ctlplane
  # enable to force metadata for public net
  #NeutronEnableForceMetadata: true
  StandaloneEnableRoutedNetworks: false
  StandaloneHomeDir: /home/stack
  InterfaceLocalMtu: 1500
  # Needed if running in a VM, not needed if on baremetal
  NovaComputeLibvirtType: qemu
EOF


sudo bash -c 'cat <<EOF > /usr/share/ansible/roles/tripleo-podman/defaults/main.yml
---
tripleo_container_registry_insecure_registries: []
tripleo_container_registry_login: false
tripleo_container_registry_logins: {}
tripleo_container_default_pids_limit: 4096
tripleo_podman_packages: "{{ _tripleo_podman_packages | default([]) }}"
tripleo_buildah_packages: "{{ _tripleo_buildah_packages | default([]) }}"
tripleo_podman_purge_packages: "{{ _tripleo_podman_purge_packages | default([]) }}"
tripleo_podman_tls_verify: true
tripleo_podman_debug: false
tripleo_podman_buildah_login: false
tripleo_podman_default_network_config:
  cniVersion: 0.4.0
  name: podman
  plugins:
    - type: bridge
      bridge: cni-podman0
      isGateway: true
      ipMasq: true
      hairpinMode: true
      ipam:
        type: host-local
        routes:
          - dst: 0.0.0.0/0
        ranges:
          - - subnet: 10.255.255.0/24
              gateway: 10.255.255.1
    - type: portmap
      capabilities:
        portMappings: true
    - type: firewall
    - type: tuning
tripleo_container_events_logger_mechanism: journald
tripleo_podman_unqualified_search_registries:
  - registry.redhat.io
  - registry.access.redhat.com
  - registry.fedoraproject.org
  - registry.centos.org
  - docker.io
  - registry-proxy.engineering.redhat.com
tripleo_podman_insecure_registries: "{{ tripleo_container_registry_insecure_registries }}"
tripleo_podman_registries:
  - prefix: registry-proxy.engineering.redhat.com
    insecure: true
    location: registry-proxy.engineering.redhat.com
tripleo_container_default_runtime: runc
EOF'


time sudo openstack tripleo deploy \
  --standalone \
  --templates \
  --local-ip=192.168.24.2/24 \
  -e /usr/share/openstack-tripleo-heat-templates/environments/standalone/standalone-tripleo.yaml \
  -r /usr/share/openstack-tripleo-heat-templates/roles/Standalone.yaml \
  -e /home/stack/standalone-images.yaml \
  -e /home/stack/standalone_parameters.yaml \
  --output-dir /home/stack $@

date
