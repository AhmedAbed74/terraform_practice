provider "aws" {
   region = "eu-central-1" 
   
}

variable vpc_cidir_block {}
variable subnet_cidir_block {}
variable env_prefix {}
variable avail_zone {}
variable my_ip {}
variable instance_type {}
variable my_public_key {}

resource "aws_vpc" "my_vpc" {
    cidr_block = var.vpc_cidir_block
    tags= {
        Name: "${var.env_prefix}-vpc"
    }
  
}

resource "aws_subnet" "my_subnet" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = var.subnet_cidir_block
  availability_zone = var.avail_zone
  tags = {
    Name: "${var.env_prefix}-subnet-1"
  }
}

resource "aws_internet_gateway" "my_gateway" {
    vpc_id = aws_vpc.my_vpc.id  
}

resource "aws_route_table" "my_route" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_gateway.id
  }
   tags = {
    Name: "${var.env_prefix}-myroute"
    }
}

resource "aws_route_table_association" "rtb-subnet" {
    subnet_id = aws_subnet.my_subnet.id
    route_table_id = aws_route_table.my_route.id
  
}

resource "aws_security_group" "myapp-sg" {
    name = "myapp-sg"
    vpc_id = aws_vpc.my_vpc.id  

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }   
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }   
    egress {
        
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
   
    }
}

data "aws_ami" "latest-amazon-linux-image" {
    owners = ["amazon"]
    most_recent = true
    filter {
      name = "name"
      values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }
 
}  
resource "aws_key_pair" "ssh-key" {
    key_name = "server-key"
    public_key = "${file(var.my_public_key)}"
  
}
output "aws_ami_id" {
    value = data.aws_ami.latest-amazon-linux-image.id
}    

resource "aws_instance" "ec2" {

    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.instance_type

    subnet_id = aws_subnet.my_subnet.id
    vpc_security_group_ids = [aws_security_group.myapp-sg.id]
    
    availability_zone = var.avail_zone
    associate_public_ip_address = true 

    key_name = aws_key_pair.ssh-key.key_name
    user_data = <<EOF
                    #!/bin/bash
                    sudo yum update -y && sudo yum install -y docker
                    sudo systemctl start docker
                    sudo usermod -aG docker ec2-user
                    docker run -p 8080:80 nginx
                EOF

     tags = {
    Name: "${var.env_prefix}-my-ec2"
    }

} 