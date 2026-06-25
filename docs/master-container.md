# IP-Sentinel Master 容器化部署

该镜像以无 systemd 的方式运行 Master 长轮询服务。所有运行时状态都保存在 `/opt/ip_sentinel_master`，迁移和备份时只需要处理这个卷。

## 构建镜像

```bash
docker build -f master/Dockerfile -t ip-sentinel-master:4.3.1 .
```

## GitHub Actions 打包

仓库内的 `.github/workflows/master_container.yml` 会在 `main` 分支相关文件变更、推送 `v*` 标签或手动触发时，自动构建并推送多架构镜像到 GitHub Container Registry：

```text
ghcr.io/<github-owner>/ip-sentinel-master:latest
ghcr.io/<github-owner>/ip-sentinel-master:4.3.1
```

推送到 `Copperchaleu/IP-Sentinel` 后，镜像地址会是：

```text
ghcr.io/copperchaleu/ip-sentinel-master:latest
ghcr.io/copperchaleu/ip-sentinel-master:4.3.1
```

## 首次启动

```bash
docker run -d \
  --name ip-sentinel-master \
  --restart unless-stopped \
  -e TG_TOKEN="123456:replace_me" \
  -e MASTER_NODE_NAME="IP-Sentinel-Master" \
  -v ip-sentinel-master-data:/opt/ip_sentinel_master \
  ip-sentinel-master:4.3.1
```

也可以使用 Compose：

```bash
cat > .env <<'EOF'
TG_TOKEN=123456:replace_me
MASTER_NODE_NAME=IP-Sentinel-Master
TZ=Asia/Shanghai
EOF

docker compose -f docker-compose.master.yml up -d --build
```

## 备份

```bash
docker stop ip-sentinel-master

docker run --rm \
  -v ip-sentinel-master-data:/data:ro \
  -v "$PWD:/backup" \
  debian:bookworm-slim \
  tar czf /backup/ip-sentinel-master-backup.tgz -C /data .

docker start ip-sentinel-master
```

备份包包含：

- `master.conf`
- `sentinel.db`
- SQLite WAL/SHM 文件，如果存在
- `.tg_offset`
- 运行期 `tg_master.sh`

## 恢复或迁移

```bash
docker volume create ip-sentinel-master-data

docker run --rm \
  -v ip-sentinel-master-data:/data \
  -v "$PWD:/backup:ro" \
  debian:bookworm-slim \
  tar xzf /backup/ip-sentinel-master-backup.tgz -C /data

docker compose -f docker-compose.master.yml up -d
```

## 从裸机 Master 迁入容器

在旧机器上执行：

```bash
systemctl stop ip-sentinel-master.service 2>/dev/null || true
tar czf ip-sentinel-master-backup.tgz -C /opt/ip_sentinel_master .
```

把 `ip-sentinel-master-backup.tgz` 复制到新机器后执行：

```bash
docker volume create ip-sentinel-master-data

docker run --rm \
  -v ip-sentinel-master-data:/data \
  -v "$PWD:/backup:ro" \
  debian:bookworm-slim \
  tar xzf /backup/ip-sentinel-master-backup.tgz -C /data

docker compose -f docker-compose.master.yml up -d --build
```

## 注意事项

- 容器模式默认关闭 Master OTA。升级时建议拉取新代码、重建镜像、重启容器。
- 首次启动必须提供 `TG_TOKEN`。卷内已存在 `master.conf` 后，会优先使用保存的配置。
- 如果需要主动用环境变量覆盖配置，启动一次时加入 `UPDATE_CONFIG_FROM_ENV=true`。
