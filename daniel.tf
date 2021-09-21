provider "aws" {
  profile = "Daniel_Minecraft"
  region = "eu-west-2"
}

variable "my_ip" {
    type = string
    description = "My IP Address"
    sensitive = true
}

# Ubuntu Server AMI
#  ami-0194c3e07668a7e36 (64-bit x86) / ami-0960f1036d6edacf5 (64-bit Arm)

resource "aws_vpc" "Daniel_VPC_tf" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Daniel_VPC"
    costcenter = "Daniel"
    managed_by = "terraform"
  }
}

resource "aws_internet_gateway" "Daniel_VPC_Gateway_tf" {
  vpc_id = aws_vpc.Daniel_VPC_tf.id
  tags = {
    Name = "Daniel_VPC_Gateway"
    costcenter = "Daniel"
    managed_by = "terraform"
  }
}

resource "aws_route_table" "Daniel_Route_Table_tf" {
  vpc_id = aws_vpc.Daniel_VPC_tf.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Daniel_VPC_Gateway_tf.id
  }
  
  tags = {
    Name = "Daniel_VPC_Route_Table"
    costcenter = "Daniel"
    managed_by = "terraform"
  }
}

resource "aws_subnet" "Daniel_Subnet_tf" {
  vpc_id = aws_vpc.Daniel_VPC_tf.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "Daniel_Subnet"
    costcenter = "Daniel"
    managed_by = "terraform"
  }
  availability_zone = "eu-west-2a"
  # This is to prevent errors where the availability zone is different throughout deployment
  # I assume but don't know whether this can be set dynamically with 'depends on' and attributes
}

resource "aws_route_table_association" "Daniel_Route_Table_Association_tf" {
  subnet_id = aws_subnet.Daniel_Subnet_tf.id
  route_table_id = aws_route_table.Daniel_Route_Table_tf.id
  # tags = {
  #   Name = "Daniel_Route_Table_association"
  #   costcenter = "Daniel"
  #   managed_by = "terraform"
  # }
}

resource "aws_security_group" "Daniel_Security_Group_tf" {
  name = "Daniel_MC_SG"
  description = "Allows SSH Traffic and Minecraft Traffic"
  vpc_id = aws_vpc.Daniel_VPC_tf.id

  ingress {
      cidr_blocks = [ var.my_ip ]
      description = "Allow SSH Traffic"
      from_port = 22
      protocol = "tcp"
      to_port = 22
    }
    ingress {
      cidr_blocks = [ "0.0.0.0/0" ]
      description = "Allow Minecraft Traffic"
      from_port = 25565
      protocol = "tcp"
      to_port = 25565
    }
    ingress {
      cidr_blocks = [ "0.0.0.0/0" ]
      description = "Allow Minecraft UDP Traffic"
      from_port = 19132
      protocol = "udp"
      to_port = 19132
    }
  # egress {
  #     cidr_blocks = [ var.my_ip ]
  #     description = "Allow SSH Traffic"
  #     from_port = 22
  #     protocol = "tcp"
  #     to_port = 22
  #   }
  egress {
      cidr_blocks = [ "0.0.0.0/0" ]
      description = "Allow Minecraft Traffic"
      from_port = 25565
      protocol = "tcp"
      to_port = 25565
    } 
  egress {
      cidr_blocks = [ "0.0.0.0/0" ]
      description = "Allow Minecraft UDP Traffic"
      from_port = 19132
      protocol = "udp"
      to_port = 19132
    } 
  egress {
      cidr_blocks = [ "0.0.0.0/0" ]
      description = "Allow HTTP Traffic"
      from_port = 80
      protocol = "tcp"
      to_port = 80
    } 
  egress {
      cidr_blocks = [ "0.0.0.0/0" ]
      description = "Allow wget Traffic"
      from_port = 443
      protocol = "tcp"
      to_port = 443
    } 
  egress {
      cidr_blocks = [ "0.0.0.0/0" ]
      description = "Allow DNS Traffic"
      from_port = 53
      protocol = "udp"
      to_port = 53
    } 
  # egress {
  #     cidr_blocks = [ "0.0.0.0/0" ]
  #     description = "Allow Git Traffic"
  #     from_port = 9418
  #     protocol = "tcp"
  #     to_port = 9418
  #   } 
  tags = {
    Name = "Daniel_Minecraft_SG"
    costcenter = "Daniel"
    managed_by = "terraform"
  }
}

resource "aws_network_interface" "Daniel_Network_Interface_tf" {
  subnet_id = aws_subnet.Daniel_Subnet_tf.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.Daniel_Security_Group_tf.id]

  tags = {
    Name = "Daniel_Subnet"
    costcenter = "Daniel"
    managed_by = "terraform"
  }
}

resource "aws_eip" "Daniel_Elastic_IP_tf" {
  instance = aws_instance.Daniel_Server_tf.id
  network_interface = aws_network_interface.Daniel_Network_Interface_tf.id
  associate_with_private_ip = "10.0.1.50"
  vpc = true
  # Note this has to happen after IG: and references full object
  depends_on = [
    aws_internet_gateway.Daniel_VPC_Gateway_tf
  ]
  tags = {
    Name = "Daniel_EIP"
    costcenter = "Daniel"
    managed_by = "terraform"
  }
}

resource "aws_instance" "Daniel_Server_tf" {
  ami = "ami-0194c3e07668a7e36"
  instance_type = "t3a.medium"
  tags = {
      Name = "Daniel_Server"
      costcenter = "Daniel"
      managed_by = "terraform"
  }
  availability_zone = "eu-west-2a"
  key_name = "Daniel_Minecraft"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.Daniel_Network_Interface_tf.id
  }

 user_data = <<-EOF
              #!/bin/bash
              # update system and install git
              sudo apt update -y

              # add user mc, with permissions in /minecraft
              sudo useradd --no-create-home mc
              sudo mkdir /minecraft
              sudo chown mc /minecraft

              # download & install openjdk16
              sudo add-apt-repository ppa:linuxuprising/java -y

              sudo apt update

              wget --no-check-certificate -c --header "Cookie: oraclelicense=accept-securebackup-cookie" https://download.oracle.com/otn-pub/java/jdk/16.0.2+7/d4a915d82b4c4fbb9bde534da945d746/jdk-16.0.2_linux-x64_bin.tar.gz -P /home/ubuntu/
              sudo mkdir /usr/lib/jvm
              cd /usr/lib/jvm
              sudo tar -xvzf /home/ubuntu/jdk-16.0.2_linux-x64_bin.tar.gz
              sudo sed -e 's|PATH="\(.*\)"|PATH="/opt/jdk1.6.0_45/bin:\1"\nJAVA_HOME="/usr/lib/jvm/jdk-16.0.2"|g' -i /etc/environment
              sudo update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk-16.0.2/bin/java" 0
              sudo update-alternatives --install "/usr/bin/javac" "javac" "/usr/lib/jvm/jdk-16.0.2/bin/javac" 0
              sudo update-alternatives --set java /usr/lib/jvm/jdk-16.0.2/bin/java
              sudo update-alternatives --set javac /usr/lib/jvm/jdk-16.0.2/bin/javac

              sudo apt-get install git -y

              # clone vanilla base git repo
              git clone https://github.com/jhculb/Vanilla-MC-Server-Base.git /minecraft

              # move minecraft.service
              sudo mv /minecraft/minecraft.service /etc/systemd/system/
              sudo chmod 644 /etc/systemd/system/minecraft.service

              # copy minecraft service conf.d
              sudo mkdir /etc/conf.d
              sudo mv /minecraft/minecraft /etc/conf.d/

              # start service
              sudo systemctl start minecraft

              # enable service
              sudo systemctl enable minecraft
              EOF
}