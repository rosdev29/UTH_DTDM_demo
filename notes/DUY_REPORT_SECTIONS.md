# NỘI DUNG BÁO CÁO - PHẦN CỦA DUY

Tài liệu này tổng hợp các mục do Duy phụ trách trong báo cáo đồ án.

## 1.3 Phạm vi và giới hạn

Trong đề tài này, phần hạ tầng tập trung triển khai mô hình CI/CD gọn nhẹ trên một máy ảo duy nhất, sử dụng Docker Compose và Nginx reverse proxy thay cho nền tảng orchestration phức tạp. Phạm vi triển khai bao gồm: cấu hình môi trường VM, tổ chức container theo chiến lược blue-green, script deploy/health-check/rollback, và các thiết lập bảo mật cơ bản ở mức VM và Docker.

Giới hạn của phạm vi:
- Hệ thống chạy trên single VM nên chưa tối ưu cho mở rộng ngang ở quy mô lớn.
- Chưa tích hợp đầy đủ stack quan sát tập trung (metrics, tracing, centralized logging).
- Quy trình CD còn giữ bước xác nhận thủ công qua ChatOps để đảm bảo an toàn vận hành trong bối cảnh đồ án.

Với mục tiêu học thuật, phạm vi này đạt được sự cân bằng giữa tính thực tế, khả năng triển khai nhanh và dễ trình diễn.

## 2.2 Docker

### 2.2.1 Kiến trúc Docker

Docker cung cấp lớp ảo hóa ở mức container, giúp chuẩn hóa môi trường chạy ứng dụng giữa các giai đoạn phát triển và triển khai. Trong kiến trúc đề tài, mỗi thành phần được đóng gói thành container riêng: `app-blue`, `app-green`, `nginx`. Cách tách lớp này giúp triển khai độc lập, rollback nhanh và giảm rủi ro ảnh hưởng chéo giữa các thành phần.

### 2.2.2 Dockerfile multi-stage

Mặc dù demo hiện tại dùng image Nginx tĩnh để minh họa blue-green rõ ràng, nguyên tắc multi-stage vẫn là thực hành khuyến nghị cho ứng dụng thật:
- Stage build dùng image đầy đủ toolchain để compile/test.
- Stage runtime chỉ chứa artifact và runtime tối thiểu.
- Giảm kích thước image, tăng tốc pull/deploy, giảm bề mặt tấn công bảo mật.

Trong lộ trình mở rộng, dự án nên chuẩn hóa Dockerfile multi-stage cho service backend chính.

### 2.2.3 Docker Compose

Docker Compose là công cụ điều phối các service trong môi trường demo:
- `app-blue`: môi trường đang phục vụ traffic.
- `app-green`: môi trường phiên bản mới để kiểm thử trước khi cắt traffic.
- `nginx`: reverse proxy public tại cổng `8080`, chuyển tiếp vào upstream active.

Compose giúp định nghĩa mạng nội bộ thống nhất, volume map cho nội dung demo `BLUE/GREEN`, và khởi tạo đồng bộ bằng một lệnh `docker compose up -d`.

### 2.2.4 Docker API và CLI

Vận hành được thực hiện thông qua Docker CLI:
- `docker compose up -d app-green`: khởi động phiên bản green.
- `docker compose exec -T nginx ...`: chạy health-check nội bộ trong network.
- `docker compose restart nginx`: nạp lại cấu hình định tuyến.
- `docker compose stop app-blue`: dừng phiên bản cũ sau khi cắt traffic.

Cách tiếp cận CLI rõ ràng, dễ tích hợp với script tự động và ChatOps command handler.

### 2.2.5 Quản lý trạng thái container

Dự án dùng trạng thái song song blue/green để quản lý vòng đời container:
1. Blue đang active.
2. Green được khởi động và kiểm tra sức khỏe.
3. Khi green đạt điều kiện, Nginx đổi upstream.
4. Blue được stop để giảm tài nguyên.
5. Khi có lỗi, rollback kích hoạt blue trở lại.

Cơ chế này giảm downtime và giúp thao tác rollback có tính quyết định, nhanh và dễ kiểm chứng.

## 2.3 VM và Cloud

### 2.3.1 Kiến trúc VM

Mô hình hạ tầng chọn kiến trúc single VM chạy Docker Engine:
- Hệ điều hành Ubuntu 22.04 LTS.
- Docker CE + Docker Compose v2.
- Nginx reverse proxy làm entry point duy nhất.
- App containers chỉ expose nội bộ qua Docker network.

Kiến trúc này phù hợp phạm vi đồ án do dễ setup, dễ vận hành và tối ưu chi phí.

### 2.3.2 AWS EC2/Azure VM

AWS EC2 và Azure VM đều là lựa chọn phù hợp để triển khai mô hình tương tự:
- AWS EC2 mạnh về hệ sinh thái và tài liệu cộng đồng.
- Azure VM thuận lợi khi tích hợp hệ sinh thái Microsoft.

Trong đồ án, nhóm ưu tiên môi trường VM có chi phí hợp lý và thao tác nhanh để demo. Thiết kế hạ tầng theo Docker Compose giúp giữ tính di động, có thể chuyển giữa GCP/AWS/Azure mà không đổi nhiều logic triển khai.

### 2.3.3 Cloud-init

Cloud-init là cơ chế bootstrap VM tự động ngay lần khởi tạo đầu tiên:
- Cài đặt package nền (Docker, Compose, monitoring cơ bản).
- Thiết lập user, SSH key, timezone, firewall mặc định.
- Giảm sai sót thao tác thủ công và tăng khả năng tái lập môi trường.

Đối với giai đoạn hiện tại, cloud-init được đề xuất như bước chuẩn hóa tiếp theo để rút ngắn thời gian dựng hạ tầng.

## 3.3.1 Sơ đồ kiến trúc 3 lớp (Lộc + Duy)

Kiến trúc tổng thể gồm 3 lớp:
1. **Control Plane**: GitHub Actions, Registry, OpenClaw Agent, Slack/ChatOps.
2. **Deployment Plane**: VM chạy Docker Compose và Nginx điều phối traffic.
3. **Runtime Plane**: cặp container `app-blue` và `app-green` phục vụ luân phiên.

Đóng góp phần hạ tầng của Duy tập trung vào lớp Deployment + Runtime, đảm bảo luồng chuyển đổi blue-green an toàn và có rollback.

### Hình 3.1 - Kiến trúc tổng thể hệ thống

![Hình 3.1 - Kiến trúc tổng thể hệ thống](C:/Users/acer/.cursor/projects/d-H-c-k-8-Cloud-Computing-BTL/assets/c__Users_acer_AppData_Roaming_Cursor_User_workspaceStorage_96a48877c6af9509a9307782e2cbecc4_images_DTDM-3.1.drawio-022778c1-9c0c-4cd7-8f55-cfc4f01d3be3.png)

### Hình 3.2 - Use Case hệ thống ChatOps

![Hình 3.2 - Use Case hệ thống ChatOps](C:/Users/acer/.cursor/projects/d-H-c-k-8-Cloud-Computing-BTL/assets/c__Users_acer_AppData_Roaming_Cursor_User_workspaceStorage_96a48877c6af9509a9307782e2cbecc4_images_DTDM-3.2.drawio-d83f8035-e0c7-463d-ad25-60313bc39ec8.png)

### Hình 3.3 - Sequence triển khai và rollback

![Hình 3.3 - Sequence triển khai và rollback](C:/Users/acer/.cursor/projects/d-H-c-k-8-Cloud-Computing-BTL/assets/c__Users_acer_AppData_Roaming_Cursor_User_workspaceStorage_96a48877c6af9509a9307782e2cbecc4_images_DTDM-3.3.drawio__1_-354803c9-2396-4497-a2aa-053717a33059.png)

### Hình 3.4 - Máy trạng thái của OpenClaw

![Hình 3.4 - Máy trạng thái của OpenClaw](C:/Users/acer/.cursor/projects/d-H-c-k-8-Cloud-Computing-BTL/assets/c__Users_acer_AppData_Roaming_Cursor_User_workspaceStorage_96a48877c6af9509a9307782e2cbecc4_images_DTDM-3.4.drawio__1_-3f46f0ee-1e6f-408d-85fa-3761e778fff8.png)

### Hình 3.5 - Kiến trúc triển khai Blue-Green tối giản

![Hình 3.5 - Kiến trúc triển khai Blue-Green tối giản](C:/Users/acer/.cursor/projects/d-H-c-k-8-Cloud-Computing-BTL/assets/c__Users_acer_AppData_Roaming_Cursor_User_workspaceStorage_96a48877c6af9509a9307782e2cbecc4_images_DTDM-3.5.drawio__2_-8eca4b75-42cd-474a-b093-3a2997e9181b.png)

## 3.4.3 Container Deployment Strategy

Chiến lược triển khai sử dụng blue-green deployment:
1. Start `app-green`.
2. Health-check trực tiếp `app-green` trong Docker network (không kiểm tra qua endpoint public để tránh false-positive).
3. Nếu pass, cập nhật upstream Nginx sang green và restart Nginx.
4. Stop `app-blue`.
5. Nếu fail ở bước health-check, quy trình dừng, giữ nguyên blue.

Rollback flow:
1. Chuyển upstream về blue.
2. Restart Nginx.
3. Start bảo đảm `app-blue` đang chạy.
4. Stop `app-green`.

Chiến lược này cho phép cập nhật phiên bản mới với rủi ro thấp và phục hồi nhanh khi có lỗi.

## 3.5 Bảo mật

### 3.5.1 VM Security

Các biện pháp bảo mật mức VM:
- Chỉ cho phép SSH bằng key, vô hiệu hóa đăng nhập password.
- Không cho phép root login trực tiếp.
- Giới hạn firewall chỉ mở `22`, `80`, `443`.
- Cập nhật bản vá bảo mật định kỳ.
- Tách tài khoản vận hành và nguyên tắc cấp quyền tối thiểu.

### 3.5.2 Docker Security

Các biện pháp bảo mật mức container:
- Không public trực tiếp cổng app nội bộ; chỉ public qua Nginx.
- Tách reverse proxy và app thành container riêng.
- Hạn chế đặc quyền container, ưu tiên non-root cho service ứng dụng thật.
- Không lưu secret trực tiếp trong source code; dùng biến môi trường hoặc secret store.
- Theo dõi log container phục vụ phát hiện sự cố.

## 4.1 Môi trường triển khai

### 4.1.1 Thông số VM

Cấu hình đề xuất:
- vCPU: 2-4 core
- RAM: 4-8 GB
- Disk: SSD 20 GB trở lên
- OS: Ubuntu 22.04 LTS

Cấu hình này đáp ứng tốt nhu cầu demo blue-green và kiểm thử script triển khai.

### 4.1.2 Phần mềm cài đặt

Danh sách phần mềm nền:
- Docker CE
- Docker Compose v2
- Nginx (container reverse proxy)
- PowerShell/Bash scripts cho deploy, health-check, rollback

### 4.1.3 Môi trường phát triển

Môi trường phát triển và kiểm thử:
- Local máy Windows với PowerShell.
- Docker Desktop để chạy stack container.
- Trình duyệt truy cập `http://localhost:8080` xác nhận trạng thái active.
- Terminal command kiểm chứng `HTTP 200` và log container.

## 4.4 Triển khai Deployment

### 4.4.1 Blue-Green

Hai môi trường chạy song song:
- `app-blue` hiển thị nhãn **BLUE**.
- `app-green` hiển thị nhãn **GREEN**.

Nhãn trực quan giúp xác minh tức thời container nào đang nhận traffic, hỗ trợ demo rõ ràng cho hội đồng.

### 4.4.2 Health Check Script

Health-check được triển khai cho cả Bash và PowerShell, có cơ chế retry:
- Kiểm tra trạng thái HTTP nhiều lần với khoảng nghỉ giữa các lần thử.
- Hỗ trợ kiểm tra endpoint public hoặc kiểm tra nội bộ qua network của Nginx container.
- Triển khai hiện tại dùng kiểm tra trực tiếp `app-green` trước khi switch.

### 4.4.3 Rollback Automation (Duy + Lộc)

Rollback script thực hiện các bước:
1. Đổi cấu hình Nginx upstream về blue.
2. Restart Nginx áp dụng cấu hình mới.
3. Đảm bảo `app-blue` chạy ổn định.
4. Dừng `app-green`.

Kết quả kiểm thử cho thấy rollback thành công, endpoint luôn duy trì khả dụng và phản hồi `HTTP 200`.

## Phụ lục C - Hướng dẫn chạy demo

### C.1 Chuẩn bị
- Cài Docker Desktop (Windows) hoặc Docker CE + Compose v2 (Ubuntu).
- Mở terminal tại thư mục `UTH_DTDM_demo`.

### C.2 Khởi động hệ thống
```powershell
docker compose up -d
docker compose ps
```

### C.3 Deploy sang GREEN
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1
curl.exe -I http://localhost:8080
```
- Truy cập `http://localhost:8080`, giao diện hiển thị nhãn **GREEN**.

### C.4 Rollback về BLUE
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\rollback.ps1
curl.exe -I http://localhost:8080
```
- Refresh trang, giao diện hiển thị nhãn **BLUE**.

### C.5 Kiểm tra nhanh trạng thái
```powershell
curl.exe -s http://localhost:8080 | findstr GREEN
curl.exe -s http://localhost:8080 | findstr BLUE
```

### C.6 Xử lý lỗi nhanh
```powershell
docker compose ps
docker compose logs --tail=100 nginx app-blue app-green
```

