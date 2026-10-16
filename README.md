# Bar Assistant 的懒猫 LPK 打包仓库

懒猫微服应用 `cloud.lazycat.app.bar-assistant` 的打包工程。定时检查上游镜像
`docker.io/barassistant/server` 的 6.x 版本并自动构建与提审。

- 上游：https://github.com/karlomikus/bar-assistant（MIT）
- 跟随版本的镜像：`docker.io/barassistant/server`（`bar-assistant` 与 `bar-init` 两个 service）
- 不跟随版本：salt-rim、meilisearch
- 平台凭据：仓库 Secret `LZC_API_TOKEN`
