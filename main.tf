# 1. AWS 리전 설정
provider "aws" {
  region = "ap-northeast-2"
}

# 2. Lightsail 인스턴스 생성 (4GB RAM, 2 vCPU)
resource "aws_lightsail_instance" "bigbang_server" {
  name              = "doctory-mvp-bigbang"
  availability_zone = "ap-northeast-2a"
  blueprint_id      = "ubuntu_22_04" # OS: Ubuntu 22.04 LTS
  bundle_id         = "medium_3_0"   # 사양: 4GB RAM / 2 vCPU

  # [추가] AWS 콘솔에 등록된 키 페어의 이름을 정확히 입력합니다.
  key_pair_name     = "doctory-key" 
}

# 3. 고정 IP 생성 
resource "aws_lightsail_static_ip" "main_ip" {
  name = "doctory-static-ip"
}

# 4. 고정 IP를 인스턴스에 연결
resource "aws_lightsail_static_ip_attachment" "ip_attach" {
  static_ip_name = aws_lightsail_static_ip.main_ip.name
  instance_name  = aws_lightsail_instance.bigbang_server.name
}

# 5. 방화벽 설정
resource "aws_lightsail_instance_public_ports" "firewall" {
  instance_name = aws_lightsail_instance.bigbang_server.name

  port_info {
    protocol  = "tcp"
    from_port = 22   # SSH 접속용
    to_port   = 22
  }

  port_info {
    protocol  = "tcp"
    from_port = 80   # FE 접속용 (HTTP)
    to_port   = 80
  }

  port_info {
    protocol  = "tcp"
    from_port = 443  # HTTPS 접속용
    to_port   = 443
  }
}

# 6. 결과 출력
output "public_ip" {
  value = aws_lightsail_static_ip.main_ip.ip_address
}