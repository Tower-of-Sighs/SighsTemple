# SighsTemple

空白的 `common + targets/<loader>-<minecraft-version>` Minecraft 开发模板。

默认包名与 Gradle group 为 `cc.sighs.temple`，默认 mod id 为 `temple`。

快速迁移请对 AI 这么说：

“使用 https://github.com/Tower-of-Sighs/SighsTemple 框架来重构本项目，第一步先将当前mc版本的所有源码及资源迁移至common部分，第二步将明确查询源码证实了存在明显版本差异的内容转移到targets中的对应版本下，第三步搭建spi模式，将targets中的内容抽象化，只保留具体实现差异，共通逻辑迁移回common部分，第四步将当前targets下的主版本内容移植到全部所有版本。”

## 初始化新项目

`scripts/init-project.ps1` 把模板一次性改写成具体项目：包路径、主类名、mod id、`gradle.properties` 的 `mod_*`、metadata 引用、`assets/<mod id>` 与文档中的项目名都会替换。

```powershell
.\scripts\init-project.ps1 `
    -ProjectName 'Ember Sanctum' `
    -Package 'com.example.ember' `
    -Author 'Zhang San' `
    -License 'MIT' `
    -Description '一个示例模组。'
```

- `ProjectName` 同时用作 `mod_name`、根工程名和主类前缀：`Ember Sanctum` 会得到 `EmberSanctumCommon`、`EmberSanctumForge`、`EmberSanctumFabric`、`EmberSanctumNeoForge121`、`EmberSanctumNeoForge261`。
- `-ModId` 可省略，默认取 `ProjectName` 去掉非 `[a-z0-9_]` 字符后的小写形式；不合适时显式传入。
- 省略参数时 PowerShell 会交互提示输入。
- 脚本只对未初始化的模板运行一次，已初始化会直接报错退出。
- 作者、简介中的非 ASCII 字符以 `\uXXXX` 写入 `gradle.properties`，因为 Gradle 按 ISO-8859-1 读取 properties。
- 初始化后旧的 `build/` 产物仍在，执行一次 `clean build` 即可。

## IDEA

直接打开任意 `targets/<loader>-<version>/` 目录。IDEA 会导入当前 target，并把 `../../common` 作为 composite build 的独立可编辑模块一起导入，只下载该 target 的加载器和 Minecraft 依赖。

## Target

| Target | Gradle JVM | 构建命令 |
| --- | --- | --- |
| `forge-1.20.1` | JDK 21 | `targets\forge-1.20.1\.\gradlew.bat clean build` |
| `forge-1.19.2` | JDK 21 | `targets\forge-1.19.2\.\gradlew.bat clean build` |
| `forge-1.18.2` | JDK 21 | `targets\forge-1.18.2\.\gradlew.bat clean build` |
| `fabric-1.20.1` | JDK 17 | `targets\fabric-1.20.1\.\gradlew.bat clean build` |
| `fabric-1.21.1` | JDK 21 | `targets\fabric-1.21.1\.\gradlew.bat clean build` |
| `fabric-26.1` | JDK 25 | `targets\fabric-26.1\.\gradlew.bat clean build` |
| `neoforge-1.21.1` | JDK 21 | `targets\neoforge-1.21.1\.\gradlew.bat clean build` |
| `neoforge-26.1` | JDK 25 | `targets\neoforge-26.1\.\gradlew.bat clean build` |

根项目默认只同步 `common`。使用 JDK 21 时可选择性构建全部 JDK 21 target：

```powershell
.\gradlew.bat '-Ptarget=forge-1.20.1' build
.\gradlew.bat '-Ptarget=fabric-1.20.1' build
.\gradlew.bat -PallTargets=true build
```

`fabric-26.1` 与 `neoforge-26.1` 因 JDK 25 与 Gradle 9 要求独立构建。

## 结构

- `common/`: 所有没有确证版本差异的共享代码与共享资源，可以引用 Minecraft 与 loader 类型。
- `targets/*`: loader 和版本专属入口、metadata、资源及 API 适配。
- `gradle/target-conventions/publish.gradle`: 所有 target 共用的发布约定。

每个 target 通过 source-set sharing 把 `../../common/src/main/java`（由 `prepareCommonSources` 同步到生成目录）直接编译进自己的源码集，因此 `common` 既能在任意 target 内被独立编辑，也能单独构建：

```powershell
.\gradlew.bat -p common build
```

经源码确证在某个 target 上存在版本差异的 common 文件，在该 target 的 `prepareCommonSources` 中 `exclude` 对应路径，并由该 target 提供自己的实现。

## 共享资源

将所有加载器和版本共用的资源放在 `common/src/main/resources/`。构建任意 target 时，该目录会与 target 自己的 `src/main/resources/` 合并并写入最终 jar。

加载器 metadata 仍必须保留在 target 中：Fabric 使用 `fabric.mod.json`，Forge 使用 `META-INF/mods.toml`，NeoForge 使用 `META-INF/neoforge.mods.toml`。

## 本地依赖

每个 target 都会自动将自身 `libs/` 目录中的 `*.jar` 作为 `implementation` 依赖。将 jar 放入对应目录后不需要在 `build.gradle` 中逐条声明；`*-sources.jar` 和 `*-javadoc.jar` 会被忽略。

```text
targets/forge-1.20.1/libs/
targets/forge-1.19.2/libs/
targets/forge-1.18.2/libs/
targets/fabric-1.20.1/libs/
targets/fabric-1.21.1/libs/
targets/fabric-26.1/libs/
targets/neoforge-1.21.1/libs/
targets/neoforge-26.1/libs/
```

本地 jar 的传递依赖无法自动推导。若某个 jar 还依赖其他库，需要将这些库也放入同一个 `libs/` 目录，或按常规方式声明依赖。

## 发布

每个 target 都提供 `publishMods`，可手动发布其自身的产物至 CurseForge 与 Modrinth。两个平台的项目 ID 是所有 target 共用的非敏感信息，在根 `gradle.properties` 中取消注释并填写：

```properties
publish_curseforge_project_id=你的CurseForge项目ID
publish_modrinth_project_id=你的Modrinth项目ID
```

token 只从环境变量读取，不要写入仓库。PowerShell 示例：

```powershell
$env:CURSEFORGE_TOKEN = '...'
$env:MODRINTH_TOKEN = '...'
$env:PUBLISH_CHANGELOG = '本次版本的更新说明' # 可选

cd targets\forge-1.20.1
.\gradlew.bat publishMods
```

将目录替换为其他 target 即可单独发布对应加载器和 Minecraft 版本。Fabric 会上传重映射后的 jar；Forge 与 NeoForge 上传各自的最终 jar。

`publish` 任务会把 target 的 Java component 发布到 Sighs Maven 仓库，细节见 [Publishing](docs/PUBLISHING.md)。

## 版本参考

- [Minecraft 1.20.1、1.21.1、26.1 完整迁移差异参考](docs/version-differences/README.md)
- [多版本日常维护工作流](docs/MAINTENANCE_WORKFLOW.md)
- [Target CI 自动发现](docs/CI_TARGET_DISCOVERY.md)
