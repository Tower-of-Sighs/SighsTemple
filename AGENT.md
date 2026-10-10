# SighsTemple 开发与迁移规范

本仓库使用 `common + targets/<loader>-<minecraft-version>` 结构维护多个 Minecraft 加载器和版本。任何开发者或自动化代理在修改前都必须遵守本文件；更完整的协作、评审和 CI 规则见 [docs/MAINTENANCE_WORKFLOW.md](docs/MAINTENANCE_WORKFLOW.md)。

## 架构边界

```text
common/                         无确证版本差异的共享源码树与共享资源
targets/<loader>-<mc-version>/  一个独立的加载器 + Minecraft 版本工程
gradle/target-conventions/      所有 target 共用的构建约定
```

- `common` 放所有没有确证版本差异的代码，包括引用 Minecraft 与 loader 类型的那部分；依赖平台类型不是拆分理由，Java 版本也不是。
- `targets/*` 只放该 target 的入口、注册、事件、Minecraft API、Mixin、网络、渲染和 metadata。
- 每个 target 通过 `includeBuild('../../common')` 把 `common` 作为 composite build 导入 IDE（仅让 IDE 把 `common` 当作独立可编辑模块，不产生 Gradle 项目依赖）；再用 source-set sharing 把共享源码编译进自己：`prepareCommonSources` 这个 `Sync` 任务把 `../../common/src/main/java` 同步到 `$buildDir/generated/common-main` 并加入 main 源码集，test 源码集加入 `../../common/src/test/java` 与 `../../common/src/test/resources`。target 不依赖 `project(':common')`。
- 版本差异的登记点是各 target `prepareCommonSources` 里的 `exclude` 块：某个 common 文件在该 target 上有确证差异时，在那里 `exclude '<路径>'`，并把该 target 自己的实现放进 target。
- 唯一能把代码从 `common` 拆到 `targets/<loader>-<mc-version>/` 的理由是：经阅读实际源码/API 确证该内容在不同 loader 或不同 Minecraft 版本之间存在差异。不得凭猜测拆分，也不得为了“代码好看”而拆分。
- `common` 现在不是独立的 Gradle 子项目，而是共享源码树：`common/build.gradle` 用 `java-library` + `net.neoforged.moddev.legacyforge 2.0.91`、toolchain 17，对着与 `targets/forge-1.20.1` 相同的 Forge 1.20.1 类路径独立编译与测试（`gradlew -p common build` / `gradlew -p common test`）。
- 不要用运行时版本判断、反射或同名 class 覆盖来兼容不同 target；不同 API 应由各 target 的适配器实现。
- 一个发布 jar 只对应一个 loader 与一个 Minecraft 版本，禁止 universal jar。

## 文件与配置约定

| 内容 | 位置 | 规则 |
| --- | --- | --- |
| 共享 Java 代码 | `common/src/main/java/` | 放所有没有确证版本差异的代码，可引用 Minecraft 与 loader 类型；确证有版本差异的文件在该 target 的 `prepareCommonSources` 中 `exclude`。 |
| 共享资源 | `common/src/main/resources/` | 会自动合并到所有 target 的最终 jar。 |
| 目标专属资源 | `targets/<name>/src/main/resources/` | 仅放该版本/loader 专属资源。 |
| Loader metadata | target 的 `src/main/resources/` | 保留在 target；Fabric、Forge、NeoForge 格式不可共用。 |
| 版本/loader 参数 | `targets/<name>/gradle.properties` | 不放在仓库根 `gradle.properties`。 |
| 共享模组信息 | 根 `gradle.properties` | 仅 `mod_*` 和 Gradle 运行参数。 |
| 本地 jar 依赖 | `targets/<name>/libs/` | 自动作为 `implementation` 依赖读取；不需要逐条声明。 |
| 发布配置 | `gradle/target-conventions/publish.gradle` | 统一管理，target 不复制发布逻辑。 |

`libs/` 中的普通 jar 不会自动带来传递依赖；依赖的其他 jar 也必须放入同一个 `libs/`，或改用正常的 Maven 依赖声明。不要把 `*-sources.jar`、`*-javadoc.jar` 或构建产物误放入此目录。

共享资源与 target 资源若有同路径文件，必须明确选择唯一归属；不要依赖覆盖顺序。加载器 metadata、Mixin 配置、access widener/access transformer 和版本专属语言文件一律归 target。

## 日常开发

1. 先判断改动是 `common`、单个 target、多个 target，还是构建/发布配置。
2. 单 target 改动只修改对应 `targets/<name>/`；不因方便而改动其他版本。
3. 改动默认放入 `common`；只有经源码确证某段内容存在版本差异时，才把它移入对应 target，并在该 target 的 `prepareCommonSources` 里 `exclude` 对应 common 路径。
4. 改动资源、metadata、Mixin、注册、事件、网络或渲染时，除构建外必须做相应的运行验证。
5. 不提交 token、账号、密码、私有仓库凭据、IDE 运行缓存或 `build/` 输出。

### 构建命令

每个 target 是独立 Gradle 根工程，应在它自己的目录中构建：

```powershell
cd targets\forge-1.20.1
.\gradlew.bat clean build
```

| Target | Gradle JVM |
| --- | --- |
| `forge-1.20.1` | JDK 21 |
| `forge-1.19.2` | JDK 21 |
| `forge-1.18.2` | JDK 21 |
| `fabric-1.20.1` | JDK 17 |
| `fabric-1.21.1` | JDK 21 |
| `fabric-26.1` | JDK 25 |
| `neoforge-1.21.1` | JDK 21 |
| `neoforge-26.1` | JDK 25 |

根项目的 `-PallTargets=true build` 在 JDK 21 下只能聚合除 `fabric-26.1`、`neoforge-26.1` 之外的 6 个 target；这两个 26.1 target 需要 JDK 25，必须独立构建。

### 发布

在对应 target 内运行 `publishMods` 可手动发布该 target 的 jar 到 CurseForge 和 Modrinth。根 `gradle.properties` 中配置非敏感项目 ID；token 只通过环境变量提供：

```powershell
$env:CURSEFORGE_TOKEN = '...'
$env:MODRINTH_TOKEN = '...'
.\gradlew.bat publishMods
```

发布前必须执行该 target 的 `clean build`，检查 jar 内的 metadata、共享 class、共享资源和版本范围。不要从根项目或错误 target 发布。

## 将既有项目迁入本框架

迁移应以“先可构建、再抽取共享代码、最后验证行为”为顺序，禁止先删除旧工程再尝试恢复。

1. **盘点原项目**：记录 Minecraft 版本、loader、JDK、Gradle、mappings、入口、Mixin、资源、数据生成、依赖与运行配置。
2. **建立 target**：为每个 `(loader, Minecraft 版本)` 建立 `targets/<loader>-<mc-version>/` 独立工程，包含 wrapper、`settings.gradle` 与本地 `gradle.properties`。用 `includeBuild('../../common')` 让 IDE 把 `common` 作为 composite build 的独立可编辑模块导入，并把 `../../common/src/main/java` 加入 main 源码集、把 `../../common/src/test/` 加入 test 源码集（source-set sharing）；不要使用 `project(':common')` 依赖。
3. **复制专属层**：将入口、注册、事件、Mixin、渲染、网络、metadata 和版本专属资源放入对应 target；不要在一个 target 放多版本分支。
4. **抽取 common**：把没有确证版本差异的代码（包括引用 Minecraft 与 loader 类型的那部分）迁到 `common`；只有经源码确证存在版本差异的部分才留在 target，并在该 target 的 `prepareCommonSources` 里 `exclude` 对应路径。
5. **迁移资源**：所有 target 共用的 assets/data/lang 放到 `common/src/main/resources/`；将 Fabric/Forge/NeoForge metadata 与版本专属 Mixin 配置保留在 target。
6. **迁移依赖**：可从公开仓库解析的依赖写入对应 target 的 `build.gradle`；仅本地提供的 jar 放入该 target 的 `libs/`。`common` 只用一份固定的 loader 类路径（见 `common/build.gradle`）独立编译，某个 target 专属的加载器依赖仍写在对应 target。
7. **迁移配置**：模组名称、ID、许可证、作者、描述等共享值放根 `gradle.properties`；Minecraft、loader、mappings、版本范围和 JDK 相关值放 target 本地属性。
8. **逐 target 验证**：使用要求的 JDK 运行 `clean build`，检查 jar 内容，并做最小 client 与 dedicated server 启动验证；涉及数据或资源时额外运行 data generation/reload 验证。
9. **记录差异**：不能立即统一的 API 或行为差异写入 `docs/version-differences/`，由 target 适配实现，不能以 common 中的版本判断掩盖。
10. **清理旧结构**：只有所有迁入 target 均可构建且已验证后，才删除旧代码、旧资源与旧构建入口。

## 提交前检查

- `common` 只放没有确证版本差异的代码；有确证差异的文件已在对应 target 的 `prepareCommonSources` 中 `exclude` 并改为 target 自己的实现。
- 每个新增/修改的 target 使用正确 JDK 独立构建。
- 最终 jar 含正确 metadata、目标专属资源与共享 class/resources。
- 本地 `libs/` 内容明确且没有误提交的旧 jar。
- 发布相关改动不包含 token；项目 ID、版本类型、依赖关系和 changelog 已确认。
- README、版本差异文档和支持矩阵与实际 target 一致。
