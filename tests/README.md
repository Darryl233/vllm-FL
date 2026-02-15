# vLLM 测试指南

本文档说明如何添加 Unit Test 和 Functional Test，使其能在 CI 中运行，以及如何在本地运行测例。

## 目录

- [测试分类](#测试分类)
- [添加 Unit Test](#添加-unit-test)
- [添加 Functional Test](#添加-functional-test)
- [本地运行测例](#本地运行测例)
- [配置文件说明](#配置文件说明)

---

## 测试分类

| 类型 | 配置文件 | Workflow | 运行方式 |
|------|----------|----------|----------|
| **Unit Test** | `.github/configs/unit.yml` | `unit_tests.yml` | `torchrun --nproc_per_node=8` 并行 |
| **Functional Test** | `.github/configs/functional.yml` | `functional_tests.yml` | 每个测试文件独立 pytest 进程（环境隔离） |

---

## 添加 Unit Test

### 方式一：在现有 subset 中新增测例

1. 在对应目录下创建 `test_*.py` 文件，或往现有文件中添加测试函数。
2. 文件路径需与 subset 的 `path` 配置匹配。

**示例**：在 `engine` subset 中新增测例 → 文件放在 `tests/engine/test_*.py`。

### 方式二：新增 subset

1. **修改 `.github/workflows/unit_tests.yml`**：在 `matrix.subset` 中加入新 subset 名：

   ```yaml
   matrix:
     subset:
       - benchmarks
       - compile
       # ...
       - your_new_subset
   ```

2. **修改 `.github/configs/unit.yml`**：添加配置：

   ```yaml
   unit-conf:
     # ... 其他 subset ...
     your_new_subset:
       depth: all
       ignore:
         - pass
       deselect:
         - pass
   ```

3. **放置测例文件**：
   - 默认：`tests/your_new_subset/test_*.py`
   - 自定义路径：在配置中加 `path: tests/xxx/yyy`

---

## 添加 Functional Test

### 方式一：在现有 subset 中新增测例

1. 在对应 subset 的 `path` 下创建 `test_*.py`。
2. 若需跳过某些测例，在 `functional.yml` 的 `deselect` 中添加。

**示例**：`v1_e2e` 的 path 为 `tests/v1/e2e`，新测例放在 `tests/v1/e2e/test_xxx.py`。

### 方式二：新增 subset

1. **修改 `.github/workflows/functional_tests.yml`**：在 `matrix.subset` 中加入新 subset：

   ```yaml
   matrix:
     subset:
       - basic_correctness
       # ...
       - your_new_subset
   ```

2. **修改 `.github/configs/functional.yml`**：添加配置：

   ```yaml
   functional-conf:
     # ... 其他 subset ...
     your_new_subset:
       path: tests/your/path
       depth: all
       ignore:
         - pass
       deselect:
         - pass
   ```

---

## 本地运行测例

### 1. 环境准备

```bash
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate flagscale-inference

# 安装依赖
pip install -r requirements/cuda.txt
pip install -r requirements/common.txt
pip install -e .
```

### 2. 运行单个文件

```bash
python -m pytest -x -p no:warnings tests/v1/e2e/test_min_tokens.py
```

### 3. 运行指定测例

```bash
python -m pytest -x -p no:warnings tests/v1/e2e/test_min_tokens.py::test_xxx
```

### 4. 运行整个 subset（模拟 CI 行为）

**Unit Test（多进程）**：

```bash
# 按 subset 运行
torchrun --nproc_per_node=8 -m pytest -q -x -p no:warnings \
  --ignore=pass \
  tests/engine/ tests/compile/  # 替换为对应 subset 路径
```

**Functional Test（逐个文件）**：

```bash
# 示例：运行 v1_e2e 下所有文件
for f in tests/v1/e2e/test_*.py; do
  python -m pytest -q -x -p no:warnings "$f"
done
```

### 5. 使用 ignore / deselect

```bash
python -m pytest -x -p no:warnings \
  --ignore=some_path \
  --deselect=tests/v1/e2e/test_spec_decode.py \
  tests/v1/e2e/test_min_tokens.py
```

### 6. 查看 pytest 退出码

```bash
python -m pytest tests/xxx.py; echo "Exit code: $?"
# 0=成功, 1=失败, 5=未收集到测试
```

---

## 配置文件说明

### 字段含义

| 字段 | 含义 | 示例 |
|------|------|------|
| `path` | 测例根目录（可选） | `tests/v1/e2e` |
| `depth` | 递归深度，`all` 表示最深 | `all` 或 `1` |
| `ignore` | 要忽略的路径（通常用 `pass` 占位） | `pass` 或 `tests/xxx` |
| `deselect` | 要取消选中的测例或文件 | 文件路径或 `file::test_func` |

### 路径推断规则

- 若配置了 `path`：使用该路径。
- 若未配置：默认使用 `tests/<subset_name>`。
- 测例文件需符合 `test_*.py` 命名。

### 新增 deselect 示例

```yaml
deselect:
  - tests/v1/e2e/test_spec_decode.py       # 整个文件
  - tests/engine/test_xxx.py::test_yyy     # 单个测例
```

---
