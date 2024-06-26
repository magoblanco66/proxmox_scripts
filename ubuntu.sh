
#!/bin/bash
# Copyright (c) 2022-2024 jhonus
# Author: jhonus (telegram)
# License: MIT
# https://github.com/magoblanco66/proxmox_scripts/raw/main/LICENSE

#ASCI Nombre https://www.freetool.dev/es/generador-de-letras-ascii ANSI REGULAR
function header_info {
  clear
  cat <<"EOF"
  
██    ██ ██████  ██    ██ ███    ██ ████████ ██    ██ 
██    ██ ██   ██ ██    ██ ████   ██    ██    ██    ██ 
██    ██ ██████  ██    ██ ██ ██  ██    ██    ██    ██ 
██    ██ ██   ██ ██    ██ ██  ██ ██    ██    ██    ██ 
 ██████  ██████   ██████  ██   ████    ██     ██████  
                                                   
EOF
}
header_info
echo -e "\n Cargando..."

# Clear the contents of the ISO directory
echo "Clearing contents of /var/lib/vz/template/iso/..."
rm -rf /var/lib/vz/template/iso/*

# Variables
# Menu de selección de versión de Ubuntu
echo "Selecciona la versión de Ubuntu que deseas instalar:"
options=("Ubuntu 18.04.6" "Ubuntu 20.04.6" "Ubuntu 22.04.2" "Ubuntu 22.10" "Ubuntu 23.04" "Salir")
select opt in "${options[@]}"
do
    case $opt in
        "Ubuntu 18.04.6")
            UBUNTU_VERSION="18.04.6"
            ISO_FILE="ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"
            ISO_URL="https://releases.ubuntu.com/${UBUNTU_VERSION}/${ISO_FILE}"
            break
            ;;
        "Ubuntu 20.04.6")
            UBUNTU_VERSION="20.04.6"
            ISO_FILE="ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"
            ISO_URL="https://releases.ubuntu.com/${UBUNTU_VERSION}/${ISO_FILE}"
            break
            ;;
        "Ubuntu 22.04.2")
            UBUNTU_VERSION="22.04.2"
            ISO_FILE="ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"
            ISO_URL="https://releases.ubuntu.com/${UBUNTU_VERSION}/${ISO_FILE}"
            break
            ;;
        "Ubuntu 22.10")
            UBUNTU_VERSION="22.10"
            ISO_FILE="ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"
            ISO_URL="https://releases.ubuntu.com/${UBUNTU_VERSION}/${ISO_FILE}"
            break
            ;;
        "Ubuntu 23.04")
            UBUNTU_VERSION="23.04"
            ISO_FILE="ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"
            ISO_URL="https://releases.ubuntu.com/${UBUNTU_VERSION}/${ISO_FILE}"
            break
            ;;
        "Salir")
            echo "Saliendo..."
            exit 0
            ;;
        *) echo "Opción inválida $REPLY";;
    esac
done

# Variables generales
ISO_PATH="/var/lib/vz/template/iso/${ISO_FILE}"
VM_NAME="Ubuntu"
STORAGE="local"
MEMORY="1024"  # Ajusta según los requisitos de tu VM
DISK_SIZE="50G"  # Ajusta según los requisitos de tu VM
BRIDGE="vmbr0"

# Function to get the next available VM ID
get_next_vm_id() {
    local last_id=99  # Establecer el número base para la búsqueda
    for dir in /var/lib/vz/images/*/; do
        dir=${dir%/}  # Eliminar la barra al final
        vm_id=${dir##*/}  # Obtener el número de VM del directorio
        if [[ $vm_id =~ ^[0-9]+$ ]]; then
            if [ $vm_id -gt $last_id ]; then
                last_id=$vm_id
            fi
        fi
    done
    echo $((last_id + 1))  # Devolver el próximo número disponible
}

# Determine the next available VM ID
VM_ID=$(get_next_vm_id)

# Function to download the ISO
download_iso() {
    local url=$1
    echo "Attempting to download Ubuntu ISO from $url..."
    wget $url -O $ISO_PATH
    return $?
}

# Download the ISO if it doesn't exist
if [ ! -f $ISO_PATH ]; then
    download_iso $ISO_URL
    if [ $? -ne 0 ]; then
        echo "Failed to download the Ubuntu ISO from $ISO_URL. Aborting."
        exit 1
    fi
else
    echo "The ISO file $ISO_FILE already exists. Skipping download."
fi

# Verify the ISO integrity
echo "Verifying the integrity of the Ubuntu ISO..."
if ! sudo mount -o loop $ISO_PATH /mnt; then
    echo "Failed to mount the ISO file. Aborting."
    exit 1
fi

# Variables for VM creation
DISK_PATH="/var/lib/vz/images/$VM_ID/vm-$VM_ID-disk-0.raw"

# Create the VM directory if it doesn't exist
if [ ! -d "/var/lib/vz/images/$VM_ID" ]; then
    mkdir -p "/var/lib/vz/images/$VM_ID"
fi

# Create the disk file if it doesn't exist
if [ ! -f "$DISK_PATH" ]; then
    echo "Creating the disk file..."
    qemu-img create -f raw "$DISK_PATH" "$DISK_SIZE"
else
    echo "The disk file already exists."
fi

# Verify the creation of the disk file
if [ -f "$DISK_PATH" ]; then
    echo "Disk file created successfully."
else
    echo "Failed to create the disk file."
    exit 1
fi

# Create a new VM in Proxmox
echo "Creating a new VM in Proxmox..."
qm create $VM_ID --name "$VM_NAME" --memory "$MEMORY" --net0 virtio,bridge="$BRIDGE" --ostype l26 --scsihw virtio-scsi-pci

# Attach the disk to the VM
echo "Attaching the disk to the VM..."
qm set $VM_ID --scsi0 "$STORAGE:$VM_ID/vm-$VM_ID-disk-0.raw,size=$DISK_SIZE"

# Verify the creation and attachment of the disk
if qm config $VM_ID | grep -q "scsi0"; then
    echo "Disk attached successfully."
else
    echo "Failed to attach the disk."
    exit 1
fi

# Set the CD-ROM
echo "Setting the CD-ROM..."
qm set $VM_ID --ide2 "$STORAGE:iso/${ISO_FILE},media=cdrom"

# Set the boot order to prioritize CD-ROM first
echo "Setting boot order..."
qm set $VM_ID --boot order=ide2

# Start the VM
echo "Starting the VM..."
qm start $VM_ID

echo "Ubuntu VM created and started successfully."
