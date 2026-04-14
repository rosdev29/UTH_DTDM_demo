# Bản nháp báo cáo - Phần Duy (Infrastructure & Design)

## 1.3 Phạm vi và giới hạn (Infrastructure)

Phần hạ tầng của đề tài tập trung xây dựng một môi trường triển khai CI/CD gọn nhẹ trên một máy ảo duy nhất, không sử dụng Kubernetes. Phạm vi thực hiện bao gồm: cấu hình VM, Docker runtime, Docker Compose cho mô hình blue-green, Nginx reverse proxy, script vận hành triển khai/rollback, và các biện pháp bảo mật cơ bản cho VM và container.

Giới hạn của phần triển khai:
- Hệ thống chạy trên single VM nên chưa hướng tới khả năng mở rộng ngang ở quy mô lớn.
- Chưa tích hợp đầy đủ bộ quan sát nâng cao (distributed tracing, centralized metrics stack).
- Cơ chế tự động hóa CI mới dừng ở build/push image; triển khai được kích hoạt thủ công qua ChatOps để đảm bảo an toàn vận hành.

Trong phạm vi đồ án sinh viên, cách tiếp cận này đáp ứng tốt mục tiêu: đơn giản, dễ triển khai, dễ demo và có khả năng rollback rõ ràng.

## 2.2 Docker

### 2.2.1 Vai trò của Docker trong kiến trúc đề tài

Docker là lớp chuẩn hóa môi trường chạy ứng dụng giữa các giai đoạn phát triển và triển khai. Thay vì cài thủ công dependency trên máy chủ, ứng dụng được đóng gói thành image để đảm bảo tính nhất quán, giúp giảm lỗi khác biệt môi trường.

Lợi ích chính của Docker trong đề tài:
- Đóng gói ứng dụng độc lập, dễ tái sử dụng.
- Triển khai nhanh bằng thao tác pull image và start container.
- Hỗ trợ rollback thuận tiện khi phiên bản mới không đạt yêu cầu.
- Phù hợp với kiến trúc gọn nhẹ trên single VM.

### 2.2.2 Docker Compose và mô hình blue-green

Docker Compose được dùng để điều phối nhiều service cùng lúc gồm `app-blue`, `app-green` và `nginx`. Trong đó:
- `app-blue`: phiên bản đang phục vụ.
- `app-green`: phiên bản mới để kiểm thử trước khi cắt traffic.
- `nginx`: reverse proxy đứng trước, điều hướng traffic vào backend active.

Luồng blue-green:
1. Khởi chạy `app-green`.
2. Chạy health check xác nhận hoạt động.
3. Nếu đạt điều kiện, cập nhật upstream Nginx sang green.
4. Dừng `app-blue`.
5. Nếu thất bại, rollback về blue.

Mô hình này giúp giảm downtime, tăng độ an toàn khi cập nhật phiên bản mới.

### 2.2.3 Mẫu `docker-compose.yml` cho blue-green

```yaml
services:
  app-blue:
    image: nginxdemos/hello:latest
    container_name: app-blue
    restart: unless-stopped
    expose:
      - "80"
    networks:
      - app_net

  app-green:
    image: nginxdemos/hello:latest
    container_name: app-green
    restart: unless-stopped
    expose:
      - "80"
    networks:
      - app_net

  nginx:
    image: nginx:alpine
    container_name: edge-nginx
    restart: unless-stopped
    depends_on:
      - app-blue
      - app-green
    ports:
      - "8080:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    networks:
      - app_net

networks:
  app_net:
    driver: bridge
```

### 2.2.4 Quy trình quản lý và triển khai image với Docker Compose

Trong kiến trúc đề tài, GitHub Actions chỉ đảm nhận build và push Docker image lên registry. Quá trình triển khai không kích hoạt tự động, mà được khởi phát bởi người vận hành qua ChatOps để tăng kiểm soát.

Quy trình triển khai:
1. Nhận image mới từ registry (tag `latest` hoặc commit SHA).
2. Khởi động `app-green` bằng image mới.
3. Chạy health check.
4. Nếu healthy, Nginx chuyển upstream sang green.
5. Dừng `app-blue`.
6. Nếu fail, giữ blue và rollback.

### 2.2.5 Quản lý tài nguyên, log và best practices

Trong demo, container sử dụng chính sách `restart: unless-stopped` để tăng khả năng tự phục hồi. Ngoài ra:
- Chỉ mở cổng public tại Nginx; app nội bộ dùng `expose`.
- Tách reverse proxy và ứng dụng để dễ theo dõi sự cố.
- Chuẩn hóa script `deploy`, `health-check`, `rollback`.
- Ghi nhận log theo từng bước phục vụ debug và báo cáo.

## 2.3 VM và Cloud

### 2.3.1 Lý do chọn VM thay vì Kubernetes

Đề tài ưu tiên tính gọn nhẹ và khả năng hoàn thành trong phạm vi học thuật. Vì vậy, single VM phù hợp hơn Kubernetes ở giai đoạn này.

Bảng so sánh tóm tắt:

| Tiêu chí | Single VM + Docker Compose | Kubernetes |
|---|---|---|
| Độ phức tạp triển khai | Thấp | Cao |
| Độ phức tạp vận hành | Thấp đến vừa | Cao |
| Phù hợp phạm vi sinh viên | Cao | Trung bình |
| Chi phí ban đầu | Thấp | Cao hơn do overhead |
| Tốc độ vào demo | Nhanh | Chậm hơn |

Kết luận: chọn VM là tối ưu cho mục tiêu đồ án hiện tại; Kubernetes phù hợp hơn khi hệ thống mở rộng quy mô production lớn.

### 2.3.2 Cấu hình VM đề xuất

- Cloud: Google Cloud Platform (GCP)
- Dịch vụ: Compute Engine
- Loại máy: C2
- Hệ điều hành: Ubuntu 22.04 LTS
- Runtime: Docker CE, Docker Compose v2
- Reverse proxy: Nginx
- Lưu trữ: SSD 20GB (tối thiểu), tách volume cho log và dữ liệu trạng thái

### 2.3.3 Network và firewall

Thiết lập mạng theo nguyên tắc tối thiểu quyền:
- Mở `22/tcp` cho SSH (ưu tiên giới hạn IP nguồn).
- Mở `80/tcp` cho HTTP.
- Mở `443/tcp` cho HTTPS (khi cấu hình TLS).
- Không public trực tiếp cổng nội bộ của ứng dụng.

Mẫu firewall cơ bản (UFW):

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

## 3.4.3 Container Deployment Strategy: Blue-Green, Health Check, Rollback

Hệ thống áp dụng blue-green deployment với hai container ứng dụng:
- `app-blue`: phiên bản hiện tại.
- `app-green`: phiên bản mới.

Mẫu cấu hình Nginx upstream:

```nginx
events {}

http {
  upstream app_backend {
    server app-blue:80;
    # server app-green:80;
  }

  server {
    listen 80;
    server_name _;

    location / {
      proxy_pass http://app_backend;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }
  }
}
```

### Luồng triển khai
1. Start `app-green`.
2. Chạy health check.
3. Nếu pass, chuyển Nginx upstream sang green.
4. Restart Nginx.
5. Stop `app-blue`.

### Luồng rollback
1. Chuyển upstream về blue.
2. Restart Nginx.
3. Start lại `app-blue` (nếu cần).
4. Stop `app-green`.

### Kết quả kiểm thử demo
- Deploy thành công, health check pass.
- Rollback thành công, blue hoạt động trở lại.
- Kiểm tra bằng `curl -I` trả `HTTP/1.1 200 OK` trước và sau rollback.

## 3.5 Bảo mật

### 3.5.1 Bảo mật VM
- Dùng SSH key, tắt đăng nhập password.
- Không cho phép root login trực tiếp qua SSH.
- Cấu hình firewall tối thiểu cổng cần thiết.
- Cập nhật bản vá bảo mật định kỳ.

### 3.5.2 Bảo mật Docker
- Ưu tiên chạy container với non-root user.
- Không expose trực tiếp cổng app nội bộ ra Internet.
- Quản lý secrets tách khỏi source code.
- Theo dõi log để phát hiện bất thường và sự cố vận hành.

## 4.1 Môi trường triển khai

### 4.1.1 Hạ tầng phần cứng và hệ điều hành
- VM: GCP Compute Engine C2
- OS: Ubuntu 22.04 LTS
- Disk: SSD 20GB

### 4.1.2 Phần mềm nền tảng
- Docker CE
- Docker Compose v2
- Nginx reverse proxy

### 4.1.3 Kết quả triển khai cơ bản
- `docker compose up -d` khởi động thành công các service.
- Nginx phục vụ traffic ổn định qua cổng public.
- Sau deploy/rollback, endpoint luôn phản hồi `HTTP 200`.

## 4.4 Triển khai deployment (phần Docker/script)

### 4.4.1 Script deploy
- `deploy.ps1`/`deploy.sh` đảm nhiệm: start green -> health check -> switch traffic -> stop blue.

### 4.4.2 Script health check
- `health-check.ps1`/`health-check.sh` kiểm tra endpoint theo số lần retry cấu hình trước.

### 4.4.3 Script rollback
- `rollback.ps1`/`rollback.sh` chuyển traffic về blue và dừng green khi có lỗi.

Các script đã được kiểm thử trong demo và cho kết quả ổn định.

## Phụ lục C - Hướng dẫn cài đặt và chạy thử

1. Cài Docker Desktop (Windows) hoặc Docker CE + Compose (Ubuntu).
2. Clone repo demo và di chuyển vào thư mục dự án.
3. Chạy `docker compose up -d`.
4. Kiểm tra trạng thái bằng `docker compose ps`.
5. Chạy deploy: `powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1`.
6. Chạy rollback: `powershell -ExecutionPolicy Bypass -File .\scripts\rollback.ps1`.
7. Kiểm tra dịch vụ: `curl -I http://localhost:8080`.
