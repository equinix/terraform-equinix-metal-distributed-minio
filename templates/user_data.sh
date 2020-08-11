#!/bin/bash

# Detect Operating System
function dist-check() {
  # shellcheck disable=SC1090
  if [ -e /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO=$ID
    # shellcheck disable=SC2034
    DISTRO_VERSION=$VERSION_ID
  fi
}

# Check Operating System
dist-check

# Install pre-requisites (parted and filesystem packages)
  function install-prerequisites() {
    # Installation begins here
    # shellcheck disable=SC2235
    if [ "$DISTRO" == "ubuntu" ]; then
      apt-get update
      apt-get install parted xfsprogs -y
    fi
    # shellcheck disable=SC2235
    if [ "$DISTRO" == "debian" ]; then
      apt-get update
      apt-get install parted xfsprogs -y
    fi
    if [ "$DISTRO" == "raspbian" ]; then
      apt-get update
      apt-get install parted xfsprogs -y
    fi
    if [ "$DISTRO" == "arch" ]; then
      pacman -Syu
      pacman -Syu --noconfirm parted xfsprogs
    fi
    if [ "$DISTRO" = "fedora" ]; then
      dnf update -y
      dnf install parted xfsprogs -y
    fi
    # shellcheck disable=SC2235
    if [ "$DISTRO" == "centos" ]; then
      yum install parted xfsprogs -y
    fi
    if [ "$DISTRO" == "rhel" ]; then
      yum install parted xfsprogs -y
    fi
  }

  # Install prerequisites
  install-prerequisites

root_disk=`df -h | sort -k 6 | head -1 | cut -c1-8`

# Partition and format only drives of the same model
# This is useful for software defined storage solutions where its best to use homogeneous drives
# You can view drive models by running: lsblk -d -o name,size,model,rota
# Example: DRIVE_MODEL="HGST HUS728T8TAL"
# To specify multiple drive models to be used for Minio, the string should be in this format: "DRIVE_MODEL_1\|DRIVE_MODEL_2" where each model name is separated by \|
# Example: DRIVE_MODEL="HGST_HUS728T8TAL\|Micron_5200_MTFD"
# Leaving the string empty (DRIVE_MODEL="") will make the script use any drive model
DRIVE_MODEL="${minio_drive_model}"

# A set of disks to ignore from partitioning and formatting
# In this format: BLACKLIST="/dev/sda|/dev/sdb"
BLACKLIST="$${root_disk}"
# Base directory to hold the data* directories where each storage drive will be mounted
DATA_BASE="/srv/minio"

FILESYSTEM_TYPE="xfs"

usage() {
    echo "Usage: $(basename $0) <new disk>"
}

scan_for_new_disks() {
    # Looks for unpartitioned disks
    declare -a RET
    DEVS=($(lsblk -d -n -p -o name,model | grep "$${DRIVE_MODEL}" | awk '{print $1}' | egrep -v "$${BLACKLIST}"))
    for DEV in "$${DEVS[@]}";
    do
        # Check each device if there is a "1" partition.  If not,
        # "assume" it is not partitioned.
      if [[ $${DEV} == *"/dev/sd"* ]]; then
        if ([ ! -b "$${DEV}1" ]);
        then
            RET+="$${DEV} "
        fi
      elif [[ $${DEV} == *"/dev/nvme"* ]]; then
        if ([ ! -b "$${DEV}p1" ]);
        then
            RET+="$${DEV} "
        fi
      else
        echo "Device $${DEV} is not of /dev/sdX or /dev/nvmeXn1 format"
      fi
    done
    echo "$${RET}"
}

get_next_mountpoint() {
    DIRS=($(ls -1d $${DATA_BASE}/data* 2>&1| sort --version-sort))
    if [ -z "$${DIRS[0]}" ];
    then
        echo "$${DATA_BASE}/data1"
        return
    else
        IDX=$(echo "$${DIRS[$${#DIRS[@]}-1]}"|tr -d "[a-zA-Z/]" )
        IDX=$(( $${IDX} + 1 ))
        echo "$${DATA_BASE}/data$${IDX}"
    fi
}

add_to_fstab() {
    UUID=$${1}
    MOUNTPOINT=$${2}
    grep "$${UUID}" /etc/fstab >/dev/null 2>&1
    if [ $${?} -eq 0 ];
    then
        echo "Not adding $${UUID} to fstab again (it's already there!)"
    else
        LINE="UUID=\"$${UUID}\"\t$${MOUNTPOINT}\t$${FILESYSTEM_TYPE}\tnoatime,nodiratime,nodev,noexec,nosuid\t1 2"
        echo -e "$${LINE}" >> /etc/fstab
    fi
}

is_partitioned() {
# Checks if there is a valid partition table on the
# specified disk
    OUTPUT=$(sfdisk -l $${1} 2>&1)
    grep "No partitions found" "$${OUTPUT}" >/dev/null 2>&1
    return "$${?}"
}

has_filesystem() {
    DEVICE=$${1}
    OUTPUT=$(file -L -s "$${DEVICE}")
    grep filesystem <<< "$${OUTPUT}" > /dev/null 2>&1
    return $${?}
}

do_partition() {
# This function creates one (1) primary partition on the
# disk, using all available space
    DISK=$${1}
    parted --script $${DISK} mklabel gpt mkpart primary 0% 100% > /dev/null 2>&1

#
# Use the bash-specific $PIPESTATUS to ensure we get the correct exit code
# from parted and not from echo
if [ $${PIPESTATUS} -ne 0 ];
then
    echo "An error occurred partitioning $${DISK}" >&2
    echo "I cannot continue" >&2
    exit 2
fi
}

set_partition() {
    DRIVE=$${1}
    if [[ $${DRIVE} == *"/dev/sd"* ]]; then
        echo "$${DRIVE}1"
    elif [[ $${DRIVE} == *"/dev/nvme"* ]]; then
        echo "$${DRIVE}p1"
    else
        echo "Device $${DRIVE} is not of /dev/sdX or /dev/nvmeXn1 format"
    fi
}

if [ -z "$${1}" ];
then
    DISKS=($(scan_for_new_disks))
else
    DISKS=("$${@}")
fi

if [ $${#DISKS[@]} -eq 0 ];
then
    echo "There are no partitionable drives"
    exit 0
fi

# Partitioning all drives

echo "Disks to setup are: $${DISKS[@]}"

for DISK in "$${DISKS[@]}";
do
    echo "Working on $${DISK}"
    is_partitioned $${DISK}
    if [ $${?} -ne 0 ];
    then
        echo "$${DISK} is not partitioned, partitioning"
        do_partition $${DISK}
    fi
done

# Most of the time this message ("/dev/sdb1: No such file or directory") occurs after one partition and you do not reread device partition table which was already loaded.
# A simple partprobe or kpartx -u /dev/sdb1 (/dev/sdb1 is the new partition number to load into partition table) should be enough.
# partprobe or kpartx -u /dev/sdb1
# Running partprobe to load the latest partition tables otherwise there may be an error such as "/dev/nvme0n1p1: No such file or directory" when formatting the partition with a filesystem.
# I had to run partprobe after all the partitions were done for all disks
# because after running it for the first time it doesnt seem to really load the latest partition tables so this way its more reliable

partprobe

# Formatting and mounting all drive partitions

for DISK in "$${DISKS[@]}";
do
    PART_NAME=($(set_partition $${DISK}))
    has_filesystem $${PART_NAME}
    if [ $${?} -ne 0 ];
    then
        echo "Creating filesystem on $${PART_NAME}."
        #echo "Press Ctrl-C if you don't want to destroy all data on $${PART_NAME}"
        #sleep 5
        mkfs.$${FILESYSTEM_TYPE} -f $${PART_NAME}
    fi
    MOUNTPOINT=$(get_next_mountpoint)
    echo "Next mount point appears to be $${MOUNTPOINT}"
    [ -d "$${MOUNTPOINT}" ] || mkdir -p "$${MOUNTPOINT}"
    read UUID FS_TYPE < <(blkid -u filesystem $${PART_NAME}|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
    add_to_fstab "$${UUID}" "$${MOUNTPOINT}"
    echo "Mounting disk $${PART_NAME} on $${MOUNTPOINT}"
    mount "$${MOUNTPOINT}"
done

# Amount of disks that got partitioned
echo "$${#DISKS[@]}"

# For testing you can delete a partition with "parted --script /dev/sdk rm 1". This removes /dev/sdk1


useradd -m -d $${DATA_BASE} -s /sbin/nologin minio-user
curl -LO https://dl.min.io/server/minio/release/linux-amd64/minio
mv minio /usr/local/bin/minio
chmod +x /usr/local/bin/minio

cat <<-"EOF" > /etc/systemd/system/minio.service
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
WorkingDirectory=/usr/local/

User=minio-user
Group=minio-user

EnvironmentFile=/etc/default/minio
ExecStartPre=/bin/bash -c "if [ -z \"$${MINIO_VOLUMES}\" ]; then echo \"Variable MINIO_VOLUMES not set in /etc/default/minio\"; exit 1; fi"

ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES

# Let systemd restart this service always
Restart=always

# Specifies the maximum file descriptor number that can be opened by this process
LimitNOFILE=65536

# Disable timeout logic and wait until process is stopped
TimeoutStopSec=infinity
SendSIGKILL=no

[Install]
WantedBy=multi-user.target

# Built for $${project.name}-$${project.version} ($${project.name})

EOF

cat <<EOT > /etc/default/minio
MINIO_VOLUMES="http://node{1...${minio_node_count}}$${DATA_BASE}/data{1...$${#DISKS[@]}}"
MINIO_ACCESS_KEY="${minio_access_key}"
MINIO_SECRET_KEY="${minio_secret_key}"
MINIO_REGION_NAME="us-east-1"

EOT

chown minio-user:minio-user /usr/local/bin/minio
chown minio-user:minio-user /etc/default/minio
chown -R minio-user:minio-user $${DATA_BASE}

systemctl daemon-reload
systemctl enable minio.service
systemctl start minio.service

sleep 10
curl -LO https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
mv mc /usr/local/bin/
