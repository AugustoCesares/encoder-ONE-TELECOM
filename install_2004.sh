#!/bin/bash
set -e
echo "--- [1/7] Atualizando Sistema (Ubuntu 20.04) ---"
sudo apt-get update
sudo apt-get install -y git curl build-essential wget gcc make
echo "--- [2/7] Preparando Kernel e Vídeo ---"
sudo bash -c "echo blacklist nouveau > /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo bash -c "echo options nouveau modeset=0 >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo update-initramfs -u
echo "Parando interface gráfica..."
sudo service gdm3 stop || sudo service lightdm stop || true
sudo rmmod nouveau || true
echo "--- [3/7] Instalando Driver Nvidia + CUDA 12.6 ---"
CUDA_FILE="cuda_12.6.1_560.35.03_linux.run"
if [ ! -f "$CUDA_FILE" ]; then
    echo "Baixando driver Nvidia (pode demorar)..."
    wget https://developer.download.nvidia.com/compute/cuda/12.6.1/local_installers/$CUDA_FILE
fi
chmod +x $CUDA_FILE
sudo ./$CUDA_FILE --override --driver --toolkit --silent
echo "--- [4/7] Instalando Docker ---"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
else
    echo "Docker já instalado."
fi
echo "--- [5/7] Instalando Docker Compose ---"
sudo curl -SL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
sudo mkdir -p /opt/ssl /opt/conf
sudo chmod 755 /opt/ssl /opt/conf
echo "--- [6/7] Configurando Nvidia Container Toolkit ---"
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
&& curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
&& curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | \
sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
echo "--- [7/7] Build da Imagem, Patch e Deploy ---"
cd /usr/local/src/docker_install_ole || { echo "Pasta não encontrada!"; exit 1; }
echo "Construindo imagem Docker..."
sudo docker build -t cooliobr/local:1.0 .
echo "Aplicando Patch Nvidia..."
wget https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh -O patch.sh
chmod +x patch.sh
sudo ./patch.sh
echo "Iniciando Containers..."
sudo docker-compose -f docker-compose-encoder.yml up -d
echo "=== Instalação Concluída no Ubuntu 20.04! ==="
