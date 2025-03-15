# spin-system-simulations

## 実行環境
以下の環境でシミュレーションを実行可能です。

- **OS:** MacOS
- **言語/フレームワーク:**  
    - Python 3.11.5  
    - numpy
    - matplotlib
    - Pytorch
- **ハードウェア:**  GPU(MPS, CUDA)推奨. (CPUのみでも動くが処理時間的に厳しい)
- **管理ツール:**  Poetry 2.1.1

## セットアップとインストール
以下の手順に従って環境を構築してください。

### リポジトリのクローン:
```bash
git clone https://github.com/tatsuya0926/spin-system-simulations.git
cd spin-system-simulations
```

### Poetryのインストール:
インストール方法は何でもいいが、バージョンは.poetry-versionに合わせること。
```bash
brew install poetry
```

### Python環境構築:
```bash
poetry init
poetry install
```

Python環境（または仮想環境）をJupyter NotebookやJupyter Labで使えるカーネルとして登録する。
```bash
poetry shell
python -m ipykernel install --user --name=spin-system-simulations-py3.11
```
もし`poetry shell`が効かない場合、Poetryのshellプラグインをインストールしたのち上記を実行すれば良い。
```bash
poetry self add poetry-plugin-shell
```